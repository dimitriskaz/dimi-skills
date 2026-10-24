# dimi

One plugin, two halves that compose: the **development loop** a good reviewer would make you follow, and **agent engineering** know-how for building LLM agents. Repo-agnostic: repository facts come from `CLAUDE.md`/`AGENTS.md`, the plugin options and the per-repo starter in `templates/project-claude/`; client facts come from `.claude/fde-client-profile.md`.

```
/plugin install dimi --marketplace dimitriskaz/dimi-skills      # Claude Code 2.1.275+; or: marketplace add, then /plugin install dimi@dimi-skills
```

## Development loop

| Skill | Invoke | When |
| --- | --- | --- |
| plan-from-ticket | `/dimi:plan-from-ticket <KEY>` | Before coding: touchpoints, identity keys, run-it-twice, scale, failure modes, threat model, tests that fail without the change, commit plan |
| ui-states-review | `/dimi:ui-states-review` | Before committing UI: state matrix (unread ≠ empty, partial success, 409/403), forms, truthfulness, tokens, keyboard, specs needed |
| tidy | `/dimi:tidy` | Before the self-review: remove session narrative, ticket/customer references, what-comments, commented-out code, placeholder docstrings and scratch files from the change; keep why-comments; prove the diff is comment-only |
| pr-self-review | `/dimi:pr-self-review` | Before commit/push: compliance gate, both checklists, local checks, report, commit + PR drafts. Proportional to diff size; calls `review-agent`/`harden-mcp` for agent and MCP code |
| pr-correctness-scalability-review | alone or via pr-self-review | Eleven lenses: pairs, run-it-twice, caps, scale, failure modes, claims vs code, copies, data semantics, tests, frontend, agent/LLM code |
| pr-security-data-review | alone or via pr-self-review | Tenant isolation, authz bypass, validation, injection, SSRF, secrets, PII, customer data, defaults, LLM/agent code, dependencies |
| commit-push-pr | `/dimi:commit-push-pr [headline] [--ready] [--watch-ci] [--skip-checks]` | Rebase check, local checks, explicit-path commits in ticket format, push, draft PR with drafted body |
| address-review | `/dimi:address-review` + pasted comments | Verify each point against the code, fix by root cause, re-validate, draft replies |
| compound | `/dimi:compound` | Turn findings and corrections into `.claude/rules/` (path-scoped), hooks or skills |
| agent-tool-design | `/dimi:agent-tool-design` | Contract and safety for a tool a model can call; writes as human-accepted proposals; side-effect discipline |
| agent-bootstrap | `/dimi:agent-bootstrap` | Start an agent project: current docs first, constraint-led framework choice, scaffold with budgets, tracing, evals, HITL, ADR |

| Agent | Model | Edits? | Isolated? | Use when |
| --- | --- | --- | --- | --- |
| explore | haiku | no | no | searches and call tracing — keeps file dumps out of your context |
| reviewer | opus | no | no | fresh-context review of the working tree; preloads both checklists |
| verifier | sonnet | no | no | runs scoped checks one at a time and returns an evidence table |
| spec-writer | sonnet | e2e only | no | browser specs + evidence in the repo's style |
| implementer | opus | yes | worktree | one independent unit of work, start to commit |

Hooks run in every session where the plugin is enabled: `scripts/format-file.sh` (PostToolUse Edit|Write), `scripts/stop-check.sh` (Stop), `scripts/guard-bash.sh` (PreToolUse Bash), `scripts/session-context.sh` (SessionStart startup|resume|clear|compact). Configure them in `/plugin` → dimi → **Configure options**; they also read `STOP_*`/`GUARD_*`/`HOOK_*` env vars as fallbacks. `jq` required. Portable across GNU coreutils and stock macOS.

The loop: plan-from-ticket → build → ui-states-review → tidy → pr-self-review → commit-push-pr → address-review → compound. Full explanation in [`docs/guide.md`](../../docs/guide.md).

## Agent engineering

| Skill | Invoke | Who triggers it | What it does |
| --- | --- | --- | --- |
| harness-reference | (automatic) | Claude, when working on agent code | Background knowledge: orchestration, frameworks, tools and MCP, RAG, observability, security and delivery practice, split into topic files |
| review-agent | `/dimi:review-agent [path]` | You or Claude | Read-only production-readiness review in a forked subagent; prioritised report with evidence and fixes |
| harden-mcp | `/dimi:harden-mcp [path]` | You or Claude | Read-only MCP server review against the 2026-07-28 spec; prioritised report |
| client-profile | `/dimi:client-profile [client]` | You only | Creates `.claude/fde-client-profile.md`, which the other skills read |
| refresh-harness | `/dimi:refresh-harness [area]` | You only | Re-verifies dated facts against official sources and prepares a pull request; run from a checkout of dimi-skills |

Principles and decisions live in `skills/harness-reference/references/` and change slowly. Rubrics, checklists and tested code patterns live in each review skill's `references/`. API specifics are never stored: the skills confirm them against current docs at run time. Dated facts carry an "as of" note; run `/dimi:refresh-harness` every month or two.

## Notes

- The `reviewer` agent's `skills:` preload names the two checklist skills by bare name; if your Claude Code version requires the namespaced form, change it to `dimi:pr-correctness-scalability-review, dimi:pr-security-data-review`.
- `isolation: worktree` branches from the default branch, so `implementer` cannot see uncommitted work.
- See [CHANGELOG.md](CHANGELOG.md) for releases.
