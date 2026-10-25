# Agent frameworks and platforms (dated)

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Versions and statuses below were read from package registries and official docs on 24 October 2026. Re-check before pinning or recommending. Code blocks in this file are fragments adapted from vendor docs, not runnable as written: names such as `chat_client`, `mock_llm`, `researcher`, `Crew`, `z` and `createStep` are assumed to be imported or defined elsewhere, and the APIs change with each release.

Contents:

- Frameworks compared
    - Microsoft Agent Framework
    - Semantic Kernel, AutoGen and AG2
    - Google Agent Development Kit (ADK)
    - OpenAI Agents SDK
    - LangChain, LangGraph and Deep Agents
    - CrewAI
    - Mastra
    - Other frameworks and platforms you may have missed
    - Choosing a framework on an engagement

## Frameworks compared

As of October 2026 the field has consolidated: Microsoft has folded Semantic Kernel and AutoGen into Microsoft Agent Framework, Google ADK has moved to a 2.x graph runtime, and LangGraph, CrewAI and Mastra are all past 1.0. Versions below were checked against the package registries on 24 October 2026; these projects release every week or two, so re-check before you pin.

**At a glance**

| Framework | Languages | Latest version | Licence | Status |
| --- | --- | --- | --- | --- |
| Microsoft Agent Framework | Python, .NET (Go in preview) | Python 1.23.0, .NET 1.26.0 | MIT | Active; 1.0 GA 3 Apr 2026 with long-term support |
| Semantic Kernel | C#, Python, Java | Python 1.45.0, .NET 1.81.0 | MIT | Sustain only: critical and security fixes, new features go to Agent Framework |
| AutoGen | Python, .NET | 0.7.5 (Sep 2025) | MIT | Maintenance mode since Oct 2025 |
| AG2 (community AutoGen fork) | Python | 1.2.1 | Apache-2.0 | Active; 1.0 rewrite Jul 2026 |
| Google ADK | Python, TypeScript, Go, Java, Kotlin | Python 2.13.0, TS 2.3.0, Go 2.6.0, Java 1.13.0 | Apache-2.0 | Very active; 2.0 GA May 2026 (Python) |
| OpenAI Agents SDK | Python, TypeScript | Python 0.24.0, JS 0.21.0 | MIT | Very active; still pre-1.0 |
| LangChain and LangGraph | Python, TypeScript | langchain 1.4.7, langgraph 1.2.17 (Python) | MIT | Very active; 1.0 Oct 2025 |
| CrewAI | Python | 1.15.30 | MIT | Very active; 1.0 Oct 2025 |
| Mastra | TypeScript | @mastra/core 1.79.0 | Apache-2.0; `ee/` folders source-available | Very active; 1.0 Jan 2026 |

**How each handles the Part 1 features**

| Framework | Orchestration model | Human-in-the-loop | Checkpoints and state | MCP | A2A | Tracing |
| --- | --- | --- | --- | --- | --- | --- |
| Microsoft Agent Framework | Graph workflows (executors, edges, supersteps) plus prebuilt Sequential, Concurrent, Handoff, Group Chat and Magentic | `ctx.request_info()` with response handlers; tool approval requests | Checkpoints at superstep boundaries in memory, file or Cosmos DB; time travel | Yes, stable | Yes; Python package still beta | OpenTelemetry built in |
| Google ADK 2.x | Graph workflows, dynamic nodes, LLM agents with sub-agents | Tool confirmation (`require_confirmation=True`), experimental | Session services (in-memory, database, Vertex); `user:`, `app:`, `temp:` state prefixes | Consume and expose | Experimental | OpenTelemetry |
| OpenAI Agents SDK | Hand-offs and agents-as-tools, or plain code; no graph engine | `needs_approval` on tools; serialisable `RunState` | Many session backends; Temporal, Restate, DBOS and Dapr integrations | Yes | No native support | On by default to OpenAI's dashboard; unavailable to zero-data-retention orgs |
| LangGraph (with LangChain) | `StateGraph` or the Functional API; `create_agent` with middleware on top | `interrupt()` and `Command(resume=...)`; approve, edit, reject or respond middleware | Checkpointers for memory, SQLite, Postgres, MongoDB, Cosmos; time travel and forking | Yes, MCP adapter | Through LangSmith Deployment endpoints | LangSmith |
| CrewAI | Role-based Crews inside event-driven Flows | `human_input=True`; `@human_feedback` in Flows | `@persist` on Flows; checkpoints and forking (JSON, SQLite) | Tools only | Yes, protocol 0.3 | Third-party integrations built on OpenTelemetry |
| Mastra | Workflows (`.then`, `.parallel`, `.branch`, loops) and agent networks | `suspend()` and `resume()`; `requireApproval` on tools | Snapshots in LibSQL or Postgres; restart active runs after a crash | Client and server | v0.3 and v1.0 | Built-in tracing with exporters |

