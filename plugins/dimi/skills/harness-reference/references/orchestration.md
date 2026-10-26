# Orchestration layer

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Contents:

- Workflow architectures
- Ahead-of-time designed workflows and planned stages
- Dynamic workflow design and stage planning
- Multi-agent collaboration, communication and data hand-offs (A2A)
- Human-in-the-loop approvals
- Checkpoints, pausing and resuming
- Automated state and context management
- Failure recovery

## Workflow architectures

A workflow architecture is the shape of control flow: it decides whether your code or the model chooses the next step. Every pattern below sits somewhere between fully scripted and fully autonomous.

| Pattern | How control flows | Good for | Watch out for |
| --- | --- | --- | --- |
| Prompt chain (sequential) | Fixed steps; each output feeds the next, with optional checks between steps | Extract, then validate, then summarise | Errors compound; latency adds up step by step |
| Router | A classifier (model or rules) sends the input down one branch | Support triage; sending easy questions to a cheaper model | Misroutes; always keep a fallback branch |
| Parallel (fan-out, fan-in) | Independent subtasks run at once and are merged; or one task runs N times and the results are voted on | Multi-source research; running safety checks beside the main answer | Merge logic; cost multiplies by N |
| Orchestrator and workers | A lead model splits the task at runtime and delegates the pieces | Code changes across many files; deep research | The lead becomes a bottleneck; hand-offs lose context |
| Evaluator and optimiser (reflection) | One step drafts, another critiques, and the loop repeats until it passes | Writing, translation, code that must pass tests | Endless loops; cap the iterations |
| Autonomous loop (ReAct) | The model picks tool calls in a loop until it decides it is done | Open-ended tasks with unknown steps | Cost, drift; needs budgets and guardrails |
| Graph or state machine | Nodes and edges over shared state, including conditional edges and cycles | Production agents that need both control and loops | More design work up front |
| Event-driven (actor model) | Agents react to messages on a bus; no central script | Large, distributed multi-agent systems | Hard to trace and reason about |

Most production systems are hybrids: a deterministic graph whose individual nodes are agentic. The practical rule is to start with the simplest shape that works, and add autonomy only where the steps genuinely cannot be known in advance.

## Ahead-of-time designed workflows and planned stages

An ahead-of-time workflow is designed by an engineer before it runs: the stages, their order, the branches and the exits are fixed in code or config, and the model only does the work inside each stage. This is the default for enterprise work because it is predictable, testable and easy to audit.

**How they are expressed**

- **Plain code**: functions that call the model and each other. Fine for three or four steps; it gets messy once you need retries, pauses and branches.
- **Graph APIs**: nodes and edges over a shared state object. Examples are LangGraph's `StateGraph`, Microsoft Agent Framework workflows (executors joined by edges), Google ADK 2.x graph workflows (which supersede its older `SequentialAgent`, `ParallelAgent` and `LoopAgent`), Mastra workflows (`.then()`, `.branch()`, `.parallel()`) and CrewAI Flows (`@start`, `@listen`, `@router`).
- **Declarative config**: YAML or JSON definitions that a runtime executes, such as CrewAI's `agents.yaml` and `tasks.yaml` or Agent Framework's declarative YAML workflows. Good when non-engineers need to read or change the flow.
- **Visual builders**: drag-and-drop canvases such as Microsoft Copilot Studio, n8n, Dify and Langflow. Fast to prototype; harder to version, test and review. OpenAI is shutting down its Agent Builder on 30 November 2026, a reminder that a hosted builder can disappear from under a client.

**What a well-designed stage has**

1. A typed input and output contract, enforced with structured outputs (Pydantic, Zod or JSON Schema), so the next stage never parses free text.
2. A gate after it: a validation check (schema, business rule or small model judge) that decides pass, retry or escalate.
3. A bounded loop where loops exist, with a maximum iteration count.
4. An explicit fallback path: a human queue, a simpler model, or a safe default answer.
5. Its own trace span and cost counter, so you can see which stage is slow or expensive.

**Worked example: invoice processing**

1. Extract fields from the PDF (vision model, structured output).
2. Validate totals, dates and VAT numbers in code.
3. Match the invoice to a purchase order with a lookup tool.
4. If the match fails or the amount is over a threshold, pause for human review.
5. Post the approved invoice to the ERP through an idempotent API call.

