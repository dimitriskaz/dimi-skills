---
name: "agent-tool-design"
description: "Design or review a tool that an LLM agent can call: contract and schema written for the model, bounded and PII-minimised outputs, structured error envelopes, tenant scoping from claims, writes as human-accepted proposals, injection posture, per-tool tests and evals, and a no-tool-without-a-consumer rule."
argument-hint: "[tool name or description]"
---

# Agent tool design

Use when adding or changing a tool a model can call — an in-app assistant tool, an MCP tool, a function for a framework agent. Triggers: `/dimi:agent-tool-design`, "design a tool for the assistant", "add a tool that…", "review this tool", "the model should be able to…". For the MCP server plumbing itself use an MCP-builder skill if one is installed (e.g. `anthropic-skills:mcp-builder`); this skill is about the *contract* and its safety, whatever the transport.

## 0. Start from the job, not the API

- Which user job does this tool serve, in one sentence, and which **consumer** calls it today (a prompt rule, a workflow, a guide)? A tool with no consumer is not built. Ship tools with the feature that uses them, never ahead of it.
- Which existing tools overlap? One tool per job; a model with two near-identical tools picks the wrong one. Prefer extending an existing tool with a parameter over a sibling tool, unless the output shape differs.
- Read or write? Writes are *proposals* (section 4). If the job needs both, make two tools.
- Inventory the agent's current tools and write the new one into that list; check the total stays small enough to describe in the system prompt without crowding out the task.

## 1. Contract written for the model

**Name**: `verb_noun`, specific (`get_test_settings`, not `settings`). No two tools share a verb+noun pair.

**Description** (the model reads this, not the code): when to use it, when *not* to (and what to use instead), what it returns, the limits (max rows, window), and one short example call. Describe the data in the model's terms, not the database's.

**Input schema** — strict:
- Enums for anything enumerable; bounded integers for windows and limits; regex/format for ids; no free-form query strings that reach a query language.
- Required vs optional explicit; optional fields have safe defaults; no parameter the server will ignore.
- Never a tenant, actor or permission field: those come from the session or job claims, never from the model.
- Idempotency key on anything that creates.

**Output schema** — stable and bounded:
- A fixed shape with a machine-readable `status`; ids and short fields, not whole raw rows; a `truncated: true` flag plus a cursor when a cap is hit, never a silent partial list; a stated `max_items`.
- Estimate the token size of a maximal response and keep it within the budget you give one tool call; summarise or aggregate (per host, per severity) instead of listing every item.
- Only the fields the job needs. Personal data (emails, user names, IPs, locations, command text) is projected out unless the job needs it, and then the description says so. Prefer stable object ids to people's identifiers.

**Error envelope**: `{status: 'error', code, retryable, hint}`. `hint` tells the model what to do ("use `list_x` first to get an id"). Never include response bodies, query strings, stack traces or vendor error text.

**MCP mapping**: on an MCP server the output schema is the tool's `outputSchema`, the success payload goes in `structuredContent` (plus a text copy), and the error envelope is a result with `isError: true` whose text carries `code` and `hint`; JSON-RPC errors are for protocol problems only (see `${CLAUDE_PLUGIN_ROOT}/skills/harden-mcp/references/checklist.md`, D4 and D5).

## 2. Reads

- Tenant-scoped from claims; the session or context is built per call and reset after; no module-level caches of credentials or tenant data.
- Bounded work per call: page limits, time windows capped, fan-out bounded; a 100-item request that triggers 200 sequential lookups is a timeout and a denial-of-service lever.
- Cache identical reads within a run where the framework allows; make the cache key include every argument.
- Partial reads are reported as partial. Unreadable sources are reported as unread, never omitted or zeroed.

## 3. Outbound calls inside tools

- Fixed or allowlisted hosts; read-only `(method, path)` allowlists pinned by a test; pagination links followed only on the same host and allowlisted paths; vendor redirect/region headers ignored.
- Rate limits honoured via a shared envelope; retry inside the request, not around the whole walk.
- Secrets never in results or logs; sent only to the token endpoint; least-privilege scopes documented beside the tool.

## 4. Writes are proposals

