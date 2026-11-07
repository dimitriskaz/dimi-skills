# dimi

One plugin, two halves that compose: the **development loop** a good reviewer would make you follow, and **agent engineering** know-how for building LLM agents. Repo-agnostic: repository facts come from `CLAUDE.md`/`AGENTS.md`, the plugin options and the per-repo starter in `templates/project-claude/`; client facts come from `.claude/fde-client-profile.md`.

```
/plugin install dimi --marketplace dimitriskaz/dimi-skills      # Claude Code 2.1.275+; or: marketplace add, then /plugin install dimi@dimi-skills
```

Not sure which skill fits? `/dimi:help [task]`. It is also how Claude finds the manual-only skills, which Claude Code leaves out of the model's skill list.

## Development loop

| Skill | Invoke | When |
| --- | --- | --- |
| grill-me | `/dimi:grill-me [plan]` | Before building: one question at a time until every decision and dependency is resolved; recommends an answer each time; depth-first |
| plan-from-ticket | `/dimi:plan-from-ticket <KEY>` | Before coding: touchpoints, identity keys, run-it-twice, scale, failure modes, threat model, tests that fail without the change, commit plan |
| ui-states-review | `/dimi:ui-states-review` | Before committing UI: state matrix (unread ≠ empty, partial success, 409/403), forms, truthfulness, tokens, keyboard, specs needed |
| agent-ui-review | `/dimi:agent-ui-review` | Before committing a chat, copilot or agent screen: stream states (stalled, stopped, dropped mid-answer), tool calls in flight, approval gates bound to the exact call, budget and context limits as named states, failed retrieval ≠ no results, citations, audit trail and undo, model output rendered as content |
| tidy | `/dimi:tidy` | Before the self-review: remove session narrative, ticket/customer references, what-comments, commented-out code, placeholder docstrings and scratch files from the change; keep why-comments; prove the diff is comment-only |
| pr-self-review | `/dimi:pr-self-review` | Before commit/push: compliance gate, the three checklists (correctness, structure, security), local checks, report, commit + PR drafts. Proportional to diff size; calls `review-agent`/`harden-mcp` for agent and MCP code, `ui-states-review` for frontend work and `agent-ui-review` for model-backed screens |
| pr-correctness-scalability-review | alone or via pr-self-review | Eleven lenses: pairs, run-it-twice, caps, scale, failure modes, claims vs code, copies, data semantics, tests, frontend, agent/LLM code |
| pr-security-data-review | alone or via pr-self-review | Tenant isolation, authz bypass, validation, injection, SSRF, secrets, PII, customer data, defaults, LLM/agent code, dependencies |
| pr-structure-review | alone or via pr-self-review (stage 2b) | Maintainability: a reframing that would delete a class of complexity, conditionals bolted onto unrelated flows, logic in the wrong layer, pass-through wrappers, casts and optionality that hide the invariant, files past `max_file_lines`, functions mixing jobs, sequential async, non-atomic updates; `review.sh sizes` gives lines before and after per file |
| commit-push-pr | `/dimi:commit-push-pr [headline] [--ready] [--watch-ci] [--skip-checks] [--base <branch>]` | Rebase check, local checks, explicit-path commits in ticket format, push, draft PR with drafted body |
| address-review | `/dimi:address-review` + pasted comments | Verify each point against the code, fix by root cause, re-validate, draft replies |
| compound | `/dimi:compound` | Turn findings and corrections into `.claude/rules/` (path-scoped), hooks or skills |
| agent-tool-design | `/dimi:agent-tool-design` | Contract and safety for a tool a model can call; writes as human-accepted proposals; side-effect discipline |
| debug | `/dimi:debug <symptom>` | Something is red: capture with a done check, reproduce as a failing test, baseline, isolate, one hypothesis at a time with a log, fix the cause, prove it; a perf number is checked (limiter, same conditions, repeatable, errors, timed region, end to end) before it is reported; stops after two killed hypotheses |
| decision-log | `/dimi:decision-log start\|add\|read\|commit` | Long or unattended runs: the contract first (goal, a done check that can pass or fail, permissions, escape hatch), then one append-only TSV row per fork, verified unit, pivot, revert or blocker with an evidence pointer; `read` audits the rows and leads with what needs attention; kept outside git unless a reviewer needs it |
| agent-evals | `/dimi:agent-evals <agent>` | Golden tasks with expected tool sequences, deterministic asserts then a calibrated judge, repeated trials, replay mode in CI and budgeted live mode, injection fixtures |
| walkthrough | `/dimi:walkthrough <module>` | Explain a flow end to end for a newcomer, reviewer or client: the path, the data, invariants, where people trip, a diagram — verified by reading |
| release-notes | `/dimi:release-notes [range] [--docs] [--areas a,b] [--audience public\|internal]` | Public, enterprise-style product documentation generated from the running app: task pages per module and feature with a Playwright screenshot per step (clipped, the acted-on control outlined, personal data masked, dev and environment chrome removed, captured per role on a demo tenant), getting started, roles and permissions, settings, limits, troubleshooting built from the product's own messages, a glossary, public release notes per version, and a Word release document per release to send customers (steps and screenshots for every new feature, action required, settings, fixes; your company template through the `release_doc_template` option; built with pandoc outside the repo); the product's own labels from the screen and locale files; a publish gate (`docs-check.sh`) that fails any code, ticket, PR, commit, host or test reference in the published folder; an internal trace kept outside it; framework-aware (Docusaurus, MkDocs, Mintlify, Starlight, VitePress, Nextra, plain Markdown) |
| report | `/dimi:report [subject] [--kind …] [--audience …]` | One HTML page about a ticket, codebase, review, investigation or release, for a reviewer, newcomer, client or stakeholder: verdict first, what changed with scaled change bars, the path with `path:line`, a diagram, evidence, filterable findings, risks; built from git facts and the reports other skills wrote; opens from disk, light and dark, prints to PDF |
| build-report | `/dimi:build-report [question or KEY] [--surface screen\|job\|bi\|notebook] [--critique <route>]` | A reporting feature in the codebase's own stack, or a critique of an existing dashboard as a decision instrument: the question list and who decides what from it, one metric registry with a definition template and fixture tests, rollups or indexed bounded queries designed against the `SCALE` line with freshness and partial marks, tenant scoping and per-widget permission, chart by question with a table alternative, a KPI that shows its comparison and trend or is just a count, scan path and restrained colour, the operational status model (freshness, severity, owner, next action, suppression with audit), every widget state, filters in the URL, exports and scheduled jobs from the same definitions; reuses the chart library, blocks and tokens the repo already has |
| poc | `/dimi:poc init\|mark\|sync\|push\|ledger\|status` | Demo/POC branch hygiene: mark shortcuts, ledger of demo-only / owed / in-review / ported, merge main in (never rebase), push straight with a light gate, status with drift |
| port | `/dimi:port <feature> [--from demo] [--base …]` | Demo → production: real delta minus upstream and your open PRs, integration worktree of main + open PRs, reuse / rewrite / drop per hunk, base on main or stacked one level, then the normal loop |
| agent-bootstrap | `/dimi:agent-bootstrap` | Start an agent project: current docs first, constraint-led framework choice, scaffold with budgets, tracing, evals, HITL, ADR |