| Strengths | Weaknesses |
| --- | --- |
| Predictable cost and latency | Brittle when inputs vary more than expected |
| Each stage can be unit-tested and evaluated | Every new case needs an engineer to change the graph |
| Easy to explain to compliance and auditors | Can under-use the model's judgement |
| Failures are localised to a stage | Many branches become hard to maintain |

For an FDE, this is usually the right first delivery: clients trust a flow they can see on a whiteboard, and you can add agentic autonomy inside individual stages later.

## Dynamic workflow design and stage planning

In a dynamic workflow the model designs the plan at runtime: it decides which stages are needed, in what order, and revises the plan as results come in. Use it when the steps depend on what the agent discovers, such as debugging, research or open-ended analysis.

| Technique | How it works | Typical use |
| --- | --- | --- |
| ReAct | Reason, act, observe, repeat; no explicit plan is written down | Short tool-using tasks |
| Plan-and-execute | A planner writes a step list; an executor runs each step; a re-planner revises after each result | Multi-step tasks where a visible plan helps |
| Living to-do list | The agent keeps a written checklist in its context or a file and ticks items off | Long coding and research sessions |
| Hierarchical decomposition | An orchestrator creates subtasks and spawns sub-agents, each with a fresh context | Broad research; large codebases |
| Ledger-based orchestration | The orchestrator keeps a task ledger (facts, plan) and a progress ledger (is progress being made, who acts next) and re-plans when stuck; the Magentic-One pattern | Open-ended multi-agent work |
| Code as plan | The model writes a script or a small graph, and the harness executes it in a sandbox | Data analysis; batch tool use |
| Search over plans | Several candidate plans are explored and scored before committing | Rare in production because of cost |

**Guardrails that make dynamic plans safe**

- Budgets: maximum steps, tokens, wall-clock time and cost per run, enforced by the harness rather than the prompt.
- An allowlist of tools per agent, so a plan cannot reach for capabilities it was never given.
- Plan validation: the plan is emitted as structured output and checked against a schema and business rules before execution.
- Plan approval: for high-stakes tasks, a human approves the plan once instead of approving every step.
- Stall detection: repeated identical tool calls, or no state change for N steps, triggers a re-plan or escalation.

**The hybrid pattern most teams converge on**

Keep the outer stages fixed and let the model plan inside a stage. For example, a support system has fixed stages (classify, resolve, respond, log), but the resolve stage is an agent that plans its own investigation with read-only tools. This gives you auditability at the top and adaptability where it is actually needed.

## Multi-agent collaboration, communication and data hand-offs (A2A)

A multi-agent system splits work across specialised agents, each with its own instructions, tools and context window. The harness decides who talks to whom, how control passes between them, and what data travels with it. Split only when one agent is genuinely overloaded: every extra agent adds latency, cost and a hand-off that can lose information.

**Topologies**

| Topology | How it works | Good for |
| --- | --- | --- |
| Supervisor (manager) | A lead agent delegates to workers and assembles their results; workers never talk to each other | Most enterprise cases; easiest to control |
| Hand-off (swarm) | The active agent transfers control to a peer, which then owns the conversation | Customer service routing between specialists |
| Sequential pipeline | Agent A's output is agent B's input | Draft, review, publish |
| Concurrent | Several agents work on the same input at once; results are aggregated | Multiple expert opinions; parallel research |
| Group chat | Agents share one conversation; a manager picks the next speaker | Brainstorming; debate; review panels |
| Magentic (ledger) | An orchestrator plans, tracks progress and re-assigns work dynamically | Open-ended tasks with unknown steps |
| Blackboard | Agents read and write a shared state store instead of messaging | Loosely coupled, long-running systems |

**Two ways for one agent to use another**

- **Agent as a tool**: the caller invokes the other agent like a function, gets a result back and keeps control. Use it when the specialist answers a sub-question.
- **Hand-off**: control transfers and the receiving agent now owns the interaction. Use it when the specialist should take over the conversation.

**Data hand-offs: what to pass**

- **Full history**: simplest, but expensive, and it floods the receiver with irrelevant context.
- **Filtered history**: drop tool chatter and keep the user's turns and key results.
- **Structured brief**: a schema-validated summary of goal, facts found, constraints and open questions. This is the most reliable option for production.
- **References, not payloads**: pass a file path, blob ID or URL to large artifacts instead of pasting them inline.
- **Condensed returns**: sub-agents should return a short result, not their whole transcript, so the orchestrator's context stays clean.

