---
name: harness-reference
description: Reference knowledge for building production LLM agents (the "agentic harness") - orchestration, agent frameworks, tools and MCP, RAG, observability, evals, security and FDE delivery practice. Use when designing, building or reviewing agent code, choosing an agent framework or vector store, writing tools or MCP servers, building RAG, adding tracing, cost tracking or evals, or planning an agent engagement for a client.
when_to_use: Examples - "which agent framework should we use", "add human approval to this tool", "how should we chunk these PDFs", "set up tracing for the agent", "is this agent production ready".
user-invocable: false
---

# Agentic harness reference

Use these files as the default engineering stance for agent work. Read only the file the task needs.

## First, check for a client profile

If `.claude/fde-client-profile.md` exists in the current project, read it before giving advice. Its rules (cloud, approved models, regions, risk tiers, data classes, identity provider, observability stack) override the defaults below.

## Which file to read

| Task or question | Read |
| --- | --- |
| What a harness is; the four layers | [overview.md](references/overview.md) |
| Workflow shapes, fixed vs dynamic plans, multi-agent and A2A, human approval, checkpoints, context management, failure recovery | [orchestration.md](references/orchestration.md) |
| Choosing or comparing frameworks, managed runtimes, durable engines, low-code tools, agent protocols (dated) | [frameworks.md](references/frameworks.md) |
| Tool design, provider-hosted tools, MCP spec, MCP security, gateways, tool search, skills, sandboxes | [tools-and-mcp.md](references/tools-and-mcp.md) |
| Loading, parsing, chunking, embedding, vector stores, retrieval, re-ranking, ingestion and permissions | [rag.md](references/rag.md) |
| Monitoring, tracing, logging, EU AI Act logging, cost and token accounting, evaluation, benchmarks | [observability.md](references/observability.md) |
| Security and guardrails, agent identity, model gateways and self-hosting, prompt and config management, red teaming, runtime patterns, data governance | [cross-cutting.md](references/cross-cutting.md) |
| Delivery plan, reference stack, production readiness checklist | [playbook.md](references/playbook.md) |
| Where a fact came from; where to check for changes | [sources.md](references/sources.md) |

Cross-references inside the files use the guide's part numbers: Part 1 is orchestration.md (plus frameworks.md), Part 2 is tools-and-mcp.md, Part 3 is rag.md, Part 4 is observability.md, Part 5 is cross-cutting.md.

## Defaults to apply without being asked

1. Start with the simplest workflow that works: a fixed graph of stages, with agentic steps only where the steps cannot be known in advance.
2. Enforce budgets in code: maximum steps, tokens, cost and wall-clock time per run, plus timeouts on every model and tool call.
3. Give every write tool a stable idempotency key derived from the run (thread ID plus step, plus the tool-call ID only if the model message is checkpointed before the tool runs, else the call's ordinal), never one generated fresh inside a step that can re-run.
4. Writes are human-accepted proposals by default; a reversible write may run without approval only when the client profile explicitly allows it and the rule of two (default 6) still holds, with a sample reviewed by a person. Irreversible or financial actions always require human approval. Bind each approval to a hash of the exact tool name and arguments, single-use and with an expiry.
5. Tools act with the user's delegated permissions, or a dedicated least-privilege agent identity for autonomous runs. Authorise inside the tool, never in the prompt.
6. Treat every tool result, retrieved document and remote agent output as untrusted. No agent should combine all three of: untrusted input; access to sensitive data or systems; the ability to change state or communicate externally, without human approval (the rule of two).
7. Checkpoint state to a durable store (Postgres by default) and have a supervisor re-drive crashed runs.
8. Return tool errors to the model as short, actionable messages; retry transient errors with backoff and jitter; configure a fallback model.
9. Keep the prompt prefix stable (instructions and tool definitions first) so prompt caching works; trim or compact context in large, infrequent steps.
10. Emit OpenTelemetry GenAI spans for every run, with prompt and output capture off by default.
11. Pin dated model versions. Run the eval set with repeated trials on every model, prompt, tool or index change.
12. For RAG: strong parser, structure-aware chunks, hybrid search with a reranker, permission filters inside the query, permission sync separate from content sync.

## Scaffolding a new agent

To start a project that follows these defaults, offer the author `/dimi:agent-bootstrap` (not model-invocable): it fetches current framework docs first, scores the choice against the decision table in [frameworks.md](references/frameworks.md), and lays down budgets, tracing, evals and human-in-the-loop from day one. For tool contracts, offer `/dimi:agent-tool-design`.

## Facts that go stale

Each reference file carries its own "as of" note in its first line; when files disagree, quote the oldest date. Before quoting a version, status, price, spec revision or acquisition to a client, or pinning a dependency:

- Check the live source: use the Context7 docs tools if available, otherwise the official pages listed in [sources.md](references/sources.md).
- Prefer current official docs over these files for exact API signatures and parameter names.
- To update the files themselves, ask the author to run `/dimi:refresh-harness` from a checkout of the dimi-skills repository (it is not model-invocable).
