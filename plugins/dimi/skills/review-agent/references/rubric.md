> As of 25 October 2026. Re-verify the framework defaults named in E4, H3 and L3 against the vendors' current docs (Context7 or the official pages) with `/dimi:refresh-harness`.

# Agent production-readiness rubric

Run every check that applies. A finding needs file:line evidence that you have read, not just a search hit. If a check cannot be confirmed from the code (for example it depends on infrastructure you cannot see), record it under "Could not verify" rather than guessing.

Search hints use ripgrep syntax (`rg -n`, one `-e` per alternative so they paste as written). They find candidates only; confirm each one by reading the surrounding code.

## Severity

| Severity | Use when |
| --- | --- |
| Critical | Exploitable now or causes irreversible harm: model output executed without a sandbox, irreversible or financial action with no approval, cross-user or cross-tenant data access, secrets exposed to the model or logs, unrestricted data egress from an agent that reads untrusted content |
| High | Likely to cause an incident or failed security review: no budgets or step limits, non-idempotent writes that can retry, in-memory state in production, no authorisation inside tools, no tracing |
| Medium | Weakens reliability, cost control or auditability: no fallback model, unbounded tool outputs, floating model aliases, no eval set in CI, unstable prompt prefix |
| Low | Hygiene and clarity: thin tool descriptions, missing trace attributes, naming |

If the client profile's "Severity overrides for reviews" table names an id from this rubric, use that severity and cite the row in the finding; otherwise adjust severity to the profile's risk tiers when one exists.

## A. Control and budgets

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| A1 | Step or turn limits | Every agent loop has a maximum step, turn or recursion limit set deliberately, not left at a library default for long tasks | `rg -n -e max_turns -e recursion_limit -e max_iterations -e max_steps -e maxSteps -e stopWhen` |
| A2 | Token, cost and time budgets | Per-run budgets enforced in code, stopping the run and returning a partial result | `rg -n -e budget -e max_cost -e max_tokens -e deadline -e timeout` |
| A3 | Timeouts on calls | Every model, tool and HTTP call has a timeout | `rg -n "timeout="` and check HTTP clients created without one |
| A4 | Loop and stall detection | Repeated identical tool calls or no state change for N steps triggers a stop, re-plan or escalation | Look for a counter or signature check around the tool-call loop |

## B. Side effects

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| B1 | Stable idempotency keys | Write tools pass an idempotency key derived from run and step identity, or check an outbox or dedup table before sending | `rg -n -e 'uuid4\(' -e 'uuid\.uuid4' -e 'randomUUID\(' -e 'uuidv4\(' -e 'nanoid\(' -e 'time\.time\(\)'` inside tools or steps that perform writes; flag keys generated inside a step that can re-run |
| B2 | Approval for irreversible actions | Payments, deletes, external sends, merges and deploys require human approval | Find write tools, then look for an interrupt, `needs_approval`, `requireApproval`, `request_info`, `require_confirmation`, `HumanInTheLoopMiddleware` or `interrupt(` guarding them |
| B3 | Approval bound to the exact call | The approved action is stored as a hash of tool name and arguments, executed only if it matches, single-use, with an expiry and an approver check | Read the resume path: does it re-generate arguments after approval? |
| B4 | Compensation | Multi-step writes record undo actions or are otherwise recoverable on failure | Look for saga, rollback or compensation logic around multi-system writes |
| B5 | Side effects before interrupts | No side effect sits before an interrupt or approval point in a step that re-runs from its start on resume | LangGraph nodes re-run from the start on resume; check code above `interrupt(` |

## C. Identity and authorisation

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| C1 | Who tools act as | Delegated user tokens when a user is present; a dedicated least-privilege identity for autonomous runs; no shared admin credential | `rg -n -e ADMIN -e SERVICE_ACCOUNT -e ROOT_TOKEN -e MASTER_KEY -e SUPERUSER` used inside tools |
| C2 | Authorisation inside tools | Each tool checks the current user may act on the target resource; IDs supplied by the model are verified | Read tools that take customer, account, file or tenant IDs |
| C3 | Secrets kept from the model | No credentials in prompts, tool results, context or traces; injected at execution time from a vault or environment | `rg -n -e api_key -e secret -e password -e token -g '*prompt*'` and look for secrets interpolated into prompt strings |
| C4 | Least-privilege toolsets | Each agent gets only the tools its job needs | Compare each agent's tool list with its instructions |

