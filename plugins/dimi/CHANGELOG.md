# Changelog

## 1.1.0 - 2026-10-24

- New skill `grill-me`: stress-test a plan, spec, ticket or design in conversation, one question at a time with a recommended answer each, depth-first through the problem, shape, identity, idempotency, scale, failure, trust, settings, proof, consumer and sequence branches. Reads `CLAUDE.md`, `.claude/rules/` and `.claude/fde-client-profile.md` before asking, delegates code reading to `explore`, and hands off to `plan-from-ticket` or `agent-bootstrap`. Forked from mattpocock/skills (`grilling` + `grill-me`).

## 1.0.0 - 2026-10-24

First release of the unified `dimi` plugin (merges the former dev-workflow and fde-toolkit plugins into one).

**Development loop**
- Skills: `plan-from-ticket`, `ui-states-review`, `tidy` (remove working notes before handover), `pr-self-review` (loads `pr-correctness-scalability-review` and `pr-security-data-review` as stages; calls `review-agent`/`harden-mcp` for agent and MCP code), `commit-push-pr`, `address-review`, `compound`, `agent-tool-design`, `agent-bootstrap`.
- Agents: `explore` (haiku, read-only), `reviewer` (opus, read-only, preloads both checklists), `verifier`, `spec-writer`, `implementer` (worktree-isolated).
- Hooks: format on edit; Stop gate (debug leftovers by file class, per-package typecheck with a time budget, Python lint); Bash guard (force push, protected and default branches, `--no-verify`, sweeping `git add`, commit without ticket key); session banner on startup/resume/clear/compact. Portable across GNU coreutils and stock macOS.
- Options via `userConfig`: ticket regex, default branch, protected branches, typecheck script/fallback/budget, Python lint command and path regex, local checks line, eslint-on-edit toggle.

**Agent engineering**
- `harness-reference`: background knowledge from *The Agentic Harness: A Layer-by-Layer Guide* (facts as of 24 October 2026), split into topic files.
- `review-agent`: forked, read-only production-readiness review with a 57-check rubric, report template and tested fix patterns.
- `harden-mcp`: forked, read-only MCP server review against the 2026-07-28 spec revision (43 checks), with tested auth, SSRF and path-confinement patterns.
- `client-profile`: creates `.claude/fde-client-profile.md`, which the other skills read.
- `refresh-harness`: manual workflow to re-verify dated facts and prepare a pull request.

Every skill honours `.claude/fde-client-profile.md` when present.