**The A2A protocol**

Agent2Agent (A2A) is an open standard for agents built on different frameworks, by different vendors, to discover each other and delegate work over the network. Google launched it in April 2025 and donated it to the Linux Foundation; IBM's Agent Communication Protocol merged into it in August 2025, and v1.0 shipped in March 2026 ([AAIF](https://aaif.io/blog/a2a-joins-aaif)). On 17 August 2026 it became a hosted project of the Agentic AI Foundation, alongside MCP, AGENTS.md, goose and agentgateway ([AAIF](https://aaif.io/blog/a2a-joins-aaif)). The Linux Foundation reported over 150 supporting organisations at its first anniversary ([Linux Foundation](https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year)).

Core concepts in the 1.0.0 specification ([A2A spec](https://a2a-protocol.org/latest/specification/)):

- **Agent Card**: a JSON document published by the remote agent describing its identity, skills, endpoint, supported interfaces and authentication requirements, so a client agent can discover how to work with it.
- **Task**: a stateful unit of work with a server-generated ID. States include working, input-required, auth-required, completed, failed, canceled and rejected.
- **Message and Part**: one turn with a role of user or agent, made of parts that carry text, a file reference or structured data.
- **Artifact**: the output a task produces, also made of parts.
- **Context ID**: groups related tasks and messages into one conversation.
- **Operations**: send message (blocking or non-blocking), streaming send, get, list, cancel and subscribe to tasks, plus push-notification webhooks for long-running work.
- **Bindings**: JSON-RPC, gRPC and HTTP+JSON (REST). Clients send an `A2A-Version` header; 1.0 made breaking changes from 0.3, so check which version a counterpart speaks.
- **Security**: declared on the Agent Card; API key, HTTP auth, OAuth 2 flows, OpenID Connect and mutual TLS.
- **Trust**: treat Agent Cards and everything a remote agent returns as untrusted input, with the same prompt-injection precautions as MCP tool results.

The key design idea is that agents stay opaque: a remote agent exposes skills, not its prompts, memory or tools. That makes A2A the right fit for crossing team, vendor or company boundaries. **MCP connects an agent to tools and data; A2A connects an agent to another agent.** Inside a single codebase, a framework's native hand-offs are simpler than A2A.

## Human-in-the-loop approvals

Human-in-the-loop (HITL) means the harness pauses at defined points so a person can approve, edit, reject or answer before the agent continues. In enterprise deployments it is usually the feature that gets an agent past risk review, so design it in from day one.

**Common HITL patterns**

| Pattern | When the pause happens | Example |
| --- | --- | --- |
| Approve or reject a tool call | Before an action with side effects | Sending an email, issuing a refund, merging a PR |
| Edit the arguments | Same point; the human can change the call before it runs | Correcting the amount on a payment |
| Review the output | After generation, before delivery | A contract clause or customer reply |
| Answer a question | The agent lacks information and asks | "Which cost centre should this go to?" |
| Approve the plan | Once, before a dynamic plan executes | A migration plan across 40 services |
| Escalate | Confidence is low or a policy is hit | A fraud-score threshold or a complaint keyword |
| Human as a tool | The agent calls an `ask_human` tool whenever it chooses | Research agents that check assumptions |

**How it works under the hood**

1. The agent reaches an approval point and the harness raises an interrupt instead of executing.
2. The full run state is saved to a checkpoint (see the next section), so nothing is held in memory.
3. The harness notifies a person through a UI, Slack, Teams or email, showing what the agent wants to do and why.
4. The run waits for seconds or days, consuming no compute.
5. The person's decision is written back into the state, and the run resumes from the saved point.

This is why HITL and checkpointing are inseparable: without durable state, a pause longer than one HTTP request loses the run. Examples of the mechanism are LangGraph's `interrupt()` resumed with `Command(resume=...)`, Mastra's workflow `suspend()` and `resume()`, and per-tool approval flags in several SDKs; the framework section lists each one's approach.

**Design rules that hold up in production**

- **Tier by risk**: read-only actions on internal systems run automatically; writes are human-accepted proposals by default; a reversible write may run without approval only when the client profile explicitly allows it, with a sample reviewed by a person afterwards; irreversible or financial actions always need approval. Any tool that can reach an external address (a URL fetch, a web search, an image render) is an outbound channel and follows the rule of two (Part 5; the lethal trifecta in Part 2), even if it only reads.
- **Bind the approval to the exact action**: store a hash of the tool name and arguments with each interrupt, execute only that exact call, make each approval single-use with an expiry, and check that the approver is allowed to approve it.
- **Show context, not just the call**: the reviewer needs the agent's reasoning, the source data and a diff of what will change.
- **Set timeouts and defaults**: decide what happens if nobody answers, such as escalating or cancelling safely.
- **Keep an audit trail**: who approved what, when and with which edits. Regulated clients will ask for it.
- **Watch for approval fatigue**: if reviewers approve 99% of requests unread, the control is theatre. Raise the threshold or improve the agent.
- **Use rejections as data**: every rejection or edit is a labelled example for your evaluation set.

## Checkpoints, pausing and resuming

A checkpoint is a saved snapshot of a run's state, written after each step, so the run can pause, survive a crash, resume later, or be rewound and replayed. It turns an agent from a fragile in-memory loop into a durable process.

**What a checkpoint contains**

- The state values: message history, working variables, intermediate results.
- Where the run is: which node or step runs next, and any pending tool calls or interrupts.
- Identity: a thread or session ID (one conversation or job), a checkpoint ID and a parent checkpoint ID.
- Metadata: step number, timestamps, which agent wrote it.

**Where checkpoints are stored**

In-memory savers are for development only. Postgres is the common production default; SQLite suits only single-process deployments; Redis, Cosmos DB, Firestore or DynamoDB are common on managed clouds. Pick the store your client already operates, because they will own backups and retention.

**What checkpoints enable**

| Capability | What it means |
| --- | --- |
| Pause and resume | Stop for human input and continue hours or days later, on a different server |
| Crash recovery | A crashed run can resume from its last completed step once a supervisor or job queue notices it (by heartbeat or lease) and re-invokes the thread; durable engines do this automatically |
| Multi-turn memory | Each new user message continues the same thread's state |
| Time travel | Inspect the state at any past step, edit it, and fork a new run from there |
| Replay debugging | Re-run a failed production trace step by step |
| Long-running jobs | Work that spans many hours survives deploys and restarts |

**Framework checkpointers versus durable execution engines**

Framework checkpointers (LangGraph, Agent Framework workflows and others) save state at step boundaries inside the framework. Durable execution engines such as Temporal, Restate, DBOS and Inngest go further: they record every step's result in an event history and deterministically replay the workflow after any failure, with built-in retries, timers and signals. Several agent SDKs now integrate with them; for example the OpenAI Agents SDK documents a Temporal integration for long-running and human-in-the-loop work ([GitHub](https://github.com/openai/openai-agents-python)). Use a framework checkpointer for most agents; add a durable engine when runs last hours, touch money, or must never be lost.

**Pitfalls**

- **Re-execution on resume**: many frameworks re-run the interrupted step from its beginning. Any side effect before the pause point runs twice unless it is idempotent.
- **Non-serialisable state**: open connections, file handles and client objects cannot be checkpointed. Keep state to plain data and IDs.
- **Schema drift**: a deploy that changes the state schema can break resumption of runs saved under the old one. Version your state.
- **Unbounded growth**: a checkpoint per step adds up. Set retention and prune old threads.

## Automated state and context management

State is everything the harness tracks about a run; context is the slice of it the model actually sees on each call. Managing both automatically is what keeps long-running agents coherent and affordable, and it is now often called context engineering.

**Kinds of state**

| Kind | Lifetime | Examples | Typical store |
| --- | --- | --- | --- |
| Conversation history | One thread | User and agent turns, tool calls and results | Checkpointer or session store |
| Working state | One run | Plan, variables, partial results, flags | Typed state object in the graph |
| Long-term memory | Across sessions | User preferences, learned facts, past decisions | Memory store or vector database |
| Artifacts | Any | Files, reports, generated code | Blob storage, referenced by ID |

**State mechanics to get right**

- **Typed schemas**: define state as a class or schema, not a loose dictionary, so bad writes fail fast.
- **Reducers**: rules for merging updates, such as append to the message list but overwrite the status field. They matter most when parallel branches write the same key.
- **Scoping**: separate per-run, per-user and app-wide state. Google ADK, for example, uses key prefixes to scope session state to a user, the app or a single invocation.
- **Isolation between tenants**: one client's data must never appear in another's context. Enforce it in the store, not the prompt.

**Context engineering techniques**

1. **Trimming**: drop the oldest turns once a window is exceeded. Cheap, but it forgets.
2. **Compaction**: when near the limit, replace older turns with a model-written summary that keeps decisions, open tasks and key facts.
3. **Tool-result clearing**: shorten or remove old tool outputs, which are often the bulk of the tokens.
4. **Offloading**: write large data to a file or store and keep only a pointer in context.
5. **Note-taking**: the agent maintains a notes or progress file it can re-read after compaction.
6. **Retrieval**: fetch only the memories and documents relevant to the current step (the RAG layer).
7. **Sub-agent isolation**: give exploratory work to a sub-agent with a fresh context that returns a short summary.
8. **Prompt caching**: keep the system prompt and tool definitions stable at the start of the prompt so the provider can cache them, which cuts cost and latency on every call.
9. **Trim in large, infrequent steps**: every trim, clear or compaction changes the prompt and forces a fresh cache write, so act at a threshold (for example 80% full) rather than every turn, and always keep a tool call together with its result, since providers reject one without the other.

**Long-term memory options**

Memory layers such as Mem0, Zep (Graphiti) and LangMem extract facts from conversations, store them, and retrieve them in later sessions. Several model providers and frameworks also ship native memory features. Treat memory as user data: give users a way to view and delete it, and keep it out of shared contexts.

**Failure modes to watch**

- **Context rot**: answer quality degrades as the context fills, even below the hard limit.
- **Lost in the middle**: facts buried mid-context are used less reliably than those at the start or end.
- **Poisoning**: one wrong fact gets repeated into summaries and memory, then treated as truth.
- **Tool bloat**: dozens of tool definitions consume context before the task even starts (see Part 2).

## Failure recovery

Agents fail in more ways than ordinary software: on top of network and API errors, the model can return malformed output, pick the wrong tool, loop, or confidently get the answer wrong. The harness needs a recovery strategy for each failure class, not one generic retry.

| Failure | How you detect it | How the harness recovers |
| --- | --- | --- |
| Transient API or network error | HTTP 5xx, timeouts | Retry with exponential backoff and jitter |
| Rate limit | HTTP 429 | Back off, honouring any Retry-After header; queue work |
| Model provider outage | Error spike, latency spike | Fail over to another model or provider through a gateway |
| Malformed output | Schema validation fails | Use structured outputs; re-ask with the validation error included |
| Tool raises an error | Exception inside the tool | Return the error text to the model as the tool result so it can self-correct |
| Wrong tool or bad arguments | Argument validation, guardrails | Reject with an explanation; narrow the tool list |
| Loop or no progress | Max steps hit; identical calls repeated; no state change | Stop, re-plan, or escalate to a human |
| Budget overrun | Token, cost or time counters | Hard stop; return a partial result with a note |
| Process crash mid-run | Missing heartbeat | Resume from the last checkpoint |
| Unsafe or off-policy output | Guardrail or classifier | Block, regenerate or escalate |
| Wrong answer | Evaluator, grounding check, user feedback | Reflect and retry; require citations; route to review |

**Principles**

- **Make side effects idempotent, with stable keys**: derive the idempotency key from the run (thread ID plus tool-call or step ID), or save it in state before the call, so every retry and resume reuses the same key. A key generated fresh inside a step that re-runs gives no protection. Where the target API has no idempotency support, record the intent in an outbox or dedup table and check it before sending.
- **Compensate instead of rolling back**: for multi-step writes, record an undo action for each completed step (the saga pattern) and run them in reverse on failure.
- **Errors are context**: a clear tool error message ("date must be ISO 8601, got 03/04") lets the model fix itself; a stack trace wastes tokens.
- **Circuit breakers**: stop calling a tool or provider that keeps failing, and route around it for a while.
- **Degrade gracefully**: a partial answer that says what is missing beats a timeout.
- **Dead-letter queue**: park runs that fail repeatedly for human inspection instead of retrying forever.
- **Trace every failure**: recovery you cannot see is recovery you cannot improve (Part 4).