## D. Prompt injection and data egress

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| D1 | Untrusted inputs identified | Every source of untrusted text is known: web fetch, search, email, uploaded files, tickets, RAG documents, MCP and A2A results | List them in the report inventory |
| D2 | Rule of two | No agent combines untrusted input, sensitive data or systems, and the ability to change state or communicate externally without human approval | Map each agent against the three properties |
| D3 | Outbound channels gated | Tools that send data out (HTTP fetch to arbitrary URLs, email, webhooks, rendering images or links from model output) are allowlisted or approval-gated | `rg -n -e 'requests\.get' -e 'requests\.post' -e httpx -e 'fetch\(' -e axios -e send_email -e smtp -e webhook` in tool code |
| D4 | Untrusted content labelled | Retrieved or fetched content is wrapped in delimiters with its source, kept out of the instruction section | Read prompt assembly code |
| D5 | MCP servers vetted | Only allowlisted servers, versions pinned, tool definitions reviewed; remote servers behind a gateway | `rg -n -e mcpServers -e MCPServer -e McpToolset -e MultiServerMCPClient -e mcp_servers` and config files such as `.mcp.json` |

## E. State and durability

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| E1 | Durable checkpointer in production | Postgres or another durable store; in-memory savers only in tests or local dev | `rg -n -e InMemorySaver -e MemorySaver -e InMemoryCheckpointStorage -e InMemorySessionService -e InMemoryStore` and check which config path uses them |
| E2 | Crash recovery | A supervisor, queue lease or heartbeat re-drives crashed runs; resume has been tested | Look for a worker or job runner that picks up stalled threads |
| E3 | Serialisable, versioned state | State is plain data and IDs, with a schema version; no clients or connections in state | Read the state type definitions |
| E4 | In-flight runs survive deploys | Runs are drained or pinned to the workflow version that started them | Microsoft Agent Framework cannot resume a checkpoint if workflow topology changed; check versioning |

## F. Failure handling

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| F1 | Retries | Transient errors and 429s retried with exponential backoff, jitter and Retry-After; no retry loops on non-transient errors | `rg -n -e retry -e backoff -e tenacity -e Retry-After` |
| F2 | Fallback model | A second model or provider configured, usually through a gateway | Look for gateway config or fallback lists |
| F3 | Tool errors returned to the model | Tool exceptions become short actionable messages, not stack traces or crashes | Read tool wrappers and error handlers |
| F4 | Output validation | Structured outputs validated against a schema; re-ask with the validation error on failure | `rg -n -e response_format -e output_type -e outputSchema -e with_structured_output -e BaseModel -e 'z\.object'` |
| F5 | Dead-letter handling | Repeatedly failing runs are parked for inspection instead of retried forever | Look for a failure queue or status |

## G. Context management

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| G1 | Long-run strategy | Trimming, compaction, tool-result clearing or sub-agents for long sessions | `rg -n -e summariz -e compact -e trim_messages -e SummarizationMiddleware` |
| G2 | Stable prompt prefix | Instructions and tool definitions first; no timestamps, random IDs or per-request data at the top of the system prompt | Read system prompt construction; flag `datetime.now()` or request IDs interpolated early |
| G3 | Tool count | Tens of tools are deferred, searched or split across sub-agents rather than all loaded every call | Count tools per agent |
| G4 | Call and result pairing | Trimming never drops a tool call without its result, or the reverse | Read trimming code |

