# Agent framework landscape (dated)

> As of 24 October 2026. Names, statuses and positioning change quickly: before relying on any line here, confirm against current docs (Context7 or the vendor's pages), and prefer the maintained decision table in `${CLAUDE_PLUGIN_ROOT}/skills/harness-reference/references/frameworks.md`.

## Constraints decide before features

The client's or company's cloud, language and model contract usually settle the framework before any feature comparison does: Azure/.NET → Microsoft Agent Framework; GCP/Gemini → Google ADK; AWS-first → Strands or LangGraph on Bedrock AgentCore; OpenAI-centric → OpenAI Agents SDK (+ Temporal for durability); Claude-first coding/file/ops agents → Claude Agent SDK or Managed Agents; TypeScript shop → Mastra or Vercel AI SDK; strict typing in Python → Pydantic AI. If `.claude/fde-client-profile.md` exists, its approved models, cloud and regions are hard constraints. Read `${CLAUDE_PLUGIN_ROOT}/skills/harness-reference/references/frameworks.md` (dated decision table) and `playbook.md` (reference stack) before scoring — they are maintained with "as of" dates and refreshed by `/dimi:refresh-harness`; this skill is not the place for version facts.

Candidates to evaluate (verify each one's current state in section 0; the characterisations below are stable intent, not API facts):
- **Claude Agent SDK** (TypeScript/Python): the agentic loop, tools, MCP, subagents, hooks and permissions as a library; strongest when the product is Claude-first and you want a production harness rather than a thin loop. **Anthropic Managed Agents**: the same, hosted with a managed sandbox, when you do not want to run the loop or the sandbox yourself.
- **OpenAI Agents SDK** (Python/TS): handoffs, guardrails and tracing; OpenAI-first.
- **LangGraph**: explicit graph/state machine with checkpoints, durable execution and human-in-the-loop interrupts; choose when control flow must be explicit and resumable.
- **Pydantic AI** (Python): typed outputs and dependency injection, provider-agnostic; choose when strong typing and testability lead.
- **Google ADK**: Gemini-first, multi-agent with built-in eval tooling.
- **Vercel AI SDK** (TS): streaming UI primitives, provider-agnostic; choose for web apps where the chat UI is the product.
- **Mastra** (TS): workflows, memory and evals in one Node package.
- **CrewAI / AutoGen**: role-based multi-agent; good for prototypes, weigh maturity for production.
- **No framework**: provider SDK plus MCP client, when the loop is simple. Often right for a first version.


## Candidates (stable intent, not API facts)

- **Claude Agent SDK** (TypeScript/Python): the agentic loop, tools, MCP, subagents, hooks and permissions as a library; strongest when the product is Claude-first and you want a production harness rather than a thin loop. **Anthropic Managed Agents**: the same, hosted with a managed sandbox, when you do not want to run the loop or the sandbox yourself.
- **OpenAI Agents SDK** (Python/TS): handoffs, guardrails and tracing; OpenAI-first.
- **LangGraph**: explicit graph/state machine with checkpoints, durable execution and human-in-the-loop interrupts; choose when control flow must be explicit and resumable.
- **Pydantic AI** (Python): typed outputs and dependency injection, provider-agnostic; choose when strong typing and testability lead.
- **Google ADK**: Gemini-first, multi-agent with built-in eval tooling.
- **Vercel AI SDK** (TS): streaming UI primitives, provider-agnostic; choose for web apps where the chat UI is the product.
- **Mastra** (TS): workflows, memory and evals in one Node package.
- **CrewAI / AutoGen**: role-based multi-agent; good for prototypes, weigh maturity for production.
- **No framework**: provider SDK plus MCP client, when the loop is simple. Often right for a first version.