The model never writes directly unless the client profile permits direct writes for that action class:
1. The tool **validates** the model's request (schema, registry of allowed types, allowlisted keys) and **stores the exact patch or pairs server-side** under a proposal id, bound to the tenant, the actor and the current version of the target.
2. The tool returns the proposal id and a human-readable summary for a review card. It writes nothing.
3. A person accepts. The commit route takes **only the proposal id**, re-checks tenant and kind *before* any replay check, re-validates against the stored version (refuse on stale), applies what the server stored — never anything from the browser or the model — and records the commit.
4. Partial failure is not recorded as success; retry applies the rest; already-present items come back as `unchanged`.
5. Proposal stores outlive one process (multiple instances) and expire.

Ambiguity is refused, not guessed: zero or several matches for a reference returns an error with a hint, never the first match.

**Side-effect discipline for any tool that writes** (proposal, or a direct write where the client profile permits it):
- **Idempotency key derived from the run**, e.g. `thread_id + step_id` or the tool-call id — never a `uuid4()`/`randomUUID()` minted inside a step that can re-run on retry or resume. If the target API has no idempotency support, check an outbox/dedup table keyed the same way before sending.
- **Approval bound to the exact call**: store a hash of tool name + canonical arguments; execute only if the hash matches; single-use; expires; records the approver. Never re-generate arguments after approval.
- **No side effect before an interrupt** in a step that re-runs from its start on resume (graph frameworks do this); put the write after the approval point or make it idempotent.
- **Compensation** for multi-step writes across systems: record the undo action, or make the sequence recoverable.
- **Bounded work and stall detection**: a cap on items per call; repeated identical calls or no state change for N steps stops or escalates rather than looping.

## 5. Injection and truthfulness posture

- Tool results are **data**. Record text, connector text and document content reach the model only as tool results; the system prompt instructs the model to treat them as untrusted and never as instructions.
- Everything the model outputs is re-validated on the server before it does anything; a person accepts every write.
- The system prompt does not let the model assert facts the tools have not returned ("test X already covers this" when the tool never read X's status). If a rule needs a fact, add the field to the tool output.
- Logs carry tool name, tenant, actor id, key names and counts; never argument values that could hold personal data, never outputs.

## 6. Tests and evals per tool

- **Schema tests**: valid call accepted; each invalid shape refused with the right code; tenant/actor fields rejected if present.
- **Golden calls**: happy path, empty result, truncated result (flag and cursor present), upstream error (envelope has no body), cross-tenant attempt refused.
- **Proposal flow** (writes): propose → accept → applied; stale version refused; wrong kind refused before replay; partial failure retried; replay returns the stored result.
- **Injection fixtures**: record text containing instructions does not change behaviour.
- **Eval tasks**: three to five realistic user requests with the expected tool sequence and an acceptance rubric; run on every prompt or tool change.
- **Usage telemetry**: calls, errors, truncations per tool; a tool unused for a release is a removal candidate.

## 7. Lifecycle

Version the contract; add parameters compatibly; deprecate with an alias period and a hint in the error; remove tools nothing calls. Keep a one-page spec per tool next to the code (section 8) so the description, schema and tests stay in step.

## 8. Output: tool spec
```
# Tool: <verb_noun>
Job: <one sentence>            Consumer today: <prompt rule / workflow>
Kind: read | proposal          Tenant/actor: from claims
Description (for the model): ...
Input schema: ...              Output schema: ... (max_items, truncated+cursor)
Errors: codes → hint
Bounds: pages, windows, fan-out, token estimate of max response
Data: fields projected out and why; personal data kept and why
Outbound: hosts, allowlist, scopes
Tests: schema · golden · proposal flow · injection · cross-tenant
Evals: tasks and rubric
```
Then the implementation skeleton in the repo's convention (or via an MCP-builder skill for MCP). Before committing, run `/dimi:pr-security-data-review` on the diff; agent tools are where personal data and gate bypasses most often slip in. If the tool lives in an MCP server, run `/dimi:harden-mcp <path>` as well: it checks the server against the current MCP spec revision (OAuth 2.1 resource-server auth, audience validation, no token passthrough, SSRF, path confinement) and has tested fix patterns for each.