# MCP hardening patterns

> As of 25 October 2026. Field names follow the MCP 2026-07-28 revision and the referenced RFCs; confirm against the current spec and the SDK version in use before shipping, or ask the author to run `/dimi:refresh-harness`.

Patterns to cite in findings or adapt when fixing. The Python examples need Python 3.9 or later (`Path.is_relative_to`, `tuple[str, ...]` hints) and were run on 3.13; patterns 2 and 3 use PyJWT 2.x and httpx; pattern 8 imports Starlette, and its middleware wiring is illustrative (only `origin_allowed` was run).

Contents:

1. Protected Resource Metadata and 401 or 403 challenges
2. Validating bearer tokens (audience, issuer, expiry)
3. Calling downstream APIs without token passthrough
4. A well-formed tool definition
5. Success and error results
6. SSRF guard for URL-fetching tools
7. Confining file paths
8. Localhost binding and Origin validation for local HTTP servers
9. Bounding a tool result (page size, byte cap, cursor)

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
      "status": { "type": "string", "enum": ["active", "archived"], "default": "active", "description": "Contact status to match; archived contacts are hidden unless asked for" },
      "limit": { "type": "integer", "minimum": 1, "maximum": 50, "default": 10, "description": "Maximum contacts to return, 1 to 50" }
    },
    "required": ["query"],
    "additionalProperties": false
  },
  "outputSchema": {
    "type": "object",
    "properties": {
      "contacts": {
        "type": "array",
        "maxItems": 50,
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
      "truncated": { "type": "boolean" },
      "next_cursor": { "type": ["string", "null"] }
    },
    "required": ["contacts", "truncated", "next_cursor"]
  },
  "annotations": { "readOnlyHint": true, "openWorldHint": false }
}
```

## 5. Success and error results

One envelope for every tool. Success: `structuredContent` carries the payload and matches `outputSchema`; `content` carries the same payload serialised as JSON in a text block, which the spec (2025-06-18 onward) says a tool returning structured content SHOULD do for clients that do not read it. A short summary may follow as a second text block.

```json
{
  "content": [{ "type": "text", "text": "{\"contacts\": [{\"id\": \"c_101\", \"name\": \"Ada Lovelace\", \"company\": \"Acme\"}, {\"id\": \"c_102\", \"name\": \"Alan Turing\", \"company\": \"Acme\"}], \"truncated\": false, \"next_cursor\": null}" }],
  "structuredContent": {
    "contacts": [
      { "id": "c_101", "name": "Ada Lovelace", "company": "Acme" },
      { "id": "c_102", "name": "Alan Turing", "company": "Acme" }
    ],
    "truncated": false,
    "next_cursor": null
  },
  "isError": false
}
```

Execution failure the model can act on (a result, not a JSON-RPC error): `isError: true`, and the error payload `{code, message, retryable, hint?}` as JSON in the `content` text block. The payload may also carry fields the hint refers to, such as `next_cursor` in pattern 9's `item_too_large`, so the model reads them from a field rather than from free text. Leave out `structuredContent` on an error result: the TypeScript SDK client (checked in 1.32.2) validates any `structuredContent` against `outputSchema`, even when `isError` is true, so an error object there fails the call.

```json
{
  "content": [{ "type": "text", "text": "{\"code\": \"invalid_argument\", \"message\": \"limit must be between 1 and 50, got 500\", \"retryable\": false, \"hint\": \"Retry with limit 50 and use next_cursor to page.\"}" }],
  "isError": true
}
```

Use JSON-RPC errors only for protocol problems such as an unknown tool or malformed request. Never put response bodies, stack traces or vendor error text in `message` or `hint`.

## 6. SSRF guard for URL-fetching tools

Resolve the host and reject non-public addresses before fetching. Disable automatic redirects and re-check every hop.

```python
import ipaddress
import socket
from urllib.parse import urlparse


def assert_public_url(url: str, allowed_schemes: tuple[str, ...] = ("https",)) -> list[str]:
    """Return the resolved public IPs, or raise ValueError (also for unresolvable hosts)."""
    parts = urlparse(url)
    if parts.scheme not in allowed_schemes or not parts.hostname:
        raise ValueError("URL scheme or host not allowed")
    port = parts.port or (443 if parts.scheme == "https" else 80)
    try:
        infos = socket.getaddrinfo(parts.hostname, port, proto=socket.IPPROTO_TCP)
    except socket.gaierror as exc:
        raise ValueError(f"{parts.hostname} does not resolve") from exc
    ips = []
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if not ip.is_global:
            raise ValueError(f"{parts.hostname} resolves to a non-public address")
        ips.append(str(ip))
    return ips
