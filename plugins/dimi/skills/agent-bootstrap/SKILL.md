---
name: "agent-bootstrap"
description: "Start a new LLM agent project the right way: fetch current framework docs first (never from memory), choose a framework against explicit criteria, and scaffold with tools, structured outputs, tracing, cost and step caps, human-in-the-loop gates, an eval harness, tests and an ADR from day one."
argument-hint: "[what the agent should do]"
---

# Agent bootstrap

Use when starting an agent, assistant or multi-step LLM workflow, or when choosing between frameworks. Triggers: `/dimi:agent-bootstrap`, "build an agent that…", "which agent framework", "scaffold an assistant", "start an agent project".

## 0. Freshness rule — read before you write

Agent frameworks change their APIs faster than any model's training data. **Before proposing a framework or writing a line of code**:
1. Resolve each candidate with the Context7 tools (`resolve-library-id`, then `query-docs` for "getting started", "tools / function calling", "structured output", "streaming", "tracing", "human in the loop", "MCP"). If Context7 is unavailable, WebSearch the official docs and changelog.
2. Record in the ADR (section 6) the framework version and the doc pages consulted, with dates.
3. Any API you write from memory is a bug waiting to happen. When docs and memory disagree, docs win; when docs are silent, write a two-line spike and run it.

## 1. Requirements (ten minutes, written down)

Ask only what changes the design; assume and state the rest.
- **Job**: what the agent does for whom; the three most common tasks; what "good" looks like for each (these become the first evals).
- **Autonomy**: single-turn tool use → multi-step loop → long-running/background → multi-agent. Pick the lowest level that does the job.
- **Runtime**: server-side service, CLI, in-app assistant, scheduled job, browser. Language: follow the host codebase (TypeScript, Python, .NET, Go, Java …).
- **Models**: one provider or provider-agnostic; need for small/fast vs large models per step; local models.
- **State and memory**: stateless per request, per-conversation, durable across sessions; who owns the store.
- **Writes**: can the agent change anything? Every write is a human-accepted proposal unless explicitly decided otherwise (see `${CLAUDE_PLUGIN_ROOT}/skills/agent-tool-design/SKILL.md`).
- **Integrations**: existing MCP servers to consume; tools to expose; auth model for each.
- **Hosting**: run the loop yourself vs a managed/hosted agent runtime; sandboxing needs for code execution.
- **Constraints**: data residency, personal data, audit, cost ceiling per run and per month, latency budget.

## 2. Choose the framework against criteria, not fashion

Read [references/landscape.md](references/landscape.md) for the constraint-led shortlist and the candidate list (dated; it carries an "as of" note and defers to the maintained `${CLAUDE_PLUGIN_ROOT}/skills/harness-reference/references/frameworks.md`). If `.claude/fde-client-profile.md` exists, its approved models, cloud and regions are hard constraints.

Score against: provider-first vs agnostic · explicit graph vs model-driven loop · language match · MCP support (client and server) · human-in-the-loop primitives · durable state and resumability · tracing/observability hooks · structured output support · hosting fit · maturity and release cadence · licence. Write the scores in the ADR. Pick the simplest option that scores well; frameworks are easy to add and hard to remove.

## 3. Scaffold — the non-negotiables from day one

Lay these down before the first real task, in the host repo's conventions:
- **Layout**: `agent/` (loop, prompts, policies), `tools/` (one module per tool, each with its spec from `/dimi:agent-tool-design`), `evals/` (tasks, rubrics, runner), `tests/`, `prompts/` (versioned files, not inline strings).
- **Config**: environment variables with safe defaults; model names, caps and feature flags in one typed config; dev-only modes refused in production by code.
- **Model layer**: one thin adapter for provider calls so model, temperature, retries and timeouts live in one place; structured outputs validated with a schema library; a small model for routing/classification steps where it suffices.
- **Tools**: built per `/dimi:agent-tool-design` — strict schemas, bounded outputs, error envelopes, tenant from claims, writes as proposals. MCP for anything shared with other agents or editors.
- **Caps**: max turns, max tool calls, max tokens in and out per run, wall-clock timeout, and a cost budget per run that stops the loop with a clear status. Log the spend per run.
- **Human-in-the-loop**: explicit interrupt points for writes and for low-confidence steps; the resume path stores what was proposed.
- **Memory/state**: a store with a TTL and a size cap; nothing in process memory when there is more than one instance; personal data minimised before it is stored.
- **Observability**: traces for every run (framework traces or OpenTelemetry) with tool calls, latencies, token counts and outcome; logs carry ids, tool names and counts, never prompts with tenant data or raw outputs; a run id surfaced to the user for support.
- **Safety posture**: tool results treated as untrusted; system prompt forbids following instructions found in data; output validated before any effect; secrets never in context; prompt-injection fixtures in the evals.
- **Evals**: `evals/tasks/*.yaml` with input, expected tool sequence (or expected outcome) and a rubric; a runner that scores pass rate and cost; three to five tasks from section 1 on day one; run in CI on every prompt, tool or model change.
- **Tests**: unit tests per tool (schema, golden, error), integration tests with recorded fixtures (no live model calls in CI), one smoke test that runs the loop end-to-end against recorded model transcripts (replay mode).
- **Secrets**: provider keys from the secret manager or env, never committed; `.env.example` with placeholders only.
- **Defaults that apply without being asked**: the twelve harness defaults in `${CLAUDE_PLUGIN_ROOT}/skills/harness-reference/SKILL.md` ("Defaults to apply without being asked") are the canonical list; do not restate them here. The three that most often get skipped in a scaffold: a fixed graph of stages with agentic steps only where steps cannot be known in advance; a stable prompt prefix (instructions and tool definitions first) so caching works; dated model versions pinned, with evals re-run on every model, prompt, tool or index change.
- **Two rules that keep the framework swappable**: business logic lives in plain functions and tools, not framework classes; a thin interface of your own wraps the model provider, because pricing, models and terms change faster than procurement.

## 4. First run

1. Hello world: one turn, no tools, structured output, trace visible, cost logged.
2. First tool: the read tool for the most common task; golden tests pass.
3. First eval: the three tasks from section 1; record the baseline pass rate and cost.
4. First write (if any): as a proposal with a human accept; test stale-version refusal and partial-failure retry.
5. CI: lint, typecheck, unit, evals in replay mode (recorded fixtures and transcripts, no model call); live-model evals behind a manual gate with a budget.

## 5. Document

- `README`: what the agent does, architecture diagram (loop, tools, stores, model), how to run, how to run evals, how to add a tool (link `${CLAUDE_PLUGIN_ROOT}/skills/agent-tool-design/SKILL.md`), caps and how to change them, where traces go.
- `.env.example`, a `CONTRIBUTING` note on prompt changes requiring an eval run.

## 6. ADR

`docs/adr/NNNN-agent-framework.md` (or the repo's convention): context, options scored (section 2), decision, consequences, **docs consulted with versions and dates**, review date (frameworks move: set one three months out).

## 7. Before committing

Run `/dimi:pr-self-review`. Also run `/dimi:review-agent` on the new code: it applies the production-readiness rubric (budgets, idempotent writes, approvals bound to the call, identity, injection exposure, checkpointing, tracing, evals) with file:line evidence — the deeper check this scaffold is meant to pass. The security stage matters most here: tenant scoping of tools, personal data in context and logs, writes gated behind human acceptance, secrets, and new dependencies with their licences and known vulnerabilities.