## H. Observability

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| H1 | Tracing on every run | OpenTelemetry GenAI spans or the framework's tracing, exported to the client's backend | `rg -n -e opentelemetry -e enable_instrumentation -e LANGSMITH -e trace_processor -e set_tracing -e Langfuse -e logfire` |
| H2 | Tokens and cost recorded | Per-run token usage and cost, with cache and reasoning tokens counted once | Look for usage aggregation |
| H3 | Sensitive capture off by default | Prompt and output capture disabled or redacted in production | OpenAI Agents SDK `trace_include_sensitive_data` defaults to True; Agent Framework `ENABLE_SENSITIVE_DATA` should stay false; check LangSmith input hiding |
| H4 | Correlation IDs | Trace ID and conversation ID on every log line | Read logging setup |
| H5 | Telemetry not disabled globally | `OTEL_SDK_DISABLED` not used to silence one library, since it switches off all OpenTelemetry in the process | `rg -n "OTEL_SDK_DISABLED"` |

## I. Evaluation and change control

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| I1 | Eval set exists | Real cases with expected outcomes, versioned in the repo | `rg -l -e eval -e golden -e testset -e dataset -g '!node_modules'` |
| I2 | Evals in CI | Suite runs on pull requests and on model, prompt, tool or index changes | Check CI workflow files |
| I3 | Repeated trials | Cases run several times; pass rate and pass^k reported against an agreed tolerance | Read the eval runner |
| I4 | Pinned models | Dated model versions in production config; no `-latest` or floating aliases | `rg -n -e 'latest"' -e '\-latest' -e 'model="[a-z0-9.-]+"'` and review model config |
| I5 | Trajectory checks | Evals check tool choice and arguments, not only final text | Read eval assertions |
| I6 | Config on traces | Prompt, tool and model versions recorded on each trace | Look for version metadata on spans or runs |

## J. Tools

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| J1 | Descriptions | Each tool says what it does, when to use it, when not to, and what each argument means | Read tool definitions |
| J2 | Constrained schemas | Enums, formats, ranges and required fields; strict mode where supported | Read schemas |
| J3 | Bounded outputs | Pagination, truncation, IDs plus key fields instead of whole records | Look for tools returning raw API payloads |
| J4 | Sandboxed execution | Model-written code runs only in an isolated sandbox with no production credentials or open network | `rg -n -e 'exec\(' -e 'eval\(' -e subprocess -e shell=True -e 'os\.system' -e child_process -e 'vm\.run'` - Critical if fed model output outside a sandbox |
| J5 | Computer use isolated | Computer-use and browser actions run in a VM or browser sandbox you host, never on a developer or production machine | Find the executor for computer or browser actions |

## K. RAG (if present)

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| K1 | Permission filters in the query | Access filters applied inside the search request with the end user's identity | Read retrieval calls for filter arguments |
| K2 | Permission sync | ACL changes synced separately from content, with lag monitored | Read ingestion jobs; hash-only change detection misses permission changes |
| K3 | Hybrid search and reranking | Keyword plus vector retrieval, fused, then reranked | Look for BM25 or sparse vectors and a reranker call |
| K4 | Citations | Answers cite retrieved sources; "no good source" handled | Read answer assembly |
| K5 | Retrieval evals | Recall@k or Ragas-style metrics on a labelled set | Look for retrieval tests |
| K6 | Deduplication and versions | Near-duplicates removed, superseded documents marked | Read ingestion |

## L. Data governance

| ID | Check | What good looks like | Search hints |
| --- | --- | --- | --- |
| L1 | PII in logs | Redaction before logs or traces leave the process | Look for redaction or DLP steps |
| L2 | Retention | Retention set for checkpoints, memory, traces and caches | Check config and infrastructure code |
| L3 | Zero-data-retention fit | Hosted features used are eligible under the client's data terms (for example Anthropic's MCP connector and Claude Managed Agents are not ZDR-eligible; OpenAI Agents SDK tracing is unavailable to ZDR orgs) | List hosted features in use |
| L4 | Tenant isolation | Separate indexes, namespaces or row-level security; caches and memory never shared across tenants | Read store and cache keys |
