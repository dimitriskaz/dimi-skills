# Observability layer

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or run `/dimi:refresh-harness`.

Contents:

- Monitoring
- Tracing
- Logging
- Calculation: tokens, cost and latency
- Evaluation

## Monitoring

Monitoring watches aggregate health over time and alerts when something drifts: latency, cost, error rates, quality signals. For agents you need the usual service metrics plus a layer of AI-specific ones, because an agent can be up, fast and confidently wrong.

**What to watch and where it comes from**

OpenTelemetry's GenAI conventions define standard signals for most of these ([OTel GenAI](https://github.com/open-telemetry/semantic-conventions-genai)).

| What to watch | Why | OpenTelemetry GenAI signal |
| --- | --- | --- |
| Time to first token | Perceived speed for chat users | `gen_ai.client.inference.time_to_first_chunk` |
| End-to-end task latency | User experience and SLAs | `gen_ai.invoke_agent.duration`, `gen_ai.invoke_workflow.duration` |
| Per-step latency | Find the slow model call or tool | `gen_ai.client.inference.duration`, `gen_ai.execute_tool.duration` |
| Steps per task | Loops and inefficient plans | `gen_ai.invoke_agent.inference_calls`, `gen_ai.invoke_agent.tool_calls` |
| Tool error rate | Broken integrations, bad arguments | `error.type` on `execute_tool` spans |
| Tokens and cost per task | Budget and unit economics | Token counters, summed under the root agent span |
| Cache hit rate | Whether prompt caching is working | Cache-read tokens divided by all input tokens (uncached, cache reads and cache writes) |
| Guardrail and approval rates | Safety pressure; approval fatigue | Guardrail spans; your approval events |
| Quality scores | Silent regressions | Online eval results and user feedback |

**A warning about naming churn**

