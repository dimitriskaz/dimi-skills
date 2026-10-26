# FDE delivery playbook

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Deliver one narrow, evaluated workflow first, then widen. Most agent engagements stall on data access, missing evaluations and lack of trust, not on the choice of framework.

**A default reference stack**

| Layer | Default choice | When to deviate |
| --- | --- | --- |
| Orchestration | The framework that matches the client's cloud (see the decision table); a fixed graph of stages with agentic nodes inside | Fully dynamic only for research or debugging tasks |
| Durability | Framework checkpointer on Postgres, with a supervisor that re-drives crashed runs | Temporal, Restate or DBOS for multi-hour or financial runs |
| Model access | A gateway with keys, budgets, rate limits, a fallback model and pinned, dated model versions | Direct SDK calls only for prototypes |
| Tools | Typed function tools over client systems; vetted MCP servers behind a gateway; a sandbox for code | Provider-hosted tools if data handling terms allow |
| RAG | Strong parser, hybrid search, a reranker; start in the client's existing Postgres or search platform | A dedicated vector database at large scale or for multi-tenancy |
| Observability | OpenTelemetry GenAI traces into the client's APM, plus an LLM-observability tool | Self-hosted options for strict data residency |
| Evaluation | A golden set of real-shaped cases (3 to 5 on day one, 10 to 20 for the first CI gate, 50 to 200 by pilot; see the eval data rule in Part 4), run with repeated trials on every change, plus sampled online judging | Larger sets as usage grows |
| Guardrails | Input and output checks, plus privilege separation for any agent that reads untrusted content | Lighter controls only for internal, read-only agents |
| Security | Delegated user permissions when a user is present, a dedicated least-privilege agent identity otherwise; approval gates; an audit log | Never relax these |

**Delivery plan**

1. **Discovery**: pick one workflow with measurable value. Map the current process, systems, data owners and risk tier, and collect examples with expected outcomes: they seed the evaluation set (3 to 5 on day one of the scaffold, 10 to 20 for the first CI gate, 50 to 200 by pilot). Eval data is real-shaped by default: the structure, edge cases and expected outcomes of real work, with synthetic content. Real client cases are used only anonymised, with the client's consent, and stored under the client's data policy, never in this plugin's repository.
2. **Thin slice**: an ahead-of-time workflow with three to five read-only tools and a human review step at the end. Tracing on from the first commit.
3. **Evaluate and iterate**: run the eval set on every change and fix failures by category: retrieval, tool choice, reasoning or format.
4. **Harden**: approvals for writes, idempotency keys, budgets, failure handling, PII redaction, load tests, and a prompt-injection red-team exercise.
5. **Pilot**: a small user group, with the agent in shadow mode or with approval on every action. Measure against the old process.
6. **Scale and hand over**: dashboards, runbooks, on-call, cost reports, and training so the client's team owns prompts, tools and evals.

**Production readiness checklist**

- [ ] Every run produces a trace with per-step latency, tokens and cost
- [ ] The eval set runs on every model, prompt, tool and index change, with repeated trials and an agreed tolerance
- [ ] Step, token, time and cost budgets are enforced by the harness
- [ ] Write tools use stable idempotency keys; writes are human-accepted proposals by default, with the approval bound to the exact call. A reversible write runs without approval only when the client profile explicitly allows it, with a sample reviewed afterwards; irreversible actions always need approval
- [ ] Tools act with the user's delegated permissions, or a dedicated least-privilege agent identity for autonomous runs
- [ ] Untrusted content cannot trigger data leaving the system without approval
- [ ] A red-team suite runs in CI and a manual red-team exercise has been completed
- [ ] State is checkpointed durably, a supervisor re-drives crashed runs, and crash recovery has been tested
- [ ] Model versions are pinned, and fallback is configured and tested
- [ ] Revoking a user's access removes their retrieval results within the agreed time
- [ ] Logs redact PII, retention is set, and approvals are audited
- [ ] A data map exists and zero-data-retention eligibility is confirmed for every hosted feature in use
- [ ] Users are told they are dealing with an AI system, and generated content is labelled where EU AI Act Article 50 applies (confirm with counsel)
- [ ] Runbooks cover provider outages, runaway cost and bad outputs
- [ ] The client team can change prompts, tools and evals without you

**Failure patterns to avoid**

- Starting with multiple agents when one agent with good tools would do.
- No evaluation set, so every prompt change is a guess.
- Demoing on clean data, then failing on real scanned documents.
- Tools running as a service account that bypasses user permissions.
- Ignoring cost until the first invoice arrives.
