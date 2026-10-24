# MCP server hardening checklist

Based on the MCP specification revision 2026-07-28 and the official security best practices, as of 24 October 2026. Before relying on a spec detail, confirm it against the current spec: <https://modelcontextprotocol.io/specification/versioning> and the changelog for the revision the server targets.

Every finding needs `path:line` evidence. Mark checks that depend on deployment or identity-provider settings you cannot see as "Could not verify".

## Severity

| Severity | Use when |
| --- | --- |
| Critical | Token passthrough, missing audience validation, unauthenticated remote server exposing private data or writes, command or SQL injection, SSRF into internal networks, secrets returned in tool results, cross-user data access |
| High | No per-user authorisation inside tools, deprecated transport or auth flow on a remote server, unbounded outputs that can leak bulk data, local server running with broad host privileges, unpinned dependencies on a published server |
| Medium | Missing `outputSchema` or `isError` handling, non-deterministic tool listing, thin descriptions, no rate limiting, no structured logging |
| Low | Naming, annotations, documentation |

## 1. Protocol revision and core

| ID | Check | What good looks like |
| --- | --- | --- |
| P1 | Target revision | The server states which spec revision it supports and uses an SDK version that implements it. 2026-07-28 is current |
| P2 | Stateless core | No reliance on the removed `initialize` handshake or `Mcp-Session-Id` header; each request's `_meta` carries version and client capabilities; `server/discover` is implemented |
| P3 | Explicit state handles | Servers that need state return explicit handles the model passes back as tool arguments; handles are bound to the authenticated user on the server side and expire |
| P4 | Multi round-trip input | Requests for user input use `input_required` results and client retries (multi round-trip requests), not server-initiated sampling, elicitation or roots requests |
| P5 | Deprecated features | No new dependence on roots, sampling, logging, the HTTP+SSE transport or Dynamic Client Registration; a removal plan exists for any current use |
| P6 | Tasks | Long-running work uses the Tasks extension (`io.modelcontextprotocol/tasks`) rather than holding requests open |

## 2. Transport

| ID | Check | What good looks like |
| --- | --- | --- |
| T1 | Right transport | `stdio` for local servers; Streamable HTTP for remote servers |
| T2 | TLS | Remote servers only over HTTPS |
| T3 | Origin and binding | Local HTTP servers bind to localhost only and validate the `Origin` header to block DNS rebinding |
| T4 | Trace context | OpenTelemetry trace context accepted from `_meta` so calls join the client's traces |

## 3. Authorisation (remote servers)

| ID | Check | What good looks like |
| --- | --- | --- |
| A1 | OAuth 2.1 resource server | The server acts as an OAuth 2.1 protected resource and rejects requests without a valid bearer token |
| A2 | Protected Resource Metadata | Publishes RFC 9728 metadata (resource identifier, authorisation servers, scopes) and returns `WWW-Authenticate` with `resource_metadata` on 401 |
| A3 | Audience validation | Accepts only tokens issued for this server (RFC 8707 resource indicator / `aud`); validates signature, expiry and issuer |
| A4 | No token passthrough | Never forwards the client's token to downstream APIs; uses its own credentials or a token exchange scoped to the downstream API |
| A5 | Minimal scopes and step-up | Starts with minimal scopes; returns 403 `insufficient_scope` with a `scope=` challenge for step-up; no wildcard scopes |
| A6 | Client registration | Supports Client ID Metadata Documents; Dynamic Client Registration only for legacy clients |
| A7 | Enterprise identity | For enterprise clients, supports or plans for the Enterprise-Managed Authorization extension (company identity provider issues the tokens) |
| A8 | Confused deputy | A proxy server collects consent per client and matches redirect URIs exactly |

## 4. Tool design

| ID | Check | What good looks like |
| --- | --- | --- |
| D1 | Names | Short, unique and namespaced by service (for example `crm_contacts_search`), so they don't collide when hosts combine servers |
| D2 | Descriptions | Several sentences each: what it does, when to use it, when not to, what each argument means, with an example value |
| D3 | Input schemas | JSON Schema with types, enums, formats, ranges and required fields; no free-form `query` strings where structured fields would do |
| D4 | Output schemas | `outputSchema` declared and `structuredContent` returned, plus a text copy for older clients |
| D5 | Errors | Execution failures returned as results with `isError: true` and an actionable message; protocol problems as JSON-RPC errors |
| D6 | Bounded outputs | Pagination, limits and field selection; no tool can dump a whole table or mailbox in one call |
| D7 | Deterministic listing | `tools/list` returns tools in a stable order (it helps clients' prompt caching) |
| D8 | Few, workflow-level tools | Tools cover whole tasks rather than mirroring every API endpoint |
| D9 | Annotations honest | `readOnlyHint`, `destructiveHint` and similar are accurate, and nothing relies on them for security, since clients must treat them as untrusted |
| D10 | Stable definitions | Tool descriptions change only with a version bump and changelog, so clients that pin definitions are not surprised |

## 5. Security in tool code

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| S1 | Per-user authorisation | Every tool checks the authenticated user may act on the target resource; IDs from the model are verified | Read each handler |
| S2 | Injection | No shell, SQL or template injection: parameterised queries, argument arrays instead of shell strings | `rg -n "shell=True\|os\.system\|exec\(\|eval\(\|f\"SELECT\|\+ *\"SELECT\|child_process\|execSync"` |
| S3 | SSRF | Tools that fetch URLs block private, loopback and link-local ranges (including after redirects and DNS resolution) or go through an egress proxy | `rg -n "requests\.get\|httpx\|fetch\(\|axios\|urlopen"` |
| S4 | Path traversal | File tools resolve paths and confine them to an allowed root | `rg -n "open\(\|readFile\|Path\("` |
| S5 | Secrets | No secrets, tokens or internal stack traces in tool results or logs | Read error handlers |
| S6 | Untrusted content flagged | Results that carry third-party text (emails, web pages, tickets) are labelled as untrusted for the host | Read result builders |
| S7 | No instructions in descriptions | Tool descriptions contain no hidden directives to the model | Read all descriptions |
| S8 | Rate limiting and quotas | Per-user and per-client limits | Look for limiter middleware |
| S9 | Audit logging | Each call logged with user, tool, arguments (redacted) and outcome | Read logging |
| S10 | Supply chain | Dependencies pinned with a lockfile; releases built in CI; package name not easily squatted | Check lockfiles and CI |
| S11 | Local server privileges | Local servers run with least privilege, ideally sandboxed or containerised; the launch command is documented in full | Read launch config and README |

## 6. Operations

| ID | Check | What good looks like |
| --- | --- | --- |
| O1 | Gateway | Remote servers for enterprise clients sit behind an MCP gateway that enforces auth, logging and rate limits |
| O2 | Versioning | Server version and supported spec revision exposed; changelog maintained |
| O3 | Tests | Tests cover auth rejection, audience mismatch, authorisation per tool, error results and output bounds |
| O4 | Monitoring | Error rate, latency and auth failures monitored and alerted |

## OWASP MCP Top 10 mapping

Use this to cross-reference findings for a client's security team: token and secret exposure (A4, S5), scope creep (A5), tool poisoning (D9, D10, S7), supply chain (S10), command injection (S2), prompt injection (S6), authentication and authorisation (A1-A8, S1), telemetry (S9, T4), shadow servers (O1), context over-sharing (D6). See <https://owasp.org/www-project-mcp-top-10/>.
