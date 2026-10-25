# MCP server hardening checklist

> As of 25 October 2026. Based on the MCP specification revision 2026-07-28 (the current revision) and the official security best practices; before relying on a spec detail, confirm it against <https://modelcontextprotocol.io/specification/versioning> and the changelog for the revision the server targets, or ask the author to run `/dimi:refresh-harness`.

Every finding needs `path:line` evidence. Mark checks that depend on deployment or identity-provider settings you cannot see as "Could not verify". Search hints use `rg -n -e <pattern> -e <pattern>` (one regex per `-e`, every metacharacter escaped: `\(`, `\.`, `\+`); with the Grep tool, run one pattern per call, or join the already-escaped patterns with `|` into one regex.

## Severity

| Severity | Use when |
| --- | --- |
| Critical | Token passthrough, missing audience validation, unauthenticated remote server exposing private data or writes, command or SQL injection, SSRF into internal networks, secrets returned in tool results, cross-user data access |
| High | No per-user authorisation inside tools, deprecated transport or auth flow on a remote server, unbounded outputs that can leak bulk data, local server running with broad host privileges, unpinned dependencies on a published server, a false `readOnlyHint` or `destructiveHint: false` that masks a write, hidden directives or client arguments spliced into prompt-template instructions (R2), elicitation that asks for passwords, tokens, keys or card numbers (S12) |
| Medium | Protocol revision lag without a migration plan, missing `outputSchema` or `isError` handling, non-deterministic tool listing, thin descriptions, no rate limiting, no timeouts, no structured logging, non-protocol output on stdout from a stdio server (T5) |
| Low | Naming, accurate-but-missing annotations, documentation |

## 1. Protocol revision and core

| ID | Check | What good looks like |
| --- | --- | --- |
| P1 | Target revision | The server states which spec revision it supports and uses an SDK version that implements it. 2026-07-28 is current; an older target is Medium unless a dated migration plan exists |
| P2 | Stateless core | No reliance on the removed `initialize` handshake or `Mcp-Session-Id` header (see the "Stateless core" section of the [2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)). The changelog also describes per-request version and capability metadata in `_meta` and a `server/discover` method: confirm both field names against the current spec before citing them in a finding |
| P3 | Explicit state handles | Servers that need state return explicit handles the model passes back as tool arguments; handles are bound to the authenticated user on the server side and expire |
| P4 | Multi round-trip input | Requests for user input use `input_required` results and client retries (multi round-trip requests), not server-initiated sampling, elicitation or roots requests |
| P5 | Deprecated features | No new dependence on roots, sampling, logging, the HTTP+SSE transport or Dynamic Client Registration; a removal plan exists for any current use |
| P6 | Tasks | Long-running work uses the Tasks extension (`io.modelcontextprotocol/tasks`) rather than holding requests open |

## 2. Transport

| ID | Check | What good looks like |
| --- | --- | --- |
| T1 | Right transport | `stdio` for local servers; Streamable HTTP for remote servers |
| T2 | TLS | Remote servers only over HTTPS |
| T3 | Origin and binding | Local HTTP servers bind to localhost only and validate the `Origin` header to block DNS rebinding (pattern 8) |
| T4 | Trace context (optional) | A convention, not a spec requirement: OpenTelemetry trace context accepted from `_meta` so calls join the client's traces. Report its absence as Low at most |
| T5 | stdio hygiene | A stdio server writes nothing but protocol messages to stdout; logs, banners and debug prints go to stderr or a file. Search: `rg -n -e "print\(" -e "console\.log\(" -e "sys\.stdout"` in server code |

## 3. Authorisation (remote servers)

| ID | Check | What good looks like |
| --- | --- | --- |
| A1 | OAuth 2.1 resource server | The server acts as an OAuth 2.1 protected resource and rejects requests without a valid bearer token |
| A2 | Protected Resource Metadata | Publishes RFC 9728 metadata (resource identifier, authorisation servers, scopes) and returns `WWW-Authenticate` with `resource_metadata` on 401 (pattern 1) |
| A3 | Audience validation | Accepts only tokens issued for this server (RFC 8707 resource indicator / `aud`); validates signature, expiry and issuer (pattern 2) |
| A4 | No token passthrough | Never forwards the client's token to downstream APIs; uses its own credentials or a token exchange scoped to the downstream API (pattern 3) |
| A5 | Minimal scopes and step-up | Starts with minimal scopes; returns 403 `insufficient_scope` with a `scope=` challenge for step-up; no wildcard scopes |
| A6 | Client registration | Supports Client ID Metadata Documents; Dynamic Client Registration only for legacy clients |
| A7 | Enterprise identity | For enterprise clients, the Enterprise-Managed Authorization extension is implemented, or an ADR, README or roadmap entry in the repository names it with a date. Nothing in the repository: "Could not verify", not a pass |
| A8 | Confused deputy | A proxy server collects consent per client and matches redirect URIs exactly |

## 4. Tool design

