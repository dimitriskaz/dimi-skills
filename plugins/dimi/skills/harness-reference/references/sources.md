# Sources and refresh checklist

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Contents:

- Where to check first when refreshing
- Part 1: Orchestration and frameworks
- Part 2: Tools
- Part 3: RAG
- Part 4: Observability
- Part 5: Cross-cutting concerns

Every page cited in this guide is listed below, grouped by part, with a short list of the pages to check first when refreshing it. All were consulted on 24 October 2026. Part 5 reuses the Part 1 and Part 2 pages for platform identity and MCP, plus the sources listed under Part 5.

## Where to check first when refreshing

| What changes | Check first |
| --- | --- |
| Framework versions and releases | Each project's PyPI or npm page, and its release notes or changelog |
| Microsoft Agent Framework, Semantic Kernel, AutoGen | [Agent Framework 1.0 announcement](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/), [Agent Framework docs](https://learn.microsoft.com/en-us/agent-framework/overview/agent-framework-overview) |
| Google ADK and Agent Runtime | [adk.dev](https://adk.dev/), [Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes) |
| OpenAI Agents SDK and platform changes | [Agents SDK docs](https://openai.github.io/openai-agents-python/), [OpenAI API deprecations](https://developers.openai.com/api/docs/deprecations.md) |
| Claude agent tooling | [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview), [Claude tool reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-reference) |
| LangChain, LangGraph, CrewAI, Mastra | [LangGraph docs](https://docs.langchain.com/oss/python/langgraph/overview), [CrewAI docs](https://docs.crewai.com/en/introduction), [Mastra docs](https://mastra.ai/docs) |
| MCP specification | [MCP versioning](https://modelcontextprotocol.io/specification/versioning), [MCP blog](https://blog.modelcontextprotocol.io/) |
| A2A and other agent protocols | [A2A specification](https://a2a-protocol.org/latest/specification/), [Agentic AI Foundation projects](https://aaif.io/) |
| Observability conventions | [OpenTelemetry GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai) |
| Embedding and reranking models | [Cohere changelog](https://docs.cohere.com/changelog), [Voyage embeddings](https://docs.voyageai.com/docs/embeddings), [MTEB leaderboard](https://huggingface.co/spaces/mteb/leaderboard) |
| Agent benchmarks | [SWE-bench Pro](https://labs.scale.com/leaderboard/swe_bench_pro), [Terminal-Bench](https://www.tbench.ai/), [τ-bench](https://taubench.com/) |
| Prompt caching and pricing | [Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [OpenAI](https://developers.openai.com/api/docs/guides/prompt-caching), [Gemini](https://ai.google.dev/gemini-api/docs/caching) |
| Security guidance | [OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/), [MCP security best practices](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices) (confirm URL shape at next refresh: the `/docs/<revision>/tutorials/...` path differs from the `/specification/<revision>/...` pattern of the other spec pages) |
| EU AI Act | [artificialintelligenceact.eu](https://artificialintelligenceact.eu/) |
| Independent assessments | [Thoughtworks Technology Radar](https://www.thoughtworks.com/radar/languages-and-frameworks/agent-development-kit-adk) |

## Part 1: Orchestration and frameworks

**Multi-agent collaboration and A2A**

- [A2A specification](https://a2a-protocol.org/latest/specification/)
- [A2A joins the Agentic AI Foundation](https://aaif.io/blog/a2a-joins-aaif)
- [Linux Foundation: A2A first-year adoption](https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year)

**Microsoft**

- [Microsoft Agent Framework 1.0 announcement](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/)
- [Agent Framework workflows](https://learn.microsoft.com/en-us/agent-framework/workflows/)
- [Agent Framework checkpoints](https://learn.microsoft.com/en-us/agent-framework/workflows/checkpoints)
- [Agent Framework observability](https://learn.microsoft.com/en-us/agent-framework/user-guide/observability)
- [Agent Framework on Azure Durable Functions](https://learn.microsoft.com/en-us/agent-framework/hosting/azure-functions)
- [Migrating from AutoGen to Agent Framework](https://learn.microsoft.com/en-us/agent-framework/migration-guide/from-autogen/)
- [Semantic Kernel and Microsoft Agent Framework](https://devblogs.microsoft.com/semantic-kernel/semantic-kernel-and-microsoft-agent-framework/)
- [AutoGen maintenance-mode announcement](https://github.com/microsoft/autogen/discussions/7066)
- [AG2 repository](https://github.com/ag2ai/ag2)
- [Microsoft Foundry Agent Service](https://learn.microsoft.com/en-us/azure/foundry/agents/overview)
- [Copilot Studio: what's new](https://learn.microsoft.com/en-us/microsoft-copilot-studio/whats-new)

**Google**

- [ADK documentation](https://adk.dev/)
- [ADK 2.0](https://adk.dev/2.0/)
- [ADK callbacks](https://adk.dev/callbacks/)
- [ADK tool confirmation](https://adk.dev/tools-custom/confirmation/)
- [ADK evaluation](https://adk.dev/evaluate/)
- [ADK deployment](https://adk.dev/deploy/)
- [Gemini Enterprise Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes)
- [Managed Agents in the Gemini API](https://blog.google/innovation-and-ai/technology/developers-tools/managed-agents-gemini-api)

**OpenAI**

- [Agents SDK documentation](https://openai.github.io/openai-agents-python/)
- [Agents SDK human-in-the-loop](https://openai.github.io/openai-agents-python/human_in_the_loop/)
- [Agents SDK repository](https://github.com/openai/openai-agents-python)
- [The next evolution of the Agents SDK](https://openai.com/index/the-next-evolution-of-the-agents-sdk/)
- [OpenAI API deprecations](https://developers.openai.com/api/docs/deprecations.md)

**LangChain, CrewAI and Mastra**

- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)
- [LangChain agents](https://docs.langchain.com/oss/python/langchain/agents)
- [LangGraph interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)
- [LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)
- [Deep Agents overview](https://docs.langchain.com/oss/python/deepagents/overview)
- [LangSmith Agent Server](https://docs.langchain.com/langsmith/agent-server)
- [LangSmith Deployment](https://docs.langchain.com/langsmith/deployment)
- [CrewAI introduction](https://docs.crewai.com/en/introduction)
- [CrewAI Flows](https://docs.crewai.com/en/concepts/flows)
- [CrewAI checkpointing](https://docs.crewai.com/en/concepts/checkpointing)
- [CrewAI observability](https://docs.crewai.com/en/observability/overview)
- [Mastra 1.0 changelog](https://mastra.ai/blog/changelog-2026-01-20)
- [Mastra workflows](https://mastra.ai/docs/workflows/overview)
- [Mastra suspend and resume](https://mastra.ai/docs/workflows/suspend-and-resume)
- [Mastra memory](https://mastra.ai/docs/memory/overview)
- [Mastra deployment](https://mastra.ai/docs/deployment/overview)

**Other SDKs**

- [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- [Pydantic AI](https://pydantic.dev/docs/ai/overview/)
- [AWS Strands Agents](https://strandsagents.com/latest/)
- [Vercel AI SDK 7](https://vercel.com/blog/ai-sdk-7)
- [LlamaIndex Workflows](https://developers.llamaindex.ai/python/llamaagents/workflows/)
- [Haystack agents](https://docs.haystack.deepset.ai/docs/agents)
- [Agno](https://docs.agno.com/introduction)
- [smolagents](https://huggingface.co/docs/smolagents/index)
- [DSPy](https://dspy.ai/current/)
- [Letta](https://docs.letta.com/)

**Managed runtimes and durable execution**

- [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- [Bedrock AgentCore quotas and limits](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/bedrock-agentcore-limits.html)
- [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
- [Temporal integration with the OpenAI Agents SDK](https://docs.temporal.io/develop/python/integrations/openai-agents)
- [Restate for AI agents](https://docs.restate.dev/ai)
- [DBOS](https://docs.dbos.dev/)
- [Inngest: durable steps for AI agents](https://www.inngest.com/blog/ai-agents-inngest-durable-steps.md)
- [Cloudflare Agents](https://developers.cloudflare.com/agents/)
- [AWS Step Functions agentic reasoning step](https://aws.amazon.com/about-aws/whats-new/2026/06/aws-step-functions-agentcore/)

**Low-code builders**

- [n8n release notes](https://docs.n8n.io/release-notes/)
- [Dify open-source licence](https://docs.dify.ai/policies/open-source)
- [Langflow release notes](https://docs.langflow.org/release-notes)
- [Zapier Agents](https://zapier.com/agents)
- [Flowise repository (archived)](https://github.com/FlowiseAI/Flowise)

**Protocols and governance**

- [AG-UI](https://github.com/ag-ui-protocol/ag-ui)
- [Agent Client Protocol](https://agentclientprotocol.com/)
- [AP2](https://ap2-protocol.org/)
- [Agentic Commerce Protocol](https://docs.stripe.com/agentic-commerce/protocols/acp)
- [Agentic AI Foundation](https://aaif.io/)
- [Formation of the Agentic AI Foundation](https://linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation)

## Part 2: Tools

**Tool design and provider tools**

- [Anthropic: writing effective tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- [Claude: defining tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)
- [Claude: tool reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-reference)
- [Claude: strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use)
- [Claude: MCP connector](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector)
- [OpenAI: function calling](https://developers.openai.com/api/docs/guides/function-calling)
- [OpenAI: tools](https://developers.openai.com/api/docs/guides/tools)
- [Gemini: tools](https://ai.google.dev/gemini-api/docs/tools)
- [Gemini: function calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Anthropic: advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use)
- [Anthropic: code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [Agent Skills specification](https://agentskills.io/specification)

**Model Context Protocol**

- [MCP specification versioning](https://modelcontextprotocol.io/specification/versioning)
- [MCP 2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)
- [MCP authorisation](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)
- [MCP SDKs](https://modelcontextprotocol.io/docs/sdk)
- [MCP extensions](https://modelcontextprotocol.io/docs/extensions/overview)
- [MCP Enterprise-Managed Authorization](https://modelcontextprotocol.io/extensions/auth/enterprise-managed-authorization)
- [MCP Apps announcement](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/)
- [MCP Registry](https://modelcontextprotocol.io/registry/about)
- [MCP joins the Agentic AI Foundation](https://blog.modelcontextprotocol.io/posts/2025-12-09-mcp-joins-agentic-ai-foundation/)

**MCP security and gateways**

- [MCP security best practices](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices) (confirm URL shape at next refresh; see the table above)
- [MCP blog: tool annotations and the lethal trifecta](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/)
- [Invariant Labs: MCP tool poisoning attacks](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks)
- [Cloud Security Alliance: MCP security whitepaper](https://labs.cloudsecurityalliance.org/research-rb/csa-whitepaper-mcp-security-tool-poisoning-20260506-csa-styl/)
- [OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/)
- [Docker MCP Gateway](https://docs.docker.com/ai/mcp-gateway/)
- [Bedrock AgentCore Gateway](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway.html)
- [Cloudflare MCP Server Portals](https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/mcp-portals)
- [Kong MCP plugins](https://developer.konghq.com/mcp/)
- [Azure API Management MCP servers](https://learn.microsoft.com/en-us/azure/api-management/mcp-server-overview)
- [microsoft/mcp-gateway](https://github.com/microsoft/mcp-gateway)

## Part 3: RAG

**Loading and parsing**

- [Unstructured connectors](https://docs.unstructured.io/ui/connectors)
- [Unstructured partitioning strategies](https://docs.unstructured.io/open-source/concepts/partitioning-strategies)
- [LlamaIndex data connectors](https://developers.llamaindex.ai/python/framework/module_guides/loading/connector/)
- [Airbyte vector destinations (Pinecone)](https://docs.airbyte.com/integrations/destinations/pinecone)
- [Docling](https://github.com/docling-project/docling)
- [LlamaParse tiers](https://developers.llamaindex.ai/llamaparse/parse/guides/tiers/index.md) and [pricing](https://developers.llamaindex.ai/llamaparse/general/pricing/)
- [Marker](https://github.com/datalab-to/marker)
- [Mistral OCR](https://docs.mistral.ai/capabilities/document_ai/basic_ocr/)
- [Azure Document Intelligence](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/overview)
- [Azure Content Understanding updates](https://devblogs.microsoft.com/foundry/azure-content-understanding-updates-august-2026)
- [Google Document AI Layout Parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk)
- [AWS Textract](https://docs.aws.amazon.com/textract/latest/dg/what-is.html)

**Chunking**

- [Anthropic: contextual retrieval](https://www.anthropic.com/news/contextual-retrieval)
- [Chroma: evaluating chunking strategies](https://www.trychroma.com/research/evaluating-chunking)
- [NVIDIA: finding the best chunking strategy](https://developer.nvidia.com/blog/finding-the-best-chunking-strategy-for-accurate-ai-responses/)
- [Jina: late chunking](https://jina.ai/news/late-chunking-in-long-context-embedding-models/)
- [OpenAI vector store chunking](https://developers.openai.com/api/reference/resources/vector_stores/subresources/files/methods/create)
- [Bedrock Knowledge Bases chunking](https://docs.aws.amazon.com/bedrock/latest/userguide/kb-chunking.html)

**Embedding**

- [Cohere models](https://docs.cohere.com/docs/models) and [changelog](https://docs.cohere.com/changelog)
- [Voyage embeddings](https://docs.voyageai.com/docs/embeddings) and [pricing](https://docs.voyageai.com/docs/pricing)
- [Gemini embeddings](https://ai.google.dev/gemini-api/docs/embeddings)
- [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings)
- [Qwen3-Embedding](https://huggingface.co/Qwen/Qwen3-Embedding-8B)
- [BGE-M3](https://huggingface.co/BAAI/bge-m3)
- [Jina embeddings v5](https://jina.ai/news/jina-embeddings-v5-text-distilling-4b-quality-into-sub-1b-multilingual-embeddings)
- [Nomic Embed Text v2](https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe)
- [Hugging Face: embedding quantisation](https://huggingface.co/blog/embedding-quantization)
- [ColPali (paper)](https://arxiv.org/abs/2407.01449)

**Storage**

- [pgvector](https://github.com/pgvector/pgvector) and [pgvectorscale](https://github.com/timescale/pgvectorscale)
- [MongoDB Atlas Vector Search](https://www.mongodb.com/docs/atlas/atlas-vector-search/vector-search-overview/)
- [Elasticsearch DiskBBQ](https://www.elastic.co/search-labs/blog/diskbbq-elasticsearch-introduction)
- [Qdrant indexing](https://qdrant.tech/documentation/concepts/indexing/)
- [Pinecone indexing](https://docs.pinecone.io/guides/index-data/indexing-overview)
- [Weaviate vector indexes](https://docs.weaviate.io/weaviate/concepts/vector-index)
- [Milvus indexes](https://milvus.io/docs/index-explained.md)
- [Chroma Cloud](https://docs.trychroma.com/cloud/getting-started)
- [turbopuffer](https://turbopuffer.com/docs)
- [LanceDB](https://docs.lancedb.com/)
- [Amazon S3 Vectors](https://aws.amazon.com/blogs/aws/amazon-s3-vectors-now-generally-available-with-increased-scale-and-performance)

**Retrieval and re-ranking**

- [Elasticsearch reciprocal rank fusion](https://www.elastic.co/docs/reference/elasticsearch/rest-apis/reciprocal-rank-fusion)
- [Azure hybrid search ranking](https://learn.microsoft.com/en-us/azure/search/hybrid-search-ranking)
- [Azure agentic retrieval](https://learn.microsoft.com/en-us/azure/search/agentic-retrieval-overview)
- [Azure semantic ranker](https://learn.microsoft.com/en-us/azure/search/semantic-search-overview)
- [Query rewriting for retrieval-augmented LLMs (paper)](https://arxiv.org/abs/2305.14283)
- [HyDE (paper)](https://arxiv.org/abs/2212.10496)
- [Microsoft GraphRAG](https://microsoft.github.io/graphrag/) and [LazyGraphRAG](https://www.microsoft.com/en-us/research/blog/lazygraphrag-setting-a-new-standard-for-quality-and-cost/)
- [LightRAG](https://github.com/HKUDS/LightRAG)
- [Anthropic: multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)
- [Chroma: context rot](https://www.trychroma.com/research/context-rot)
- [Databricks: long-context RAG performance](https://www.databricks.com/blog/long-context-rag-performance-llms)
- [Cohere reranking best practices](https://docs.cohere.com/docs/reranking-best-practices)
- [Voyage rerankers](https://docs.voyageai.com/docs/reranker)
- [Qwen3-Reranker](https://huggingface.co/Qwen/Qwen3-Reranker-8B)
- [mixedbread mxbai-rerank-v2](https://www.mixedbread.com/blog/mxbai-rerank-v2)
- [Jina reranker v3.5](https://huggingface.co/jinaai/jina-reranker-v3.5)
- [ColBERT](https://github.com/stanford-futuredata/ColBERT)
- [Google RAG Engine retrieval and ranking](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/rag-engine/retrieval-and-ranking)

**Ingestion**

- [Bedrock Knowledge Bases sync](https://docs.aws.amazon.com/bedrock/latest/userguide/kb-data-source-sync-ingest.html)
- [Bedrock Knowledge Bases overview](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- [Azure AI Search indexers](https://learn.microsoft.com/en-us/azure/search/search-howto-create-indexers)
- [Azure AI Search document-level access](https://learn.microsoft.com/en-us/azure/search/search-document-level-access-overview)
- [LlamaIndex ingestion pipeline](https://developers.llamaindex.ai/python/framework/module_guides/loading/ingestion_pipeline/)
- [Presidio](https://presidio.dataprivacystack.org/)
- [OpenAI pricing](https://developers.openai.com/api/docs/pricing)

## Part 4: Observability

**Tracing and monitoring**

- [OpenTelemetry GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai)
- [OpenTelemetry GenAI overview](https://raw.githubusercontent.com/open-telemetry/semantic-conventions-genai/main/docs/gen-ai/README.md)
- [OpenTelemetry GenAI agent spans](https://raw.githubusercontent.com/open-telemetry/semantic-conventions-genai/main/docs/gen-ai/gen-ai-agent-spans.md)
- [ADK observability](https://adk.dev/observability/)
- [OpenAI Agents SDK tracing](https://openai.github.io/openai-agents-python/tracing/)
- [LangSmith with OpenTelemetry](https://docs.langchain.com/langsmith/trace-with-opentelemetry)
- [OpenInference](https://github.com/Arize-ai/openinference)
- [OpenLLMetry](https://github.com/traceloop/openllmetry)

**Observability platforms**

- [Langfuse](https://langfuse.com/docs/opentelemetry/get-started)
- [LangSmith observability](https://docs.langchain.com/langsmith/observability.md)
- [Arize Phoenix](https://github.com/Arize-ai/phoenix)
- [Braintrust](https://www.braintrust.dev/docs)
- [MLflow GenAI](https://mlflow.org/docs/latest/genai/)
- [Comet Opik](https://github.com/comet-ml/opik)
- [W&B Weave](https://github.com/wandb/weave)
- [Pydantic Logfire](https://logfire.pydantic.dev/docs/)
- [Datadog LLM Observability](https://docs.datadoghq.com/llm_observability/)
- [Dynatrace AI observability](https://docs.dynatrace.com/docs/observe/dynatrace-for-ai-observability)
- [New Relic AI monitoring](https://docs.newrelic.com/docs/ai-monitoring/intro-to-ai-monitoring/)
- [ClickHouse acquires Langfuse](https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability)
- [Traceloop joins ServiceNow](https://traceloop.com/blog/traceloop-is-joining-servicenow)
- [Cisco to acquire Galileo](https://blogs.cisco.com/news/cisco-announces-the-intent-to-acquire-galileo)
- [Helicone joins Mintlify](https://helicone.ai/blog/joining-mintlify)

**Logging, regulation and cost**

- [EU AI Act Article 12 (record-keeping)](https://artificialintelligenceact.eu/article/12/)
- [EU AI Act Article 19 (logs)](https://artificialintelligenceact.eu/article/19/)
- [EU AI Act Article 26 (deployers)](https://artificialintelligenceact.eu/article/26/)
- [Cuatrecasas: Digital Omnibus on AI published](https://www.cuatrecasas.com/en/spain/intellectual-property/art/digital-omnibus-ai-has-been-published)
- [Gibson Dunn: EU AI Act omnibus deadlines](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/)
- [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
- [Gemini context caching](https://ai.google.dev/gemini-api/docs/caching)

**Evaluation and benchmarks**

- [LangSmith evaluation concepts](https://docs.langchain.com/langsmith/evaluation-concepts)
- [Judging LLM-as-a-judge (paper)](https://arxiv.org/abs/2306.05685)
- [Ragas metrics](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/)
- [DeepEval](https://deepeval.com/docs/getting-started)
- [promptfoo](https://www.promptfoo.dev/docs/intro/)
- [Inspect AI](https://inspect.aisi.org.uk/)
- [OpenAI Evals platform](https://developers.openai.com/api/docs/guides/evals)
- [SWE-bench Pro](https://labs.scale.com/leaderboard/swe_bench_pro)
- [Why OpenAI no longer evaluates SWE-bench Verified](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)
- [τ-bench](https://taubench.com/)
- [Terminal-Bench](https://www.tbench.ai/)
- [OSWorld](http://osworld-v1.xlang.ai/)
- [GAIA (paper)](https://arxiv.org/abs/2311.12983)
- [BrowseComp](https://openai.com/index/browsecomp/)
- [MCP-Atlas (paper)](https://arxiv.org/abs/2602.00933v1)

## Part 5: Cross-cutting concerns

Platform identity (Entra Agent ID, AgentCore Identity, Google Agent Identity), MCP authorisation and the Enterprise-Managed Authorization extension are cited from the Part 1 and Part 2 pages above. Sources specific to Part 5:

**Security and privilege separation**

- [Meta: Agents Rule of Two](https://ai.meta.com/blog/practical-ai-agent-security/) (URL to confirm at next refresh)
- [CaMeL: defeating prompt injections by design (paper)](https://arxiv.org/abs/2503.18813)
- [Simon Willison: the lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/)

**Authorisation and policy**

- [Cedar policy language](https://www.cedarpolicy.com/)
- [Open Policy Agent](https://www.openpolicyagent.org/docs/)
- [OpenFGA](https://openfga.dev/docs)
- [SpiceDB](https://authzed.com/docs)

**Model gateways**

- [LiteLLM](https://docs.litellm.ai/docs/)
- [Portkey](https://portkey.ai/docs)
- [OpenRouter](https://openrouter.ai/docs)
- [Vercel AI Gateway](https://vercel.com/docs/ai-gateway)
- [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/)
- [Kong AI Gateway](https://developer.konghq.com/ai-gateway/) (URL to confirm at next refresh)

**Self-hosted inference**

- [vLLM](https://docs.vllm.ai/)
- [SGLang](https://docs.sglang.ai/) (URL to confirm at next refresh)
- [NVIDIA TensorRT-LLM](https://nvidia.github.io/TensorRT-LLM/) and [NVIDIA NIM](https://docs.nvidia.com/nim/)
- [Ollama](https://github.com/ollama/ollama)
- [llama.cpp](https://github.com/ggml-org/llama.cpp)

**User interface kits**

- [CopilotKit](https://docs.copilotkit.ai/)
- [OpenAI ChatKit](https://platform.openai.com/docs/guides/chatkit) (URL to confirm at next refresh)

**Data governance**

- [Text embeddings reveal (almost) as much as text (paper, embedding inversion)](https://arxiv.org/abs/2310.06816)

**Red teaming**

- [PyRIT](https://azure.github.io/PyRIT/)
- [garak](https://github.com/NVIDIA/garak)
- [AgentDojo (paper)](https://arxiv.org/abs/2406.13352)
- [promptfoo red teaming](https://www.promptfoo.dev/docs/red-team/)

**Guardrail tools**

- [Llama Guard and Prompt Guard](https://www.llama.com/docs/model-cards-and-prompt-formats/) (URL to confirm at next refresh)
- [Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/overview)
- [Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [Google Model Armor](https://cloud.google.com/security-command-center/docs/model-armor-overview)
- [NVIDIA NeMo Guardrails](https://github.com/NVIDIA/NeMo-Guardrails)
- [Guardrails AI](https://www.guardrailsai.com/docs) and [LLM Guard](https://llm-guard.com/)