The GenAI conventions are still marked "Development", moved to their own repository in mid-2026, and renamed core metrics in September and October 2026: `gen_ai.client.token.usage` was replaced by per-type usage counters, and inference duration became `gen_ai.client.inference.duration`. Shipping frameworks such as Agent Framework still emit the older names ([Microsoft Learn](https://learn.microsoft.com/en-us/agent-framework/user-guide/observability)). Build dashboards that read both old and new names, and pin your instrumentation versions.

**Alerts worth setting from day one**

- Cost per hour or per task above a threshold, the cheapest insurance against a runaway loop.
- p95 task latency above the SLA.
- Tool error rate or provider error rate above baseline.
- Steps per task far above the median, which usually means a loop.
- Online quality score or thumbs-down rate dropping after a deploy.
- Ingestion freshness: a RAG source that has not synced on schedule.

There is no standard metric yet for loop detection or cost per task; derive them from traces, for example by flagging repeated identical tool calls within one run and summing inference cost under each root span.

## Tracing

A trace records one agent run as a tree of timed spans: the root agent invocation, each model call, each tool call, each retrieval, with inputs, outputs, tokens and errors attached. It is the single most useful debugging tool for agents, because it shows exactly what the model saw and decided at every step.

**Standard span types**

The OpenTelemetry GenAI conventions define the span vocabulary most tools now map to ([OTel GenAI agent spans](https://raw.githubusercontent.com/open-telemetry/semantic-conventions-genai/main/docs/gen-ai/gen-ai-agent-spans.md)):

| Span | Name pattern | Records |
| --- | --- | --- |
| Invoke agent | `invoke_agent {agent name}` | One agent run; the root of most traces |
| Invoke workflow | `invoke_workflow {workflow name}` | A multi-step workflow run |
| Inference | `chat {model}` (or other operation names) | One model call: model, tokens, cache usage, finish reason |
| Execute tool | `execute_tool {tool name}` | One tool call: arguments, result, error |
| Retrieval and memory | `retrieval`, `search_memory` and similar | RAG and memory lookups |
| Plan | `plan {agent}` | A planning step |

Key attributes include `gen_ai.operation.name`, `gen_ai.request.model`, `gen_ai.agent.name`, `gen_ai.tool.name`, `gen_ai.conversation.id`, and token counts including cache reads, cache writes and reasoning tokens.

**Framework support**

| Framework | Tracing |
| --- | --- |
| Microsoft Agent Framework | Native OpenTelemetry, on by default in Python; sensitive data off by default |
| Google ADK | Native OpenTelemetry following the GenAI conventions ([ADK](https://adk.dev/observability/)) |
| OpenAI Agents SDK | Its own tracing, sent to OpenAI by default, with 30+ third-party processors; sensitive data **on** by default ([OpenAI](https://openai.github.io/openai-agents-python/tracing/)) |
| LangChain and LangGraph | LangSmith, with an OpenTelemetry mode ([LangChain](https://docs.langchain.com/langsmith/trace-with-opentelemetry)) |
| Mastra, Pydantic AI | OpenTelemetry exporters following the GenAI conventions |
| CrewAI | Third-party integrations (Langfuse, Phoenix, MLflow, Opik, Weave and others) |

For anything without native support, the open-source [OpenInference](https://github.com/Arize-ai/openinference) and [OpenLLMetry](https://github.com/traceloop/openllmetry) instrumentation libraries cover most providers, vector stores and frameworks.

**Observability platforms (ownership as of October 2026)**

| Platform | Owner | Licence | Notes |
| --- | --- | --- | --- |
| [Langfuse](https://langfuse.com/docs/opentelemetry/get-started) | ClickHouse (acquired Jan 2026) | MIT core | OTLP ingest; cloud and self-hosted both continue ([ClickHouse](https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability)) |
| [LangSmith](https://docs.langchain.com/langsmith/observability.md) | LangChain | Commercial | Cloud, hybrid or self-hosted; evals and annotation queues |
| [Arize Phoenix](https://github.com/Arize-ai/phoenix) and Arize AX | Arize | Phoenix: Elastic License 2.0 | Built on OpenInference; evals and datasets |
| [Braintrust](https://www.braintrust.dev/docs) | Braintrust | Commercial core | Strong eval workflow; online scoring |
| [MLflow 3](https://mlflow.org/docs/latest/genai/) | Databricks | Apache-2.0 | OpenTelemetry-compatible tracing and LLM judges |
| [Comet Opik](https://github.com/comet-ml/opik) | Comet | Apache-2.0 | Fully self-hostable; PyTest integration |
| [W&B Weave](https://github.com/wandb/weave) | CoreWeave | Apache-2.0 | OTLP ingest; agent views |
| [Pydantic Logfire](https://logfire.pydantic.dev/docs/) | Pydantic | SDK MIT, platform closed | OpenTelemetry-native; SQL queries |
| [Datadog LLM Observability](https://docs.datadoghq.com/llm_observability/) | Datadog | Commercial | Fits clients already on Datadog; sensitive-data scanning |
| [Dynatrace](https://docs.dynatrace.com/docs/observe/dynatrace-for-ai-observability), [New Relic](https://docs.newrelic.com/docs/ai-monitoring/intro-to-ai-monitoring/) | Vendors | Commercial | AI monitoring inside existing APM |

Consolidation is fast: Traceloop went to ServiceNow, Galileo to Cisco, Helicone to Mintlify (now in maintenance mode), and OpenAI announced it is acquiring promptfoo ([Traceloop](https://traceloop.com/blog/traceloop-is-joining-servicenow), [Cisco](https://blogs.cisco.com/news/cisco-announces-the-intent-to-acquire-galileo), [Helicone](https://helicone.ai/blog/joining-mintlify)). That is the strongest argument for instrumenting with OpenTelemetry: you can change backend without re-instrumenting.

**FDE default**: emit OpenTelemetry GenAI spans, send them to the client's existing APM for operations, and to one LLM-focused tool for debugging and evals.

## Logging

Logs are the durable, searchable record of what the system did: events, errors, decisions and actions. Traces explain a single run; logs give you the audit trail across all runs, which regulated clients and incident reviews depend on.

**What to log**

| Log type | Contents | Who uses it |
| --- | --- | --- |
| Application events | Run started and finished, stage transitions, retries, fallbacks, budget stops | Engineers on call |
| Tool action audit | Every write action: tool, arguments, target system, result, idempotency key, user identity | Security, compliance, incident review |
| Approval audit | What was proposed, who approved, rejected or edited it, and when | Compliance, process owners |
| Model interaction records | Prompt and response references, model and version, token counts | Debugging, evaluation, disputes |
| Security events | Guardrail blocks, injection detections, permission denials | Security team |

Use structured JSON logs with the trace ID and conversation ID on every line, so logs, traces and evals join up.

**Handle prompts and outputs as sensitive data**

- The OpenTelemetry conventions say instrumentations should not capture prompts and outputs by default; in production, store content in a separate access-controlled store and keep only references on spans ([OTel GenAI](https://raw.githubusercontent.com/open-telemetry/semantic-conventions-genai/main/docs/gen-ai/README.md)).
- Defaults differ: Agent Framework leaves sensitive data off by default ([Microsoft Learn](https://learn.microsoft.com/en-us/agent-framework/user-guide/observability)), while the OpenAI Agents SDK includes sensitive data in traces by default, so turn `trace_include_sensitive_data` off explicitly ([OpenAI](https://openai.github.io/openai-agents-python/tracing/)).
- Redact PII before logs leave the process, set retention periods with the client's data-protection officer, and restrict who can read raw content.

**EU AI Act record-keeping**

- **Article 12**: high-risk AI systems must technically allow automatic recording of events over their lifetime, to support risk detection, post-market monitoring and deployer oversight ([Article 12](https://artificialintelligenceact.eu/article/12/)).
- **Articles 19 and 26**: providers and deployers must keep those logs for at least six months, unless other law requires otherwise ([Article 19](https://artificialintelligenceact.eu/article/19/), [Article 26](https://artificialintelligenceact.eu/article/26/)).
- **Timing**: the Digital Omnibus on AI, in force since 27 July 2026, moved the high-risk obligations for Annex III systems to 2 December 2027 and for product-embedded Annex I systems to 2 August 2028; Article 50 transparency duties still applied from 2 August 2026 ([Cuatrecasas](https://www.cuatrecasas.com/en/spain/intellectual-property/art/digital-omnibus-ai-has-been-published), [Gibson Dunn](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/)).

Even for clients outside the high-risk categories, build the tool-action and approval audit logs anyway: they are what lets you answer "why did the agent do that?" after an incident. This is not legal advice; confirm obligations with the client's counsel.

## Calculation: tokens, cost and latency

Calculation turns raw telemetry into the numbers a client's sponsor cares about: cost per task, cost per successful outcome, latency percentiles and savings against the old process. Get the token accounting right first, because providers report tokens differently.

**The cost formula**

$$
\text{cost} = T_{\text{uncached}} \times p_{\text{in}} + T_{\text{cache read}} \times p_{\text{in}} \times r_{\text{read}} + T_{\text{cache write}} \times p_{\text{in}} \times r_{\text{write}} + T_{\text{out}} \times p_{\text{out}}
$$

Here p is the price per token and r the cache multiplier. Reasoning or thinking tokens are billed as output at Anthropic, OpenAI and Google, so they belong in the output count, counted once (see the field rules below).

**Check the field semantics before summing**

- **Anthropic**: `input_tokens` covers only uncached tokens; total input is that plus `cache_read_input_tokens` plus `cache_creation_input_tokens` ([Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)).
- **OpenAI**: cached tokens appear in `input_tokens_details` and reasoning tokens in `output_tokens_details`. These are breakdowns of `input_tokens` and `output_tokens`, so do not add them again ([OpenAI](https://developers.openai.com/api/docs/guides/prompt-caching)).
- **Google Gemini**: thinking tokens are reported in their own field, separate from the response tokens, so add them to output when costing a call.
- **OpenTelemetry**: `gen_ai.usage.input_tokens` should include cache reads and writes, with the cache counts reported as subsets.

Mixing these conventions double-counts or under-counts cached tokens, which on a cache-heavy agent can put the cost estimate off by several times.

**Prompt caching multipliers**

| Provider | Cache reads | Cache writes | Minimum cacheable prompt |
| --- | --- | --- | --- |
| [Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) | 0.1x base input as standard, lower on the newest models | 1.25x for a 5-minute TTL, 2x for 1 hour | 512 tokens on 5.x models |
| [OpenAI](https://developers.openai.com/api/docs/guides/prompt-caching) | On by default; 0.1x on GPT-5.6 and later | 1.25x (30 minutes) or 2.5x (12 hours) on GPT-5.6 and later; no write charge on earlier models | 1,024 tokens |
| [Google Gemini](https://ai.google.dev/gemini-api/docs/caching) | Implicit caching on by default from Gemini 2.5; for example 10% of base on 3.8 Flash | Explicit caches also pay hourly storage | 2,048 to 4,096 tokens depending on model |

**Worked example (illustrative prices)**

Assume $3 per million input tokens, $15 per million output tokens, cache reads at 0.1x and writes at 1.25x. An agent task makes 10 model calls, each with 20,000 input tokens (18,000 of them a stable, cached prefix) and 500 output tokens.

| Scenario | First call | Each later call | Total for 10 calls |
| --- | --- | --- | --- |
| No caching | $0.0675 | $0.0675 | $0.675 |
| With caching | $0.0810 (pays the cache write) | $0.0189 | $0.251 |

Caching cuts this task's cost by about 63%, which is why a stable prompt prefix (system prompt and tools first, changing content last) is one of the highest-value optimisations in the whole harness.

**Metrics to calculate and report**

- **Cost per task** and **cost per successful task** (total cost divided by the number of successful tasks): the second exposes cheap agents that fail often.
- **Latency**: p50, p95 and p99 for time to first token and end-to-end, never averages alone.
- **Throughput**: output tokens per second, which sets streaming feel and batch job duration.
- **Cache hit rate**: cache-read tokens divided by all input tokens (uncached plus cache reads plus cache writes); a drop usually means someone changed the prompt prefix.
- **Efficiency**: steps and tokens per completed task, tracked across releases.
- **Business value**: minutes of human work saved, or cases resolved without escalation, against the cost per task. This is the number that renews the engagement.

## Evaluation

Evaluation measures whether the agent does the job well, and keeps measuring as prompts, models, tools and data change. It is what separates an engineering process from prompt guessing, and for an FDE it is also the evidence that wins the client's trust.

**Offline and online**

| Mode | Runs on | Purpose |
| --- | --- | --- |
| Offline | A fixed dataset with expected outcomes | Regression testing in CI, comparing models and prompts, backtesting |
| Online | Sampled production runs, without reference answers | Catching drift, new failure types and quality drops after deploys |
| Human review | Annotation queues of sampled or flagged runs | Ground truth, calibrating automated judges, new test cases |

The loop that works: production failures and reviewer corrections become new offline test cases, so the eval set grows from real usage ([LangSmith](https://docs.langchain.com/langsmith/evaluation-concepts)).

**Evaluator types**

- **Code checks**: exact match, schema validity, regex, whether the right record was updated. Cheap and reliable; use them wherever you can.
- **LLM as judge**: a model grades against a rubric. Known biases are position, verbosity and self-preference; strong judges agreed with humans over 80% of the time in the original study ([Zheng et al.](https://arxiv.org/abs/2306.05685)). Use a different model family from the agent, give a specific rubric, and calibrate against human labels.
- **Pairwise comparison**: a judge picks the better of two outputs; more reliable than absolute scores for comparing versions.
- **Human evaluation**: the reference standard, used to label and to audit the automated judges.

**What to measure for agents**

| Level | Metrics |
| --- | --- |
| Final outcome | Task completion, correctness against expected result, policy compliance |
| Trajectory | Right tools chosen, correct arguments, steps taken versus the ideal, plan adherence |
| Reliability | pass^k: does it succeed on every one of k repeated attempts, not just once |
| RAG | Faithfulness (claims supported by retrieved context), context precision and recall, answer relevancy ([Ragas](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/)); recall@k, MRR and nDCG for retrieval alone |
| Safety | Prompt-injection resistance, data-leak attempts, refusal of out-of-scope actions |
| Efficiency | Tokens, cost and latency per task |

**Evaluation tools**

| Tool | Notes |
| --- | --- |
| [DeepEval](https://deepeval.com/docs/getting-started) | Open source; task completion, tool correctness, step efficiency and plan adherence metrics; runs in CI |
| [Ragas](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/) | Open source; RAG metrics plus tool-call accuracy and agent goal accuracy |
| [promptfoo](https://www.promptfoo.dev/docs/intro/) | Declarative test suites and red teaming; GitHub Action for CI. OpenAI announced in March 2026 that it is acquiring promptfoo |
| [Inspect AI](https://inspect.aisi.org.uk/) | From the UK AI Security Institute; datasets, solvers and scorers with sandboxed agent evals |
| [Google ADK eval](https://adk.dev/evaluate/) | Tool-trajectory and response-match scores, user simulation, `adk eval` |
| LangSmith, Braintrust, Phoenix, Opik, MLflow | Platform evals tied to traces, with datasets, experiments and online scoring |

OpenAI's hosted Evals platform goes read-only on 31 October 2026 and shuts down on 30 November 2026, so do not build new client work on it ([OpenAI](https://developers.openai.com/api/docs/guides/evals)).

**Public agent benchmarks (for model selection, not acceptance testing)**

| Benchmark | Measures | Note |
| --- | --- | --- |
| [SWE-bench Pro](https://labs.scale.com/leaderboard/swe_bench_pro) | Long-horizon software engineering | OpenAI stopped reporting SWE-bench Verified in Feb 2026 over flawed tests and recommends Pro ([OpenAI](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)) |
| [τ-bench family](https://taubench.com/) | Tool-using agents serving simulated users under policy | Retail, airline, telecom and banking domains; reports pass^k |
| [Terminal-Bench](https://www.tbench.ai/) | Agents doing real terminal work | Version 4.0 (Aug 2026) is current |
| [OSWorld](http://osworld-v1.xlang.ai/) | Computer-use agents on real desktops | OSWorld 2.0 released Jun 2026; the link is to the original benchmark |
| [GAIA](https://arxiv.org/abs/2311.12983) | General assistant tasks needing tools and browsing | Humans 92% at launch |
| [BrowseComp](https://openai.com/index/browsecomp/) | Finding hard-to-locate information on the web | 1,266 problems |
| [MCP-Atlas](https://arxiv.org/abs/2602.00933v1) | Tool use against 36 real MCP servers | 1,000 tasks |

Public benchmarks tell you which models are capable; only your own eval set tells you whether the agent works for this client.

**Making evals part of delivery**

1. Build the first 50 to 200 cases from real client data during discovery, with the client's experts writing the expected outcomes.
2. Run each case several times, because agents are non-deterministic. Report the pass rate and pass^k with confidence intervals, and gate merges on a tolerance agreed with the client rather than on any single-run drop.
3. Re-run the full suite on every change to the model, prompts, tools or index, not only on code pull requests. Provider-side model updates never arrive as a pull request, so pin dated model versions in production.
4. Sample 1% to 10% of production runs for online judging, more for new releases.
5. Review a fixed number of runs by hand each week and feed failures back into the suite.
6. Report eval results to the client alongside cost and latency, so quality is visible, not assumed.
