# MCP hardening patterns

Patterns to cite in findings or adapt when fixing. Field names follow the MCP 2026-07-28 revision and the referenced RFCs; confirm against the current spec and the SDK version in use before shipping.

Contents:

1. Protected Resource Metadata and 401 or 403 challenges
2. Validating bearer tokens (audience, issuer, expiry)
3. Calling downstream APIs without token passthrough
4. A well-formed tool definition
5. Success and error results
6. SSRF guard for URL-fetching tools
7. Confining file paths

## 1. Protected Resource Metadata and 401 or 403 challenges

Serve RFC 9728 metadata so clients can discover the authorisation server:

```json
{
  "resource": "https://mcp.example.com",
  "authorization_servers": ["https://login.example.com"],
  "scopes_supported": ["crm.read", "crm.write"],
  "bearer_methods_supported": ["header"],
  "resource_documentation": "https://mcp.example.com/docs"
}
```

Unauthenticated request (HTTP 401):

```
WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource", scope="crm.read"
```

Authenticated but missing a scope (HTTP 403, step-up):

```
WWW-Authenticate: Bearer error="insufficient_scope", scope="crm.write", resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource"
```

## 2. Validating bearer tokens (audience, issuer, expiry)

Accept only tokens issued for this server. Example with PyJWT and a JWKS endpoint:

```python
import jwt  # PyJWT
from jwt import PyJWKClient

RESOURCE = "https://mcp.example.com"        # this server's canonical URI (the token audience)
ISSUER = "https://login.example.com/"       # the authorisation server you trust
JWKS = PyJWKClient("https://login.example.com/.well-known/jwks.json")


def validate_bearer(token: str) -> dict:
    signing_key = JWKS.get_signing_key_from_jwt(token).key
    return jwt.decode(
        token,
        signing_key,
        algorithms=["RS256"],               # never accept "none"; pin what the IdP uses
        audience=RESOURCE,
        issuer=ISSUER,
        options={"require": ["exp", "iat", "aud", "iss", "sub"]},
    )
```

If the identity provider issues opaque tokens, use its introspection endpoint and apply the same audience and issuer checks. Map `sub` (and tenant claims) to the user whose permissions every tool call is checked against.

## 3. Calling downstream APIs without token passthrough

Never forward the client's MCP token. Either use the server's own credentials with per-user authorisation enforced in the server, or exchange the token for one scoped to the downstream API (OAuth 2.0 Token Exchange, RFC 8693, where the identity provider supports it):

```python
import httpx


def downstream_token(user_token: str, downstream_audience: str) -> str:
    resp = httpx.post(
        "https://login.example.com/oauth2/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
            "subject_token": user_token,
            "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
            "audience": downstream_audience,
            "scope": "crm.read",
        },
        auth=("mcp-server-client-id", "client-secret-from-vault"),
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]
```

## 4. A well-formed tool definition

```json
{
  "name": "crm_contacts_search",
  "title": "Search CRM contacts",
  "description": "Search the CRM for contacts by name, email or company. Use it to find a contact before reading or updating their record. Do not use it to list all contacts; it returns at most 50 matches. Example: query \"acme\", status \"active\".",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": { "type": "string", "minLength": 2, "maxLength": 200, "description": "Name, email or company to match" },
      "status": { "type": "string", "enum": ["active", "archived"], "default": "active" },
      "limit": { "type": "integer", "minimum": 1, "maximum": 50, "default": 10 }
    },
    "required": ["query"],
    "additionalProperties": false
  },
  "outputSchema": {
    "type": "object",
    "properties": {
      "contacts": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "company": { "type": "string" }
          },
          "required": ["id", "name"]
        }
      },
      "next_cursor": { "type": ["string", "null"] }
    },
    "required": ["contacts"]
  },
  "annotations": { "readOnlyHint": true, "openWorldHint": false }
}
```

## 5. Success and error results

Success, with structured content and a text copy for older clients:

```json
{
  "content": [{ "type": "text", "text": "2 contacts found: Ada Lovelace (Acme), Alan Turing (Acme)" }],
  "structuredContent": {
    "contacts": [
      { "id": "c_101", "name": "Ada Lovelace", "company": "Acme" },
      { "id": "c_102", "name": "Alan Turing", "company": "Acme" }
    ],
    "next_cursor": null
  }
}
```

Execution failure the model can act on (a result, not a JSON-RPC error):

```json
{
  "content": [{ "type": "text", "text": "limit must be between 1 and 50, got 500. Retry with limit 50 and use next_cursor to page." }],
  "isError": true
}
```

Use JSON-RPC errors only for protocol problems such as an unknown tool or malformed request.

## 6. SSRF guard for URL-fetching tools

Resolve the host and reject non-public addresses before fetching. Disable automatic redirects and re-check every hop.

```python
import ipaddress
import socket
from urllib.parse import urlparse


def assert_public_url(url: str, allowed_schemes: tuple[str, ...] = ("https",)) -> list[str]:
    """Return the resolved public IPs, or raise ValueError."""
    parts = urlparse(url)
    if parts.scheme not in allowed_schemes or not parts.hostname:
        raise ValueError("URL scheme or host not allowed")
    port = parts.port or (443 if parts.scheme == "https" else 80)
    ips = []
    for info in socket.getaddrinfo(parts.hostname, port, proto=socket.IPPROTO_TCP):
        ip = ipaddress.ip_address(info[4][0])
        if not ip.is_global:
            raise ValueError(f"{parts.hostname} resolves to a non-public address")
        ips.append(str(ip))
    return ips
```

To close the gap between checking and connecting (DNS rebinding), connect to one of the returned IPs with the original Host header, or route all fetches through an egress proxy that enforces the same rule. An allow-list of domains is stronger still when the use case permits it.

## 7. Confining file paths

```python
from pathlib import Path


def confine(root: Path, user_path: str) -> Path:
    base = root.resolve()
    target = (base / user_path).resolve()
    if not target.is_relative_to(base):
        raise ValueError("path escapes the allowed root")
    return target
```

`resolve()` follows symlinks, so a link pointing outside the root is rejected too.