```

Tested against loopback, link-local (including the cloud metadata address), RFC 1918, 100.64/10, hex-encoded hosts, `[::1]` and IPv4-mapped IPv6 (`::ffff:127.0.0.1`): all raise. To close the gap between checking and connecting (DNS rebinding), connect to one of the returned IPs with the original Host header, or route all fetches through an egress proxy that enforces the same rule. An allowlist of domains is stronger still when the use case permits it.

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

`resolve()` follows symlinks, so a link pointing outside the root is rejected too. Tested: `../x`, `/etc/passwd` and `link-to-/etc/passwd` raise; `sub/../ok.txt` and `""` (the root itself) pass.

## 8. Localhost binding and Origin validation for local HTTP servers

A local Streamable HTTP server must listen on the loopback interface only and reject requests whose `Origin` is not itself local, or a web page can reach it through DNS rebinding. Starlette or FastAPI example:

```python
from typing import Optional
from urllib.parse import urlsplit

from starlette.requests import Request
from starlette.responses import JSONResponse

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}


def origin_allowed(origin: Optional[str]) -> bool:
    """Absent Origin (non-browser client) passes; any present Origin must be a local http origin."""
    if origin is None:
        return True
    parts = urlsplit(origin)
    return parts.scheme == "http" and parts.hostname in LOCAL_HOSTS


async def origin_guard(request: Request, call_next):
    if not origin_allowed(request.headers.get("origin")):
        return JSONResponse({"error": "forbidden origin"}, status_code=403)
    return await call_next(request)


# app.middleware("http")(origin_guard)
# uvicorn.run(app, host="127.0.0.1", port=port)   # never "0.0.0.0" for a local server
```

`.hostname` strips the port and lower-cases the host, so `http://localhost:6274` is accepted while `http://evil.example`, `null`, `http://localhost.evil.example` and `https://localhost` (not an `http` origin) are not (`origin_allowed` tested on those inputs; the middleware wiring is illustrative). Bind with `host="127.0.0.1"` (or `::1`), never `0.0.0.0`.

## 9. Bounding a tool result (page size, byte cap, cursor)

Cap the number of items, cap the serialised size, and tell the model when either cap was hit. The result follows pattern 5 and validates against pattern 4's `outputSchema`:

```python
import json

MAX_ITEMS = 50
MAX_BYTES = 40_000  # per copy: the result carries the payload twice (structuredContent and its JSON text). A host that
                    # shows the model only the text copy sees ~10-13k tokens of JSON, inside Claude Code's default
                    # 25,000-token MCP output cap; if yours forwards both copies (~27k tokens), lower this.


def tool_error(code: str, message: str, retryable: bool = False, hint: str = "", **fields) -> dict:
    """An MCP error result (pattern 5): the payload as JSON text, no structuredContent.

    `fields` are extra payload fields the hint refers to (for example next_cursor).
    review-agent's framework_tool_error is the non-MCP form of the same payload.
    """
    payload = {"code": code, "message": message, "retryable": retryable, **fields}
    if hint:
        payload["hint"] = hint
    return {"content": [{"type": "text", "text": json.dumps(payload)}], "isError": True}


def bounded_result(contacts: list, cursor_for) -> dict:
    """Return at most MAX_ITEMS contacts and at most MAX_BYTES of JSON, with a cursor when truncated.

    If the first contact alone exceeds MAX_BYTES, return an error result with a next_cursor field past it,
    so the model can skip the oversized item instead of hitting an empty page with no cursor. retryable
    stays false: the same call would fail again; the call with next_cursor is a different one.
    """
    page = contacts[:MAX_ITEMS]
    truncated = len(contacts) > MAX_ITEMS
    while page and len(json.dumps({"contacts": page}).encode()) > MAX_BYTES:
        page = page[:-1]
        truncated = True
    if not page and contacts:
        return tool_error(
            "item_too_large",
            "the next contact is larger than the result size cap",
            hint="Call again with the next_cursor from this error to skip it.",
            next_cursor=cursor_for(contacts[0]),
        )
    structured = {
        "contacts": page,
        "truncated": truncated,
        "next_cursor": cursor_for(page[-1]) if truncated and page else None,
    }
    summary = f"{len(page)} contacts returned" + ("; more available, pass next_cursor to continue" if truncated else "")
    content = [{"type": "text", "text": json.dumps(structured)}, {"type": "text", "text": summary}]  # JSON copy, then optional summary
    return {"content": content, "structuredContent": structured, "isError": False}
```

`cursor_for` turns the last returned item into an opaque, user-bound cursor (for example a signed `(user, last_id)` pair), so the next call cannot be replayed by another user. Declare `truncated` and `next_cursor` in `outputSchema` (pattern 4 does) and mention the cap in the description. Tested, with every success result validated against pattern 4's `outputSchema` using `jsonschema` and its first `content` block parsing back to `structuredContent`: 10 contacts pass untouched; 51 return 50 with a cursor; 40 contacts of 5 KB return 7 under the byte cap with a cursor; a single 70 KB contact returns the `item_too_large` error result with `next_cursor` as a payload field; an empty list returns no cursor and no error.