| ID | Check | What good looks like |
| --- | --- | --- |
| D1 | Names | Short, unique and namespaced by service (for example `crm_contacts_search`), so they don't collide when hosts combine servers |
| D2 | Descriptions | Several sentences each: what it does, when to use it, when not to, what each argument means, with an example value (pattern 4) |
| D3 | Input schemas | JSON Schema with types, enums, formats, ranges and required fields; no free-form `query` strings where structured fields would do (pattern 4) |
| D4 | Output schemas | `outputSchema` declared and `structuredContent` returned, plus a text copy for older clients (pattern 4) |
| D5 | Errors | Execution failures returned as results with `isError: true` and an actionable message; protocol problems as JSON-RPC errors (pattern 5) |
| D6 | Bounded outputs | Pagination, limits and field selection; no tool can dump a whole table or mailbox in one call (pattern 9) |
| D7 | Deterministic listing | `tools/list` returns tools in a stable order (it helps clients' prompt caching) |
| D8 | Few, workflow-level tools | Tools cover whole tasks rather than mirroring every API endpoint |
| D9 | Annotations honest | `readOnlyHint`, `destructiveHint` and similar are accurate, and nothing relies on them for security, since clients must treat them as untrusted. A false hint on a writing tool is High (it is a poisoning vector); a missing hint is Low |
| D10 | Stable definitions | Tool descriptions change only with a version bump and changelog, so clients that pin definitions are not surprised |

## 5. Resources and prompts

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| R1 | Resource URIs confined | `resources/read` and URI templates resolve to an allowed root or allowlisted hosts: no path traversal through template variables, no fetch of private addresses (patterns 6 and 7); per-user authorisation applies to resources as it does to tools | `rg -n -e "resources/read" -e "uriTemplate" -e "ResourceTemplate" -e "list_resources" -e "read_resource"` |
| R2 | Prompt templates clean | Prompt templates contain no hidden directives, and arguments are inserted into fixed slots, never spliced into the instruction text; argument values from the client are treated as untrusted | `rg -n -e "prompts/get" -e "list_prompts" -e "get_prompt" -e "PromptMessage"` |

## 6. Security in tool code

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| S1 | Per-user authorisation | Every tool checks the authenticated user may act on the target resource; IDs from the model are verified | `rg -n -e "Authorization" -e "bearer" -e "current_user" -e "claims" -e "sub\b"`, then read each handler that takes an id |
| S2 | Injection | No shell, SQL or template injection: parameterised queries, argument arrays instead of shell strings | `rg -n -e "shell=True" -e "os\.system" -e "exec\(" -e "eval\(" -e "f\"SELECT" -e "\+ \"SELECT" -e "child_process" -e "execSync"` |
| S3 | SSRF | Tools that fetch URLs block private, loopback and link-local ranges (including after redirects and DNS resolution) or go through an egress proxy (pattern 6) | `rg -n -e "requests\.get" -e "httpx" -e "fetch\(" -e "axios" -e "urlopen"` |
| S4 | Path traversal | File tools resolve paths and confine them to an allowed root (pattern 7) | `rg -n -e "open\(" -e "readFile" -e "Path\("` |
| S5 | Secrets | No secrets, tokens or internal stack traces in tool results or logs | `rg -n -e "traceback" -e "stack" -e "str\(e\)" -e "e\.message" -e "api_key" -e "secret"` in result builders and error handlers |
| S6 | Untrusted content flagged | Results that carry third-party text (emails, web pages, tickets) are labelled as untrusted for the host | Read result builders |
| S7 | No instructions in descriptions | Tool descriptions contain no hidden directives to the model | Read all descriptions |
| S8 | Rate limiting and quotas | Per-user and per-client limits | `rg -n -e "RateLimit" -e "ratelimit" -e "limiter" -e "throttle" -e "slowapi" -e "express-rate-limit"` |
| S9 | Audit logging | Each call logged with user, tool, arguments (redacted) and outcome | `rg -n -e "logger" -e "logging\." -e "audit" -e "pino" -e "winston"`, then check what is written and what is redacted |
| S10 | Supply chain | Dependencies pinned with a lockfile; releases built in CI from a tagged commit; the package is published under an organisation scope or a registered namespace and its name matches the repository. Evidence: lockfile, release workflow, `package.json` or `pyproject.toml` name. Publication settings you cannot see: "Could not verify" | Check lockfiles and CI |
| S11 | Local server privileges | Local servers run with least privilege, ideally sandboxed or containerised; the launch command is documented in full | Read launch config and README |
| S12 | Elicitation content | `input_required` and any remaining elicitation never ask the user for passwords, tokens, keys or card numbers; prompts shown to the user say which server is asking | `rg -n -e "input_required" -e "elicit"` |
| S13 | Timeouts and size caps | Every tool handler and outbound call has a timeout and cancellation path; results are capped in bytes or tokens before return (hosts cap tool results, for example Claude Code at 25,000 tokens, see `${CLAUDE_PLUGIN_ROOT}/skills/harness-reference/references/tools-and-mcp.md`), with a `truncated` flag or cursor rather than a silent cut (pattern 9) | `rg -n -e "timeout" -e "AbortController" -e "signal" -e "max_bytes" -e "truncat"` |

## 7. Operations

| ID | Check | What good looks like |
| --- | --- | --- |
| O1 | Gateway | Remote servers for enterprise clients sit behind an MCP gateway that enforces auth, logging and rate limits |
| O2 | Versioning | Server version and supported spec revision exposed; changelog maintained |
| O3 | Tests | Tests cover auth rejection, audience mismatch, authorisation per tool, error results and output bounds |
| O4 | Monitoring | Error rate, latency and auth failures monitored and alerted. Evidence: metrics or alert definitions in the repository (dashboards as code, alert rules, health endpoints wired to a monitor). Nothing in the repository: "Could not verify" |

## OWASP MCP Top 10 mapping

Use this to cross-reference findings for a client's security team: token and secret exposure (A4, S5), scope creep (A5), tool poisoning (D9, D10, S7, R2), supply chain (S10), command injection (S2), prompt injection (S6, R2, S12), authentication and authorisation (A1-A8, S1, R1), telemetry (S9, T4), shadow servers (O1), context over-sharing (D6, S13). See <https://owasp.org/www-project-mcp-top-10/>.
