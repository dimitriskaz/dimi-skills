# RAG layer

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Contents:

- Loading
- Parsing
- Chunking
- Embedding
- Storage
- Retrieval
- Re-ranking
- Ingestion

## Loading

Loading pulls raw content and its metadata out of the client's systems. Most enterprise RAG quality problems start here: missing sources, lost permissions and stale copies, not the embedding model.

**What to capture for every document**

- The content itself, in its original format.
- A stable source ID and URL, so answers can cite and link back.
- Last-modified time and a content hash, for incremental updates.
- Access control: who may see it (users, groups, labels). Capture it now; retrofitting permissions later is painful.
- Business metadata: owner, department, document type, product, region, language.

**Connector options**

| Option | What it offers |
| --- | --- |
| [Unstructured](https://docs.unstructured.io/ui/connectors) | Source connectors for SharePoint, Confluence, Google Drive, Slack, Box, OneDrive, Jira, S3, Salesforce, Outlook and Zendesk, with destinations in most vector stores |
| [LlamaIndex readers](https://developers.llamaindex.ai/python/framework/module_guides/loading/connector/) | One package per source (`llama-index-readers-<source>`), from Slack and Notion to Google Docs |
| [Airbyte](https://docs.airbyte.com/integrations/destinations/pinecone) | Hundreds of sources; vector-database destinations that chunk, embed and deduplicate incrementally |
| Managed knowledge bases | Bedrock Knowledge Bases, Azure AI Search indexers and Google RAG Engine connect to common sources and sync on a schedule |
| Custom loaders | Direct API calls for the client's internal systems, which no connector covers |

**Practical advice**

- Start with the two or three sources that answer most real questions, measured against your eval set, not with "everything".
- Prefer the system's API over file exports: you get metadata, permissions and change feeds.
- Respect rate limits and run loads off-peak; a full SharePoint crawl can take days.
- Keep the raw copy in object storage, so you can re-parse without re-fetching when your parser improves.

## Parsing

Parsing turns PDFs, Office files, scans and web pages into clean, structured text (usually Markdown or JSON) with headings, tables and reading order preserved. On real enterprise documents it is often the single biggest lever on answer quality, because a table parsed into soup cannot be retrieved correctly by any embedding model.

**The three approaches**

- **Text extraction**: read the embedded text layer. Fast and cheap, but fails on scans and mangles complex layouts.
- **Layout and OCR models**: detect blocks, tables, headings and reading order, and OCR images. The default for mixed corpora.
- **Vision-language models**: send page images to a VLM that writes structured Markdown. Best on hard layouts, charts and handwriting; slower and costlier.

**Parsers worth knowing**

| Parser | Type | Notes |
| --- | --- | --- |
| [Docling](https://github.com/docling-project/docling) (IBM) | Open source, MIT | PDF, Office, HTML, email, audio; Markdown or JSON output; runs fully air-gapped; optional small VLM; ships an MCP server |
| [Unstructured](https://docs.unstructured.io/open-source/concepts/partitioning-strategies) | Open source plus platform | Partition strategies `fast`, `hi_res` and `ocr_only`; element types feed structure-aware chunking |
| [LlamaParse](https://developers.llamaindex.ai/llamaparse/parse/guides/tiers/index.md) | Hosted | Four tiers from Fast to Agentic Plus, priced from 1 to 45 credits a page ([pricing](https://developers.llamaindex.ai/llamaparse/general/pricing/)) |
| [Marker](https://github.com/datalab-to/marker) | Open code, restricted weights | Model weights use a modified OpenRAIL-M licence that needs a paid plan for larger commercial users; check the code licence too, as it has been copyleft (GPL-3.0) in the past |
| MinerU | Open source | VLM-based pipeline with an effort setting for hard pages; historically AGPL-3.0, which matters for SaaS and redistribution |
| [Mistral OCR](https://docs.mistral.ai/capabilities/document_ai/basic_ocr/) | Hosted or self-hosted | Typed blocks, tables as HTML or Markdown, and confidence scores per page, block and word |
| [Azure Document Intelligence](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/overview) and [Content Understanding](https://devblogs.microsoft.com/foundry/azure-content-understanding-updates-august-2026) | Cloud | Document Intelligence for deterministic extraction; Content Understanding adds generative analyzers and semantic chunking |
| [Google Document AI Layout Parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk) | Cloud | Gemini-assisted layout tree; outputs chunks that carry their ancestor headings |
| [AWS Textract](https://docs.aws.amazon.com/textract/latest/dg/what-is.html) | Cloud | Forms, tables, queries, plus expense, ID and lending analysers |
| Reducto | Hosted | Parse, split and extract APIs aimed at complex enterprise documents |

Check the current licence file of any open-source parser before shipping it to a client: copyleft terms affect clients who redistribute software or run it as a service.

**How to choose**

1. Build a parsing test set of 20 to 50 of the client's worst documents: scanned contracts, multi-column reports, tables spanning pages.
2. Run two or three parsers and compare the Markdown side by side; table fidelity and reading order are the usual differentiators.
3. Check the deployment constraint early. Regulated clients often need an air-gapped option such as Docling or a self-hosted OCR model.
4. Route by document type: cheap extraction for born-digital text, a VLM tier only for pages that need it.
5. Keep confidence scores and page coordinates, so low-confidence pages can go to review and answers can cite the exact page.

## Chunking

Chunking splits parsed documents into retrievable pieces. A good chunk is small enough to be precise, large enough to make sense on its own, and carries enough context to be found. Start simple, measure on your eval set, and only then add sophistication.

| Strategy | How it works | When to use it |
| --- | --- | --- |
| Fixed-size with overlap | Split every N tokens, overlapping by M | Baseline only |
| Recursive | Split on paragraphs, then sentences, then words, until under the size limit | A strong default for prose |
| Structure-aware | Split on headings, sections or document elements; keep tables whole | Manuals, policies, reports with clear structure |
| Page-level | One chunk per page | Paginated PDFs; NVIDIA found it the most consistent ([NVIDIA](https://developer.nvidia.com/blog/finding-the-best-chunking-strategy-for-accurate-ai-responses/)) |
| Semantic | Break where embedding similarity between sentences drops | Long unstructured text |
| Hierarchical (parent-child) | Match small child chunks, return their larger parent | When precise matching and full context are both needed |
| Contextual | Prepend a short, model-written summary of where the chunk sits in its document | Most enterprise corpora; see below |
| Late chunking | Embed the whole document first, then pool token vectors per chunk | Needs a long-context embedding model ([Jina](https://jina.ai/news/late-chunking-in-long-context-embedding-models/)) |
| Propositions | Rewrite text into atomic facts and index those | Fact-heavy question answering; costly to build |

**What the evidence says about size**

- Chroma's study found recursive splitting at about 200 tokens with no overlap consistently strong, and the old 800-token, 400-overlap default weak ([Chroma](https://www.trychroma.com/research/evaluating-chunking)).
- NVIDIA suggests 256 to 512 tokens for factoid questions and about 1,024 for analytical ones, with around 15% overlap ([NVIDIA](https://developer.nvidia.com/blog/finding-the-best-chunking-strategy-for-accurate-ai-responses/)).
- Managed defaults vary: OpenAI vector stores use 800 tokens with 400 overlap ([OpenAI](https://developers.openai.com/api/reference/resources/vector_stores/subresources/files/methods/create)); Bedrock Knowledge Bases default to about 300 tokens ([AWS](https://docs.aws.amazon.com/bedrock/latest/userguide/kb-chunking.html)). Do not accept a default without testing it.

**Contextual retrieval**

Anthropic's technique has a model write 50 to 100 tokens of context for each chunk, which is prepended before both embedding and keyword indexing ([Anthropic](https://www.anthropic.com/news/contextual-retrieval)). In their tests the top-20 retrieval failure rate fell from 5.7% to 3.7% with contextual embeddings (35% fewer failures), to 2.9% when contextual BM25 was added (49% fewer), and to 1.9% with reranking on top (67% fewer). The one-time cost was about $1.02 per million document tokens using prompt caching. They also note that a knowledge base under about 200,000 tokens can simply go in the prompt, though test that against your eval set given the context-rot findings under Retrieval.

**Rules of thumb**

- Never split a table row, a code block or a numbered procedure across chunks.
- Store the section path (document › chapter › heading) as metadata and prepend it to the chunk text.
- Keep chunk IDs stable across re-ingestion, so citations and caches survive updates.

## Embedding

An embedding model turns each chunk and each query into a vector, so that similar meanings land close together. Model choice matters less than parsing and chunking, but it sets your cost, latency, language coverage and lock-in.

**Current models (October 2026)**

| Model | Provider type | Context | Dimensions | Notes |
| --- | --- | --- | --- | --- |
| [Cohere Embed 5](https://docs.cohere.com/docs/models) (Pro, Fast) | API | 128k | 256 to 2,048 | Released Sep 2026; text, images and mixed PDFs; Pro and Fast share one vector space ([changelog](https://docs.cohere.com/changelog)) |
| [Voyage 4](https://docs.voyageai.com/docs/embeddings) (large, base, lite, nano) | API, nano open-weight | 32k | 256 to 2,048 | All four share one vector space, so you can index with large and query with lite; $0.02 to $0.12 per million tokens ([pricing](https://docs.voyageai.com/docs/pricing)) |
| [Gemini Embedding 2](https://ai.google.dev/gemini-api/docs/embeddings) | API | 8,192 | 128 to 3,072 | GA Apr 2026; text, image, video, audio and PDF in one space |
| [OpenAI text-embedding-3](https://developers.openai.com/api/docs/guides/embeddings) (large, small) | API | 8,192 | up to 3,072 / 1,536 | No newer model listed; $0.13 and $0.02 per million tokens |
| [Qwen3-Embedding](https://huggingface.co/Qwen/Qwen3-Embedding-8B) (0.6B to 8B) | Open weights, Apache-2.0 | 32k | Flexible | Strong multilingual self-hosted option |
| [BGE-M3](https://huggingface.co/BAAI/bge-m3) | Open weights, MIT | 8,192 | 1,024 | Dense, sparse and multi-vector output from one model |
| [Jina v5](https://jina.ai/news/jina-embeddings-v5-text-distilling-4b-quality-into-sub-1b-multilingual-embeddings) | Open weights, non-commercial | 32k | Flexible | Licence needs a commercial agreement |
| [Nomic Embed v2](https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe) | Open weights, Apache-2.0 | 512 | 768 to 256 | Fully open training data |

**Techniques that cut cost**

- **Matryoshka dimensions**: most current models let you truncate vectors (for example from 2,048 to 512) with modest quality loss, shrinking storage and speeding search.
- **Quantisation**: int8 vectors are 4x smaller and keep about 99% of quality; binary vectors are 32x smaller and keep about 96% when results are rescored ([Hugging Face](https://huggingface.co/blog/embedding-quantization)).
- **Shared embedding spaces**: Voyage 4 and Cohere Embed 5 let you change the query-side model without re-indexing the corpus.

**Multimodal and visual documents**

For slide decks, scanned forms and chart-heavy reports, embedding page images directly can beat parsing them to text. ColPali-style models embed each page as many small vectors and score them by late interaction ([paper](https://arxiv.org/abs/2407.01449)); multimodal APIs such as Cohere Embed 5, Gemini Embedding 2 and voyage-multimodal-3.5 accept images natively.

**How to choose**

1. Shortlist three models that meet the client's hosting rule (API vs self-hosted) and language needs.
2. Run them on your own retrieval eval set and compare recall@k; public leaderboards such as MTEB are a starting filter, not a decision.
3. Factor in total cost: embedding the corpus once, re-embedding on updates, and vector storage at your chosen dimension.
4. Record the model and version on every vector. Switching model families means re-indexing everything, so plan for it.

## Storage

The vector store holds embeddings, chunk text and metadata, and answers nearest-neighbour queries with filters. For most engagements the best store is one the client already operates; a dedicated vector database earns its place at large scale, heavy multi-tenancy or very low latency targets.

**Options by category**

| Category | Options | Strengths |
| --- | --- | --- |
| Extend an existing database | [pgvector](https://github.com/pgvector/pgvector) and [pgvectorscale](https://github.com/timescale/pgvectorscale) on Postgres, [MongoDB Atlas](https://www.mongodb.com/docs/atlas/atlas-vector-search/vector-search-overview/), [Elasticsearch](https://www.elastic.co/search-labs/blog/diskbbq-elasticsearch-introduction) and OpenSearch | No new system to secure; joins with business data; mature backup and access control |
| Dedicated vector databases | [Qdrant](https://qdrant.tech/documentation/concepts/indexing/), [Pinecone](https://docs.pinecone.io/guides/index-data/indexing-overview), [Weaviate](https://docs.weaviate.io/weaviate/concepts/vector-index), [Milvus](https://milvus.io/docs/index-explained.md), [Chroma](https://docs.trychroma.com/cloud/getting-started) | Rich filtering, quantisation and hybrid search; built for scale |
| Object-storage-first | [turbopuffer](https://turbopuffer.com/docs), [LanceDB](https://docs.lancedb.com/), [S3 Vectors](https://aws.amazon.com/blogs/aws/amazon-s3-vectors-now-generally-available-with-increased-scale-and-performance) | Very cheap at huge scale; slower cold queries |
| Cloud search services | Azure AI Search, Google Agent Retrieval (formerly Vector Search), Bedrock Knowledge Bases backends | Managed indexing, connectors and permission filtering |

**Index types**

- **HNSW**: a navigable graph in memory; fast and accurate, the default almost everywhere, but memory-hungry.
- **IVF**: clusters vectors and searches only the nearest clusters; lighter on memory, slightly less accurate.
- **DiskANN and disk-based variants**: keep most of the index on SSD for collections too big for RAM (pgvectorscale's StreamingDiskANN, Elasticsearch DiskBBQ, Milvus DISKANN).
- **Flat (exact)**: brute force; fine under roughly 100,000 vectors and for testing.

**What to check before choosing**

- **Filtered search quality**: permission and metadata filters can wreck recall on naive HNSW. Look for filter-aware indexing (Qdrant, pgvector's iterative scans).
- **Hybrid search**: native BM25 or sparse vectors next to dense ones saves running two systems.
- **Multi-tenancy**: namespaces, partitions or row-level security to keep clients' or departments' data apart.
- **Limits**: for example pgvector indexes vectors up to 2,000 dimensions (4,000 as half-precision), so truncate or quantise larger embeddings.
- **Operations**: backups, encryption keys, data residency, and who in the client's team will run it.

## Retrieval

Retrieval finds the chunks most likely to answer a query. In practice the winning default is hybrid search (keywords plus vectors) with metadata and permission filters, followed by a reranker; agentic retrieval then lets the model search again when the first results are not enough.

**Hybrid search**

Dense vectors catch meaning ("terminate" matches "cancel"); keyword search (BM25) catches exact terms such as product codes, names and error numbers. Running both and fusing the ranked lists beats either alone on most enterprise corpora. The usual fusion method is reciprocal rank fusion (RRF), where each list contributes to a document's score by its rank:

$$
\mathrm{RRF}(d) = \sum_{i} \frac{1}{k + \mathrm{rank}_i(d)}, \quad k = 60
$$

Elasticsearch and Azure AI Search use RRF with k = 60, and OpenAI file search also fuses its keyword and vector results with RRF ([Elastic](https://www.elastic.co/docs/reference/elasticsearch/rest-apis/reciprocal-rank-fusion), [Azure](https://learn.microsoft.com/en-us/azure/search/hybrid-search-ranking)).

**Improving the query**

| Technique | What it does |
| --- | --- |
| Query rewriting | A model turns a vague or conversational question into a precise search query ([paper](https://arxiv.org/abs/2305.14283)) |
| Multi-query | Generate several phrasings and fuse their results |
| HyDE | Write a hypothetical answer, embed it, and search with that ([paper](https://arxiv.org/abs/2212.10496)) |
| Decomposition | Split a compound question into sub-questions and retrieve for each |
| Filter extraction | Pull dates, products or regions out of the query and apply them as metadata filters |

**Beyond flat chunks**

- **GraphRAG**: extract entities and relationships, cluster them into communities and pre-summarise each, so the system can answer global questions such as "what are the main themes across these 5,000 reports?" ([Microsoft](https://microsoft.github.io/graphrag/)). LazyGraphRAG cuts indexing cost to about 0.1% of full GraphRAG ([Microsoft Research](https://www.microsoft.com/en-us/research/blog/lazygraphrag-setting-a-new-standard-for-quality-and-cost/)); [LightRAG](https://github.com/HKUDS/LightRAG) is a lighter open-source alternative.
- **Agentic retrieval**: retrieval becomes a tool the agent calls repeatedly, rewriting queries and following leads until it has enough. Azure AI Search now plans parallel sub-queries itself ([Azure](https://learn.microsoft.com/en-us/azure/search/agentic-retrieval-overview)). Anthropic found a multi-agent research system beat a single agent by 90.2% on its research eval, at roughly 15 times the tokens of a chat ([Anthropic](https://www.anthropic.com/engineering/built-multi-agent-research-system)).

**Long context versus RAG**

Bigger context windows have not made retrieval obsolete. Chroma's context-rot study across 18 models found reliability drops as input grows, with focused inputs of around 300 tokens beating 113,000-token ones ([Chroma](https://www.trychroma.com/research/context-rot)), and Databricks found many models degrade past 16,000 to 64,000 tokens ([Databricks](https://www.databricks.com/blog/long-context-rag-performance-llms)). Use long context for small, stable corpora and whole-document tasks; use retrieval for large, changing or permissioned ones.

**Enforce permissions at query time**

Apply the user's access filter inside the search query, never by post-filtering results in application code, and never by asking the model to ignore documents. Retrieve with the end user's identity so the agent can only see what that person could see.

## Re-ranking

A reranker reads the query and each candidate chunk together and scores how well the chunk answers the query. It is slower than vector search but far more precise, so the standard pattern is to retrieve broadly (about 50 to 150 candidates) and rerank down to the 5 to 20 the model will read. In Anthropic's contextual retrieval tests, adding a reranker took the failure reduction from 49% to 67% ([Anthropic](https://www.anthropic.com/news/contextual-retrieval)).

**Reranker types**

| Type | How it works | Trade-off |
| --- | --- | --- |
| Cross-encoder | Scores each query-chunk pair jointly | The default: best accuracy per millisecond |
| Late interaction (ColBERT) | Compares token-level vectors with a MaxSim score | Fast enough to use at retrieval time ([ColBERT](https://github.com/stanford-futuredata/ColBERT)) |
| Listwise | Reads all candidates at once and orders them | Strong but needs a long context window |
| LLM as reranker | A general model ranks or scores candidates | Flexible and instructable; slowest and costliest |

**Current options**

| Reranker | Licence | Notes |
| --- | --- | --- |
| [Cohere Rerank 5](https://docs.cohere.com/changelog) (Pro, Fast) | API | Released Oct 2026; 32k context; returns the relevant passage spans; calibrated scores; handles JSON, YAML and tables |
| [Voyage rerank](https://docs.voyageai.com/docs/reranker) | API | 32k context; instruction-following |
| [Qwen3-Reranker](https://huggingface.co/Qwen/Qwen3-Reranker-8B) (0.6B to 8B) | Open weights | Strong self-hosted option |
| [mixedbread mxbai-rerank-v2](https://www.mixedbread.com/blog/mxbai-rerank-v2) | Apache-2.0 | 0.5B and 1.5B sizes |
| [Jina reranker v3.5](https://huggingface.co/jinaai/jina-reranker-v3.5) | Non-commercial | Listwise, very long context |
| BGE reranker | Open weights | Widely used baseline |
| Built-in rankers | Managed | Azure AI Search semantic ranker reranks the top 50 ([Azure](https://learn.microsoft.com/en-us/azure/search/semantic-search-overview)); Google RAG Engine offers a fast ranking API or a Gemini ranker ([Google](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/rag-engine/retrieval-and-ranking)) |

**Using scores well**

- Use calibrated scores to drop irrelevant chunks with a threshold, rather than always passing a fixed top-k. Cohere suggests setting the threshold by scoring borderline documents from 30 to 50 representative queries ([Cohere](https://docs.cohere.com/docs/reranking-best-practices)).
- If nothing clears the threshold, tell the model there is no good source, so it can say "I don't know" instead of guessing.
- Rerank after permission filtering, never before, so restricted content never reaches the reranking service.

## Ingestion

Ingestion is the pipeline that runs loading, parsing, chunking and embedding continuously, keeping the index in step with the source systems. A RAG demo is a one-off script; a production RAG system is an ingestion pipeline with monitoring.

**A production ingestion pipeline**

1. **Detect changes** to content, metadata and permissions separately. Permission changes often leave the content hash and even the modified time unchanged, so read them from the source system's permission APIs or change events.
2. **Skip re-parsing and re-embedding unchanged content**, but still sync its metadata and access lists.
3. **Parse and chunk** the changed documents, routing each type to the right parser.
4. **Deduplicate and version**: drop near-duplicates, mark superseded versions, and record effective dates so retrieval can filter out or down-rank outdated documents.
5. **Enrich**: add contextual summaries, section paths and business metadata; detect and redact PII where policy requires.
6. **Embed** in batches, using batch APIs where they are cheaper.
7. **Upsert with permissions**: write vectors, text, metadata and access lists together, keyed by stable chunk IDs.
8. **Apply removals**: delete chunks for removed documents; on a permission change, update the access-list fields on every affected chunk rather than deleting content others may still see.
9. **Verify**: count documents and chunks, sample-check parsing, and run the retrieval eval set on the new index.

**How managed services handle it**

- Bedrock Knowledge Bases syncs incrementally, processing only added, modified and deleted documents, and skips re-embedding for metadata-only changes ([AWS](https://docs.aws.amazon.com/bedrock/latest/userguide/kb-data-source-sync-ingest.html)).
- Azure AI Search indexers track a high-water mark and offer resets to reprocess selectively ([Azure](https://learn.microsoft.com/en-us/azure/search/search-howto-create-indexers)).
- LlamaIndex's ingestion pipeline deduplicates by document ID and hash, caches each transformation step, and runs in parallel ([LlamaIndex](https://developers.llamaindex.ai/python/framework/module_guides/loading/ingestion_pipeline/)).

**Permissions: the hard part**

Document-level access control must flow from the source system into the index, then into every query. Support is still uneven: Bedrock Knowledge Bases filters by ACL for S3, SharePoint, Confluence, Google Drive and OneDrive but not its web crawler ([AWS](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)); in Azure AI Search only security filters are generally available, SharePoint and ADLS ACLs are in preview, and permission changes take effect only after a re-sync ([Azure](https://learn.microsoft.com/en-us/azure/search/search-document-level-access-overview)). Run permission sync on its own, shorter schedule or from permission-change events, alert when it lags, and test that a user whose access is revoked stops seeing results within an agreed time. Agree the permission model with the client's security team before building, and test it with users who should and should not see each document.

**Other operational concerns**

- **PII**: tools such as [Presidio](https://presidio.dataprivacystack.org/) detect and anonymise personal data before it is embedded or logged.
- **Re-embedding on model change**: switching model family means rebuilding the index. Build the new index alongside the old one, compare on the eval set, then switch.
- **Freshness monitoring**: alert when a source has not synced on schedule or when ingestion error rates rise.
- **Cost**: managed options charge per call and per GB stored, for example OpenAI file search at $2.50 per 1,000 calls plus $0.10 per GB per day ([OpenAI](https://developers.openai.com/api/docs/pricing)).
