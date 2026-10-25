# Tools layer: internal tools, external APIs and MCP

> From *The Agentic Harness: A Layer-by-Layer Guide*, as of 24 October 2026. Principles here change slowly; versions, statuses, prices and dates do not. Verify dated facts against live docs (Context7, or the official pages listed in `sources.md`) before relying on them, or ask the author to run `/dimi:refresh-harness`.

Contents:

- Internal tools
- External tools (APIs and MCP)

## Internal tools

Internal tools run inside the harness's own process or sandbox: functions you write, plus utilities the harness provides itself. They are the fastest, cheapest and most controllable tools, so anything you own should start here.

**How a tool reaches the model**

Every tool is presented to the model as a name, a description and a JSON Schema for its arguments. The model emits a call; the harness validates the arguments, runs the code and returns the result as a new message. Most frameworks generate the schema from a typed function signature and docstring, for example a decorated Python function with type hints or a TypeScript function with a Zod schema.

**Categories of internal tools**

| Category | Examples | Notes |
| --- | --- | --- |
| Business functions | `lookup_order`, `calculate_quote`, `create_ticket` | Wrap your client's domain logic; the bulk of an FDE's tool work |
| Data access | SQL query, search index, retrieval over a vector store | Prefer narrow, parameterised queries over free-form SQL |
| Harness utilities | Read and write files, to-do list, scratchpad notes, memory read and write | Support context management (Part 1) |
| Code execution | Run Python or shell in a sandbox | Very powerful; always isolate it |
| Agents as tools | Call a specialist agent and get its answer back | The supervisor pattern's building block |
| Human as a tool | `ask_human`, `request_approval` | Connects to the HITL flow |
| Control tools | `finish`, `hand_off_to_billing`, `update_plan` | Let the model signal intent to the harness |

**Design rules for tools the model can use well**

1. **Name and describe for the model, not for a developer.** Say what the tool does, when to use it, when not to, and what each argument means, with an example value.
2. **Prefer fewer, higher-level tools.** One `schedule_meeting` tool beats separate tools for checking calendars, finding slots and sending invites.
3. **Constrain arguments.** Use enums, formats, ranges and required fields so invalid calls fail validation before they run.
4. **Return only what the model needs.** Paginate, truncate, and return IDs plus key fields rather than whole records.
5. **Return actionable errors.** Say what was wrong and how to fix it.
6. **Make writes safe.** Stable idempotency keys (see failure recovery in Part 1), dry-run modes and approval gates for anything irreversible.
7. **Scope permissions tightly.** When a user is present, act with their delegated (on-behalf-of) permissions; for autonomous runs, use a dedicated least-privilege agent identity. Never use a shared, over-privileged account (Part 5).
8. **Test tools like APIs, then evaluate them like prompts.** Unit-test the code, and run evals to check the model picks the right tool with the right arguments.