| Agent | Model | Edits? | Isolated? | Use when |
| --- | --- | --- | --- | --- |
| explore | haiku | no | no | searches and call tracing — keeps file dumps out of your context |
| reviewer | opus | no | no | fresh-context review of the working tree; preloads both checklists |
| verifier | sonnet | no | no | runs scoped checks one at a time and returns an evidence table |
| spec-writer | sonnet | e2e only | no | browser specs + evidence in the repo's style |
| implementer | opus | yes | worktree | one independent unit of work, start to commit |
| debugger | sonnet | yes | no | a long or noisy debugging session; runs the `debug` loop and returns root cause, fix and regression test |

Hooks run in every session where the plugin is enabled: `scripts/format-file.sh` (PostToolUse Edit|Write), `scripts/stop-check.sh` (Stop), `scripts/guard-bash.sh` (PreToolUse Bash), `scripts/session-context.sh` (SessionStart startup|resume|clear|compact|fork), `scripts/session-end-note.sh` (SessionEnd: a one-line where-I-stopped note the next banner reads back). Configure them (and `demo_branch` / `demo_marker` for the `poc`/`port` skills) in `/plugin` → dimi → **Configure options**; they also read `STOP_*`/`GUARD_*`/`HOOK_*` env vars as fallbacks. The hooks read JSON with `jq`, `python3` or `node`, whichever is on PATH first (with none of them they exit quietly and the banner says so). The Stop gate uses the package manager the repo uses (lockfile, then `packageManager`) and never blocks on a missing tool: it reports the skipped check once as a warning. `ticket_regex`, `typecheck_script` and `py_lint_cmd` accept `none` to disable. Skills read options through `${user_config.KEY}` substitution; the scripts read `CLAUDE_PLUGIN_OPTION_<KEY>`. Portable across GNU coreutils and stock macOS (bash 3.2, BSD tools, no GNU `timeout`/`sha1sum`): regexes are POSIX ERE only. Windows: the scripts run under Git Bash, which Claude Code uses there; `.gitattributes` keeps them LF so a `core.autocrlf` checkout cannot break them; Git for Windows has no `jq`, so the hooks need `python3`, `node` or `jq` on PATH. Windows is not yet tested end to end, notably plugin paths with spaces in the skills' state commands.