### Microsoft Agent Framework

Agent Framework is Microsoft's single SDK for both standalone agents and graph workflows, built as the successor to Semantic Kernel and AutoGen. Version 1.0 shipped on 3 April 2026 for .NET and Python with stable APIs and long-term support ([Microsoft](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/)).

- **Stable in 1.0**: model connectors (Foundry, Azure OpenAI, OpenAI, Anthropic Claude, Amazon Bedrock, Gemini, Ollama), middleware at the agent, tool and chat-client levels, memory and context providers (Mem0, Redis, Neo4j), checkpointed workflows, the five prebuilt orchestrations, declarative YAML and MCP ([Microsoft](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/)). A2A support shipped with 1.0, but its Python package is still a beta on PyPI as of 24 October 2026.
- **Preview at 1.0 (April 2026)**: DevUI (a local debugging UI, explicitly not for production), Foundry hosted-agent integration, AG-UI and Skills. Foundry Hosted Agents itself reached GA in July 2026, but the Python hosting and DevUI packages are still betas.
- **Workflows**: executors joined by edges run in supersteps; workflows can fan out, fan in, nest and be wrapped as agents with `.as_agent()` ([Microsoft Learn](https://learn.microsoft.com/en-us/agent-framework/workflows/)).
- **Checkpoint caveat**: a checkpoint can only be resumed if the workflow topology and executor IDs are unchanged, so version workflows deliberately ([Microsoft Learn](https://learn.microsoft.com/en-us/agent-framework/workflows/checkpoints)).
- **Hosting**: Foundry Hosted Agents (deployed with `azd`), Azure Functions or Durable Functions, or self-hosted.
- **Best fit**: Azure and .NET enterprises that need typed, checkpointed workflows with approvals and long-term support. **Weakness**: much of the operational tooling is still beta, Go lags, and the gravity is towards Azure.

```python
from agent_framework.orchestrations import SequentialBuilder

writer = chat_client.as_agent(instructions="Concise copywriter...", name="writer")
reviewer = chat_client.as_agent(instructions="Brief reviewer...", name="reviewer")
workflow = SequentialBuilder(participants=[writer, reviewer]).build()
events = await workflow.run("Write a tagline for a budget-friendly eBike.")
print(events.get_outputs()[0])
```

### Semantic Kernel, AutoGen and AG2

Neither Semantic Kernel nor AutoGen is the place to start a new project in 2026; both point new users to Agent Framework.

- **Semantic Kernel** is still released, but Microsoft's README now calls Agent Framework its successor. Microsoft commits to critical bug and security fixes for at least one year after Agent Framework's GA, with most new features going to Agent Framework ([Microsoft](https://devblogs.microsoft.com/semantic-kernel/semantic-kernel-and-microsoft-agent-framework/)). Keep it only for existing estates.
- **AutoGen** entered maintenance mode in October 2025: critical fixes and security patches, no significant new features ([GitHub](https://github.com/microsoft/autogen/discussions/7066)). Microsoft's migration guide maps `AssistantAgent` to `Agent`, `RoundRobinGroupChat` to `SequentialBuilder`, `GraphFlow` to `WorkflowBuilder` and `MagenticOneGroupChat` to `MagenticBuilder` ([Microsoft Learn](https://learn.microsoft.com/en-us/agent-framework/migration-guide/from-autogen/)).
- **AG2** is the community fork led by AutoGen's original creators. Its 1.0 rewrite (July 2026) replaces group chats and swarms with a "Network" hub of typed channels ([GitHub](https://github.com/ag2ai/ag2)). Watch the naming: the PyPI package called `autogen` belongs to AG2, not Microsoft.

### Google Agent Development Kit (ADK)

ADK is Google's open-source, model-agnostic framework: Gemini first, but it also runs Claude, OpenAI and LiteLLM-routed models. It is the most multi-language option, and its docs now live at [adk.dev](https://adk.dev/).

- **ADK 2.0** (Python, Go and TypeScript; not yet Java or Kotlin) adds graph workflows, dynamic nodes and collaborative sub-agent modes. The older `SequentialAgent`, `ParallelAgent` and `LoopAgent` are superseded, and 2.0 changed the event model and session schema ([ADK 2.0](https://adk.dev/2.0/)).
- **Callbacks** run before and after the agent, the model and each tool; returning an object overrides the default. Plugins are recommended for guardrails ([ADK](https://adk.dev/callbacks/)).
- **Human-in-the-loop** uses tool confirmation (`require_confirmation=True` or `request_confirmation()`). It is still marked experimental and does not support the database or Vertex session services, which is a real production caveat ([ADK](https://adk.dev/tools-custom/confirmation/)).
- **Evaluation is built in**: eval sets with tool-trajectory and response-match scores plus user simulation, run with `adk eval` or pytest ([ADK](https://adk.dev/evaluate/)).
- **Deployment**: Agent Runtime (the new name for Vertex AI Agent Engine since April 2026), Cloud Run, GKE or any container ([ADK](https://adk.dev/deploy/)).
- **Best fit**: GCP and Gemini shops wanting many languages, built-in evals and managed hosting. **Weakness**: 2.x churn, experimental HITL and A2A, and Java and Kotlin still on the 1.x model.

```python
from google.adk import Agent
from google.adk.tools import google_search

# Docs sample uses a floating alias; pin a dated model version in production.
agent = Agent(name="researcher", model="gemini-flash-latest",
              instruction="You help users research topics thoroughly.",
              tools=[google_search])
```

### OpenAI Agents SDK

The Agents SDK is OpenAI's deliberately minimal agent loop: a handful of primitives and no graph engine ([OpenAI](https://openai.github.io/openai-agents-python/)). It works with other providers, but it is designed around OpenAI's Responses API.

- **Primitives**: agents, hand-offs, agents-as-tools, input and output guardrails, function tools, sessions, tracing, human-in-the-loop and realtime voice agents.
- **Sandbox agents** (from version 0.14, April 2026) give an agent a real workspace in Docker or a hosted sandbox such as E2B, Daytona, Modal, Cloudflare or Vercel, with snapshots and mounted cloud storage ([OpenAI](https://openai.com/index/the-next-evolution-of-the-agents-sdk/)).
- **Human-in-the-loop**: mark a tool `needs_approval=True`; the run returns interruptions, you approve or reject, then resume from the saved `RunState`. The serialised state is not authenticated, so keep it server-side ([OpenAI](https://openai.github.io/openai-agents-python/human_in_the_loop/)).
- **Durability** comes from integrations with Temporal, Restate, DBOS and Dapr rather than a built-in checkpointer.
- **Platform changes to know**: Agent Builder and the hosted Evals platform shut down on 30 November 2026 (ChatKit remains), and the Assistants API was removed on 26 August 2026 ([OpenAI](https://developers.openai.com/api/docs/deprecations.md)).
- **Best fit**: OpenAI-centric teams that want little code, approval gates and sandboxed coding or file agents. **Weakness**: still 0.x, no native A2A, no hosting of its own, and tracing is unavailable to zero-data-retention organisations, which matters for regulated clients.

```python
from agents import Agent, Runner

agent = Agent(name="Assistant", instructions="You are a helpful assistant")
result = Runner.run_sync(agent, "Write a haiku about recursion in programming.")
print(result.final_output)
```

### LangChain, LangGraph and Deep Agents

This is three layers from one company. LangGraph is the low-level durable runtime; LangChain's `create_agent` is the agent API built on it; Deep Agents is an opinionated harness on top of both ([LangChain](https://docs.langchain.com/oss/python/langgraph/overview)).

- **LangChain `create_agent`** takes a model, tools, a system prompt, an output schema, a checkpointer and middleware. Built-in middleware covers human-in-the-loop, summarisation, model and tool retries, PII handling and a to-do list ([LangChain](https://docs.langchain.com/oss/python/langchain/agents)).
- **LangGraph** offers a Graph API (`StateGraph`) and a Functional API (`@entrypoint`, `@task`, where completed tasks are replayed from cache on resume).
- **Human-in-the-loop**: `interrupt()` pauses inside a node and `Command(resume=...)` continues on the same thread. The node re-runs from its start on resume, so keep side effects after the interrupt or make them idempotent ([LangChain](https://docs.langchain.com/oss/python/langgraph/interrupts)).
- **Persistence**: checkpointers for memory, SQLite, Postgres, MongoDB and Cosmos DB, with exit, async and sync durability modes. Time travel lists past checkpoints, replays from one, or forks with `update_state()` ([LangChain](https://docs.langchain.com/oss/python/langgraph/persistence)).
- **Deep Agents** adds planning, a virtual filesystem, sub-agents, summarisation, skills, sandboxes and `AGENTS.md` memory ([LangChain](https://docs.langchain.com/oss/python/deepagents/overview)).
- **Deployment**: LangSmith Deployment (renamed from LangGraph Platform in October 2025) runs an Agent Server with threads, runs, cron jobs, a task queue and A2A and MCP endpoints ([LangChain](https://docs.langchain.com/langsmith/agent-server)).
- **Best fit**: teams needing fine-grained, model-agnostic control over state, durability and approvals. **Weakness**: many layers and fast releases; the managed platform is commercial.

```python
from langgraph.graph import StateGraph, MessagesState, START, END

graph = StateGraph(MessagesState)
graph.add_node(mock_llm)
graph.add_edge(START, "mock_llm")
graph.add_edge("mock_llm", END)
graph = graph.compile()  # pass checkpointer=... for persistence and HITL
graph.invoke({"messages": [{"role": "user", "content": "hi!"}]})
```

### CrewAI

CrewAI models work as role-based agent "crews" running inside event-driven "flows". It is independent of LangChain ([CrewAI](https://docs.crewai.com/en/introduction)).

- **Crews** run tasks sequentially or hierarchically under a manager agent. **Flows** (`@start`, `@listen`, `@router`, with dict or typed Pydantic state) give production control, and the docs recommend starting with a Flow ([CrewAI](https://docs.crewai.com/en/concepts/flows)).
- **Human-in-the-loop**: `human_input=True` on a task, or `@human_feedback` in a flow, where a model maps free-text feedback onto the outcomes you list.
- **Persistence**: `@persist` on flows (SQLite by default) plus checkpoints and forking for crews, flows and agents ([CrewAI](https://docs.crewai.com/en/concepts/checkpointing)).
- **Memory** is one unified class backed by LanceDB by default. **MCP** support is tools only; **A2A** speaks protocol 0.3.
- **Telemetry**: anonymous usage telemetry is on by default. If a client's policy requires turning it off, use the CrewAI-specific opt-out in its current docs; avoid `OTEL_SDK_DISABLED`, which switches off all OpenTelemetry in the process, including your own tracing ([CrewAI](https://docs.crewai.com/en/observability/overview)).
- **Deployment**: CrewAI AMP, cloud or on-premises, exposing kickoff and status endpoints.
- **Best fit**: fast business-process automation in Python with an easy role-and-task mental model. **Weakness**: Python only, and less low-level control than LangGraph or Agent Framework.

```python
crew = Crew(agents=[researcher, writer],
            tasks=[research_task, writing_task],
            process=Process.sequential, memory=True)
crew.kickoff(inputs={})
```

### Mastra

Mastra is the leading TypeScript-native framework, covering agents, workflows, memory, RAG, evals and MCP and A2A in one package. Version 1.0 shipped on 20 January 2026 ([Mastra](https://mastra.ai/blog/changelog-2026-01-20)).

- **Workflows**: steps with Zod schemas chained with `.then`, `.parallel`, `.branch`, `.dowhile`, `.foreach` and `.sleep`, then `.commit()` ([Mastra](https://mastra.ai/docs/workflows/overview)).
- **Human-in-the-loop**: a step returns `suspend()` and is later resumed with validated `resumeData`; tools can require approval. Snapshots need persistent storage, and active runs can be restarted after a crash ([Mastra](https://mastra.ai/docs/workflows/suspend-and-resume)).
- **Memory**: message history, working memory, semantic recall and "observational memory", stored in LibSQL or Postgres ([Mastra](https://mastra.ai/docs/memory/overview)).
- **Also built in**: RAG with several vector stores, eval scorers with live sampling, tracing exporters (Langfuse, Datadog, Arize), MCP client and server, and A2A v0.3 and v1.0.
- **Deployment**: deployers for Vercel, Netlify and Cloudflare, plus guides for AWS, Azure, Kubernetes, Temporal and Inngest ([Mastra](https://mastra.ai/docs/deployment/overview)).
- **Best fit**: TypeScript and Next.js teams. **Weakness**: TypeScript only, fast minor-version churn, and some features sit under an enterprise licence.

```ts
const step1 = createStep({
  id: "step-1",
  inputSchema: z.object({ message: z.string() }),
  outputSchema: z.object({ formatted: z.string() }),
  execute: async ({ inputData }) => ({ formatted: inputData.message.toUpperCase() }),
});

export const testWorkflow = createWorkflow({ id: "test-workflow", inputSchema, outputSchema })
  .then(step1)
  .commit();
```

### Other frameworks and platforms you may have missed

Beyond the frameworks profiled above, four other groups matter on client engagements: other code-first SDKs, managed agent runtimes from the clouds, durable execution engines, and low-code builders. Versions were read from PyPI and npm on 24 October 2026.

**Other code-first SDKs**

| Option | Language | Latest | What stands out | Watch out for |
| --- | --- | --- | --- | --- |
| [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview) | Python, TypeScript | 0.2.174 (Py), 0.3.310 (TS) | Claude Code's loop, tools, hooks, sub-agents, permissions, resumable sessions and skills as a library; MCP first-class | Claude-only; runs a CLI process; pre-1.0 |
| [Pydantic AI](https://pydantic.dev/docs/ai/overview/) | Python | 2.61.0 | Strict typing; durable execution on Temporal, DBOS, Prefect or Restate; deferred tools for approvals; MCP client and server | Very fast release cadence, so pin versions |
| [AWS Strands Agents](https://strandsagents.com/latest/) | Python, TypeScript | 1.62.0 (Py), 1.22.0 (TS) | Graph, swarm and workflow multi-agent; interrupts and Cedar-based tool gating; MCP and A2A | Pulls towards AWS |
| [Vercel AI SDK](https://vercel.com/blog/ai-sdk-7) | TypeScript | 7.0.152 | `ToolLoopAgent`; durable, resumable `WorkflowAgent`; tool approvals; MCP Apps | Multi-agent not first-class |
| [LlamaIndex Workflows](https://developers.llamaindex.ai/python/llamaagents/workflows/) | Python, TypeScript | workflows 2.26.1 | Typed event-driven steps, checkpoint and resume; strong document tooling (LlamaParse) | Company focus has shifted to document processing |
| [Haystack](https://docs.haystack.deepset.ai/docs/agents) | Python | 3.4.1 | Auditable pipelines; confirmation hooks (always ask, ask once, never ask) | Non-blocking HITL needs extra plumbing |
| [Agno](https://docs.agno.com/introduction) | Python | 3.1.10 | AgentOS runtime with teams, approvals, reconnecting streams; MCP, A2A and AG-UI | Control Plane licensing unclear |
| [smolagents](https://huggingface.co/docs/smolagents/index) | Python | 1.26.0 | Minimal code-writing agents with sandbox options | No durability; no release since May 2026 |
| [DSPy](https://dspy.ai/current/) | Python | 3.4.1 | Optimises prompts and modules inside an agent | Not an orchestration runtime; pair it with one |
| [Letta](https://docs.letta.com/) | Python, TypeScript | 0.34.x | Memory-first, long-lived agents | Pivoted to Letta Code; old API server archived |

**Managed agent runtimes**

| Platform | What it gives you | Notes |
| --- | --- | --- |
| [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html) | Runtime with microVM session isolation, managed harness, memory, MCP gateway, identity, code interpreter, browser, policy, evaluations, observability | Model- and framework-agnostic; sessions last up to 8 hours with a 15-minute idle timeout by default, both adjustable ([limits](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/bedrock-agentcore-limits.html)) |
| [Google Agent Runtime](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes) | Formerly Vertex AI Agent Engine; sessions, Memory Bank, sandboxes, Agent Gateway and Agent Registry | Renamed 22 Apr 2026; runs ADK, LangGraph, AG2, LlamaIndex |
| [Microsoft Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/overview) | Prompt agents, hosted agents (your container, GA Jul 2026) with their own Entra identity, MCP toolboxes, A2A v1.0 | Publishes to Teams and M365 |
| [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview) | Hosted harness with long-running sessions, steering, sandboxes and memory | Public beta since Apr 2026; not eligible for ZDR or HIPAA BAA |
| [Gemini Managed Agents](https://blog.google/innovation-and-ai/technology/developers-tools/managed-agents-gemini-api) | One API call starts an agent in a Google-hosted sandbox | Preview since May 2026; Gemini only |
| [LangSmith Deployment](https://docs.langchain.com/langsmith/deployment) | Agent Server with threads, runs, checkpoints, cron and A2A; cloud, hybrid or self-hosted | Wraps ADK, Claude Agent SDK, Strands and CrewAI too; commercial |

**Durable execution engines** (add these when runs last hours, cross deploys or move money)

| Engine | Model | Notes |
| --- | --- | --- |
| [Temporal](https://docs.temporal.io/develop/python/integrations/openai-agents) | Workflows replay from an event history; model calls run as activities; approvals via signals | Integrations for OpenAI Agents SDK, ADK, LangGraph, Strands; determinism rules to learn |
| [Restate](https://docs.restate.dev/ai) | Durable steps, keyed sessions, pause-and-resume approvals | Server under Business Source License, which may need legal review |
| [DBOS](https://docs.dbos.dev/) | Durable workflows as a library on Postgres; no extra server | Good fit if the client already runs Postgres |
| [Inngest](https://www.inngest.com/blog/ai-agents-inngest-durable-steps.md) | Event-driven memoised steps; rerun from a chosen step | Its AgentKit library has not released for about a year |
| [Cloudflare Agents](https://developers.cloudflare.com/agents/) | Each agent is a Durable Object with its own SQLite; scheduling, HITL, MCP client | Edge-native but Cloudflare-only; pre-1.0 |
| [AWS Step Functions](https://aws.amazon.com/about-aws/whats-new/2026/06/aws-step-functions-agentcore/) | Agentic reasoning step backed by AgentCore, with built-in human approval | Four regions at launch |
| [Azure Durable Functions](https://learn.microsoft.com/en-us/agent-framework/hosting/azure-functions) | Durable hosting for Agent Framework; approvals that wait days with no compute used | Packages still prerelease |

**Low-code and visual builders**

| Builder | Notes |
| --- | --- |
| [n8n](https://docs.n8n.io/release-notes/) | AI Agent node, MCP server and client, approvals over Slack and Telegram; "fair-code" licence restricts reselling or embedding |
| [Dify](https://docs.dify.ai/policies/open-source) | Human-input forms, sandboxed agents, workflows exposed as MCP; modified Apache licence restricts multi-tenant SaaS |
| [Langflow](https://docs.langflow.org/release-notes) | Agent component, MCP, desktop app; MIT |
| [Microsoft Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/whats-new) | A2A connections, computer use, Entra Agent IDs for every agent; best where work happens in M365 |
| [Zapier Agents](https://zapier.com/agents) | Agents across thousands of SaaS apps; still described as beta |
| [Flowise](https://github.com/FlowiseAI/Flowise) | End of life on 31 Aug 2026 and archived; do not recommend it |

**Protocols beyond MCP and A2A**

- **[AG-UI](https://github.com/ag-ui-protocol/ag-ui)**: an event protocol between an agent backend and a user interface (streaming text, tool calls, state and approval prompts). Version 1.0 shipped in September 2026, with first-party support in Agent Framework, ADK, Strands, Mastra, Pydantic AI and AgentCore.
- **[Agent Client Protocol](https://agentclientprotocol.com/)**: a "language server protocol for coding agents" between editors and agents, governed by Zed and JetBrains. Gemini CLI, Copilot, Cursor and goose implement it, and Claude and Codex via adapters.
- **[AP2](https://ap2-protocol.org/)** and the **[Agentic Commerce Protocol](https://docs.stripe.com/agentic-commerce/protocols/acp)**: standards for agents that pay or buy on a user's behalf.
- **[Agentic AI Foundation](https://aaif.io/)**: the Linux Foundation home formed in December 2025 for MCP, goose and AGENTS.md, now listing ten projects including A2A, Agent Skills and agentgateway ([Linux Foundation](https://linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation)).
- **A naming trap**: "ACP" can mean the Agent Client Protocol (editors), the Agentic Commerce Protocol (payments) or IBM's Agent Communication Protocol, which merged into A2A in 2025. Always spell out which one is meant.

### Choosing a framework on an engagement

The client's cloud, language and model contract usually decide the framework before any feature comparison does. Start from their constraints, then check the Part 1 features you actually need.

| If the client... | Start with | Why |
| --- | --- | --- |
| Runs on Azure or .NET and wants long-term support | Microsoft Agent Framework | GA with LTS; Foundry hosting; Entra identity |
| Is on GCP or standardised on Gemini | Google ADK 2.x on Agent Runtime | Many languages, built-in evals, managed hosting |
| Is AWS-first | Strands Agents or LangGraph on Bedrock AgentCore | AgentCore runs most frameworks with isolation, identity and policy |
| Is OpenAI-centric and wants minimal code | OpenAI Agents SDK, plus Temporal for durability | Fewest abstractions; sandbox agents; approvals |
| Builds coding, file or ops agents on Claude | Claude Agent SDK (or Claude Managed Agents if hosted is acceptable) | Claude Code's proven harness as a library |
| Needs fine-grained control and multi-model portability | LangGraph | Deepest checkpointing, time travel and HITL tooling |
| Wants Python with strict typing | Pydantic AI | Typed outputs; choice of durable backend |
| Wants a quick business-process automation in Python | CrewAI Flows | Easy role-and-task model; fast to demo |
| Is a TypeScript or Next.js shop | Mastra or Vercel AI SDK 7 | Native TypeScript; durable workflows and approvals |
| Has Semantic Kernel or AutoGen code | Migrate to Agent Framework | Official successor with migration guides |
| Needs runs that last days or move money | Any of the above plus Temporal, Restate or DBOS | Automatic re-drive from recorded step results; needs deterministic workflow code and versioning |

Two practical rules. Keep business logic in plain functions and tools, not in framework classes, so a framework swap costs days rather than months. And put a thin interface of your own around the model provider, because pricing, models and terms change faster than your client's procurement cycle.