Vendor guidance backs these rules. OpenAI suggests keeping fewer than 20 functions available at the start of a turn ([OpenAI](https://developers.openai.com/api/docs/guides/function-calling)). Anthropic's tool-use docs call the description by far the most important factor and suggest at least three or four sentences ([Anthropic docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)); its engineering guidance recommends namespaced names such as `asana_projects_search`, and notes that Claude Code caps tool responses at 25,000 tokens ([Anthropic](https://www.anthropic.com/engineering/writing-tools-for-agents)).

## External tools (APIs and MCP)

External tools are capabilities that live outside the harness: third-party and internal APIs, provider-hosted tools, and MCP servers. They multiply what an agent can do, and they are also where most security risk enters, because they carry untrusted data and real credentials.

**Three ways to reach an external system**

| Approach | How it works | Use it when |
| --- | --- | --- |
| Direct API wrapper | You write a function tool that calls the REST or GraphQL API | You need tight control, custom auth or a narrow slice of a big API |
| Provider-hosted tool | The model provider runs the tool on its servers (web search, code execution, file search, remote MCP connectors). Computer use is different: the provider defines the tool, but your harness executes the actions in a VM or browser you host | You want little infrastructure and accept the provider's data handling |
| MCP server | A standard server exposes tools, resources and prompts that any MCP-capable harness can use | The capability should be reusable across agents, frameworks or vendors |

OpenAPI specs can be converted into tools automatically by several frameworks, and cloud gateways (for example Bedrock AgentCore Gateway and Foundry toolboxes) turn existing APIs into managed MCP endpoints with authentication handled for you.

**Provider-hosted tools by vendor**

| Provider | Executed by the provider | Defined by the provider, executed by your harness | Schema enforcement |
| --- | --- | --- | --- |
| OpenAI Responses API | Web search, file search, code interpreter, remote MCP (approval required by default), image generation, tool search, skills ([OpenAI](https://developers.openai.com/api/docs/guides/tools)) | Computer use, `apply_patch`, local shell | Strict mode, recommended always on ([OpenAI](https://developers.openai.com/api/docs/guides/function-calling)) |
| Anthropic Claude API | Web search, web fetch, code execution, tool search, the MCP connector ([Anthropic](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-reference)) | Memory, bash, text editor, computer and browser toolsets | `strict: true` on tools ([Anthropic](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use)) |
| Google Gemini API | Google Search, Google Maps, code execution, URL context, file search ([Google](https://ai.google.dev/gemini-api/docs/tools)) | Computer use (preview) | `validated` tool-choice mode ([Google](https://ai.google.dev/gemini-api/docs/function-calling)) |

Check each hosted tool's data-retention terms before using it for a regulated client; Anthropic's MCP connector, for example, is not eligible for zero data retention ([Anthropic](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector)).

**Model Context Protocol (MCP)**

MCP is the open standard for connecting agents to tools and data. Anthropic introduced it in November 2024; on 9 December 2025 Anthropic, Block and OpenAI co-founded the Agentic AI Foundation under the Linux Foundation with MCP as a founding project, and MCP's maintainers keep technical control ([MCP](https://blog.modelcontextprotocol.io/posts/2025-12-09-mcp-joins-agentic-ai-foundation/)). The spec is versioned by date and the current revision is **2026-07-28** ([MCP](https://modelcontextprotocol.io/specification/versioning)). Official SDKs exist for TypeScript, Python, C#, Go, Rust and Ruby, with Java, Swift, PHP and Kotlin at lower tiers ([MCP](https://modelcontextprotocol.io/docs/sdk)).

| Concept | What it is in the 2026-07-28 revision |
| --- | --- |
| Host, client, server | The host app (your harness) runs one client per connected server |
| Tools | Functions with JSON Schema 2020-12 inputs, optional `outputSchema` and `structuredContent`, and `isError` results the model can act on |
| Resources | Read-only data the host can attach to context, addressed by URI |
| Prompts | Reusable prompt templates a server offers |
| Elicitation | The remaining client feature: a server asks the user for input, now delivered through `input_required` responses rather than a server-initiated request |
| Stateless core | The `initialize` handshake and session header are gone; every request carries its version and capabilities, and stateful servers return explicit handles the model passes back |
| Multi round-trip requests | A server answers `input_required` and the client retries with the answers; this replaces server-initiated sampling, elicitation and roots requests |
| Transports | `stdio` for local servers and Streamable HTTP for remote ones; HTTP+SSE is deprecated |
| Authorisation | OAuth 2.1. Servers publish Protected Resource Metadata (RFC 9728); clients send resource indicators (RFC 8707) and should use Client ID Metadata Documents, as Dynamic Client Registration is deprecated. Tokens must be issued for that server and never passed through |
| Deprecated | Roots, sampling and logging, with at least 12 months' notice |

Source: the [2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog) and [authorisation spec](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization). If you built against an earlier revision, plan a migration: the stateless change touches every server.

Official extensions add capabilities outside the core ([MCP](https://modelcontextprotocol.io/docs/extensions/overview)). **MCP Apps**, the first official extension (January 2026), lets a server return interactive UI rendered in a sandboxed iframe in Claude, ChatGPT, VS Code Copilot, M365 Copilot and goose ([MCP](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/)). **Tasks** handles long-running work. **Enterprise-Managed Authorization** lets the company's identity provider, such as Okta or Entra, issue the tokens for MCP servers, and it is the extension to raise first with an enterprise client ([MCP](https://modelcontextprotocol.io/extensions/auth/enterprise-managed-authorization)). The public MCP Registry is still in preview and lists metadata only, not private servers ([MCP](https://modelcontextprotocol.io/registry/about)).

**MCP security: the risks you must design for**

- **Prompt injection through tool results**: a web page, email or ticket returned by a tool can contain instructions the model follows. Treat every tool result as untrusted data.
- **Tool poisoning, rug pulls and shadowing**: a malicious server hides instructions in tool descriptions, changes them after approval, or interferes with another server's tools ([Invariant Labs](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks)). Pin tool definitions by hash; Anthropic's MCP connector now has a beta option that pins the tool list for a whole conversation ([Anthropic](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector)).
- **The "lethal trifecta"** (Simon Willison's term): private data, untrusted content and an outbound channel in one session can be turned into exfiltration. Remove at least one of the three for any given agent ([MCP](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/)).
- **Annotations are hints, not controls**: `readOnlyHint` and similar flags enforce nothing and must be treated as untrusted unless the server is trusted.
- **Confused deputy and token passthrough**: token passthrough is forbidden, and proxy servers must collect consent per client ([MCP security](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices)).
- **SSRF and local compromise**: block private IP ranges for servers that fetch URLs; show the full launch command and sandbox local servers.
- **Supply chain**: malicious MCP packages have shipped on npm, such as postmark-mcp in September 2025 ([Cloud Security Alliance](https://labs.cloudsecurityalliance.org/research-rb/csa-whitepaper-mcp-security-tool-poisoning-20260506-csa-styl/)). OWASP now maintains an MCP Top 10, currently in beta ([OWASP](https://owasp.org/www-project-mcp-top-10/)).

Mitigations that hold up: run only vetted servers from an internal allowlist, route remote MCP through a gateway that enforces auth, logging and rate limits, sandbox local servers, require approval for write tools, and log every tool call with its arguments. Real gateways include the open-source [Docker MCP Gateway](https://docs.docker.com/ai/mcp-gateway/), [Bedrock AgentCore Gateway](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway.html), [Cloudflare MCP Server Portals](https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/mcp-portals), [Kong's MCP plugins](https://developer.konghq.com/mcp/), [Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/mcp-server-overview) and [microsoft/mcp-gateway](https://github.com/microsoft/mcp-gateway) for Kubernetes.

**Scaling to many tools**

Loading every tool definition into every call wastes context and lowers tool-selection accuracy. Current techniques:

1. **Tool search**: load only the tool definitions the model asks for. Anthropic reported an 85% cut in tool-definition tokens and Opus 4 tool-selection accuracy rising from 49% to 74% ([Anthropic](https://www.anthropic.com/engineering/advanced-tool-use)). Claude's tool search handles up to 10,000 deferred tools, and OpenAI offers deferred loading with tool search too.
2. **Code execution over tools**: the model writes a short script in a sandbox that calls several tools and returns only the final result. Anthropic reported 37% fewer tokens for programmatic tool calling ([Anthropic](https://www.anthropic.com/engineering/advanced-tool-use)), and its code-execution-with-MCP example cut roughly 150,000 tokens to 2,000 ([Anthropic](https://www.anthropic.com/engineering/code-execution-with-mcp)). OpenAI and Cloudflare ("Code Mode") offer the same idea.
3. **Tool use examples**: one to five example calls per tool raised accuracy on complex parameters from 72% to 90% in Anthropic's tests.
4. **Skills**: folders with a `SKILL.md` (a name and a description in frontmatter, then instructions) plus scripts and resources, loaded only when relevant. Anthropic published the format as an open standard in December 2025 ([agentskills.io](https://agentskills.io/specification)), and OpenAI Codex and API, GitHub Copilot and VS Code, Gemini CLI and Claude all support it.
5. **Sub-agents with small toolsets**: give each specialist only the tools for its job.

**Sandboxes for code and computer use**

Code execution, shell access and browser control should always run in an isolated sandbox, never on the host. Hosted options include E2B, Daytona, Modal, Vercel Sandbox and Cloudflare Sandbox, plus the provider-hosted code-execution tools. Computer-use tools still need a VM or browser sandbox that you run, such as a cloud browser service or a locked-down container; the OpenAI Agents SDK's sandbox agents plug into several of these providers. Give sandboxes no network access by default, no production credentials, and a time and resource limit.