The loop: plan-from-ticket → (grill-me) → build → ui-states-review (and agent-ui-review for chat or agent screens) → tidy → pr-self-review → commit-push-pr → address-review → compound; `debug` whenever something is red; `decision-log` for any run nobody watches. Full explanation in [`docs/guide.md`](../../docs/guide.md).

## Agent engineering

| Skill | Invoke | Who triggers it | What it does |
| --- | --- | --- | --- |
| harness-reference | (automatic) | Claude, when working on agent code | Background knowledge: orchestration, frameworks, tools and MCP, RAG, observability, security and delivery practice, split into topic files |
| prose | (automatic) | Claude, when writing text people keep | House rules for PR bodies, commit bodies, release notes, reports, walkthroughs and review replies: one idea per sentence, the actor named, plain words, hedge once, no manufactured contrast, no model voice |
| review-agent | `/dimi:review-agent [path]` | You or Claude | Read-only production-readiness review in a forked subagent; prioritised report with evidence and fixes |
| harden-mcp | `/dimi:harden-mcp [path]` | You or Claude | Read-only MCP server review against the current spec revision named in its checklist; prioritised report |
| client-profile | `/dimi:client-profile [client]` | You only | Creates `.claude/fde-client-profile.md`, which the other skills read |
| refresh-harness | `/dimi:refresh-harness [area]` | You only | Re-verifies dated facts against official sources and prepares a pull request; run from a checkout of dimi-skills |

Principles and decisions live in `skills/harness-reference/references/` and change slowly. Rubrics, checklists and tested code patterns live in each review skill's `references/`. API specifics (names, versions, code fragments) are kept to what the patterns need, each under an "as of" note, and the skills confirm them against current docs at run time. Run `/dimi:refresh-harness` monthly, on the first working day.

## Notes

- The `reviewer` agent's `skills:` preload names the two checklist skills by bare name; if your Claude Code version requires the namespaced form, change it to `dimi:pr-correctness-scalability-review, dimi:pr-security-data-review`.
- `isolation: worktree` branches from the default branch, so `implementer` cannot see uncommitted work.
- See [CHANGELOG.md](CHANGELOG.md) for releases.
