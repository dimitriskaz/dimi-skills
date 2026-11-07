---
name: help
description: The full catalogue of dimi skills, including the manual-only ones Claude cannot see in its own skill list. Use when the user asks how to use the dimi plugin, what dimi can do, which dimi command fits a task, or whether dimi has a skill for something ("is there a skill for addressing review comments", "how do I commit with dimi", "what's in the dimi plugin").
when_to_use: "Triggers: /dimi:help, \"how do I use dimi\", \"what can the dimi plugin do\", \"does dimi have a skill for…\", \"which dimi command should I use\". Read it before telling the user dimi has no skill for a task."
argument-hint: "[task or question, or nothing = the whole catalogue]"
---

# dimi catalogue

Half of dimi's skills are **manual-only** (`disable-model-invocation: true`) because they commit, push, write files or change rules. Claude Code leaves those skills out of the model's skill list, so they never show up when Claude checks what it has. This file is the complete list. **Never tell the user dimi has no skill for a task without checking the table below.**

When the user's request matches a manual-only skill, do not improvise the workflow. Name the command, say what it will do in one line, and ask them to type it (you cannot run it yourself). If they would rather you do it without the skill, do that.

If an argument was given, answer it: name the one or two skills that fit and the exact command. With no argument, show the catalogue grouped as below, trimmed to what the user is likely to use. Explain the terms a newcomer might not know.

## Development loop

| Skill | Command | Manual-only | Use when |
| --- | --- | --- | --- |
| grill-me | `/dimi:grill-me [plan]` | no | Pressure-test a plan, design or idea one question at a time |
| plan-from-ticket | `/dimi:plan-from-ticket <ticket>` | no | Turn a ticket into a plan before coding: touchpoints, data model, failure modes, tests, commit breakdown |
| ui-states-review | `/dimi:ui-states-review [paths]` | no | Check a UI change for every state (loading, empty, error, denied, partial), tokens, keyboard, specs needed |
| agent-ui-review | `/dimi:agent-ui-review [paths]` | no | Check a chat, copilot or agent screen: streaming and disconnects, tool calls in flight, approval gates, budget limits, citations, audit trail and undo, safe rendering of model output |
| tidy | `/dimi:tidy [paths]` | **yes** | Remove working notes, ticket references, commented-out code and debug leftovers before handover |
| pr-self-review | `/dimi:pr-self-review [#pr]` | no | Full review of the working tree or a PR before committing; report plus commit and PR drafts |
| pr-correctness-scalability-review | `/dimi:pr-correctness-scalability-review` | no | Stage 2 of the self-review on its own |
| pr-security-data-review | `/dimi:pr-security-data-review` | no | Stage 3 of the self-review on its own |
| commit-push-pr | `/dimi:commit-push-pr [headline] [--ready]` | **yes** | Commit with explicit paths in the ticket format, push, open or update a draft PR |
| address-review | `/dimi:address-review [#pr or pasted comments]` | **yes** | Work through a colleague's review: verify each comment against the code, fix by root cause, push back with evidence, draft replies to paste |
| compound | `/dimi:compound [#pr]` | **yes** | Turn review findings and corrections into `.claude/rules/`, hooks or skills |
| debug | `/dimi:debug <symptom>` | no | Find a bug's root cause: failing test first, one hypothesis at a time |
| walkthrough | `/dimi:walkthrough <module or flow>` | no | Explain part of the system end to end with code references and a diagram |
| release-notes | `/dimi:release-notes [range] [--docs]` | **yes** | Release notes from merged work, with screenshots; `--docs` for illustrated product docs |
| report | `/dimi:report [ticket, path, range or #pr]` | no | One self-contained HTML report about a ticket, codebase, review, investigation or release: verdict, what changed, how it works, evidence, findings, risks; reads offline, light and dark, prints to PDF |
| build-report | `/dimi:build-report [what the reader must decide]` | **yes** | Build a dashboard, reports page, scheduled report or BI definition inside the codebase, in its own stack: questions first, one tested metric registry, rollups that hold at real scale, charts by question, every widget state, exports from the same definitions |
| poc | `/dimi:poc init\|mark\|sync\|push\|ledger\|status` | **yes** | Keep a long-lived demo branch honest: mark shortcuts, ledger, merge main in, push |
| port | `/dimi:port <feature>` | **yes** | Bring a feature from the demo branch to the default branch properly |

Order: plan-from-ticket → (grill-me) → build → ui-states-review (agent-ui-review too for chat or agent screens) → tidy → pr-self-review → commit-push-pr → address-review → compound. `debug` whenever something is red.

## Building LLM agents

| Skill | Command | Manual-only | Use when |
| --- | --- | --- | --- |
| agent-bootstrap | `/dimi:agent-bootstrap [what it does]` | **yes** | Start an agent project: current docs, framework choice, scaffold with tracing, budgets, evals |
| agent-tool-design | `/dimi:agent-tool-design [tool]` | **yes** | Design or review a tool a model can call |
| agent-evals | `/dimi:agent-evals [agent]` | **yes** | Build or extend the eval harness for an agent or LLM feature |
| review-agent | `/dimi:review-agent [path]` | no | Production-readiness review of an agent codebase |
| harden-mcp | `/dimi:harden-mcp [path]` | no | Security and spec-compliance review of an MCP server |
| harness-reference | (automatic) | n/a | Background knowledge Claude loads itself; not a command |
| client-profile | `/dimi:client-profile [client]` | **yes** | Create the engagement profile the other skills read |
| refresh-harness | `/dimi:refresh-harness [area]` | **yes** | Update the plugin's dated facts; only from a checkout of dimi-skills |

## Recommended marketplaces (third party, not part of dimi)

When the user asks for one of these, or asks what else to install, give the exact commands; dimi does not contain them and cannot run them.

| Plugin | Commands | What it is | Entry command after install |
| --- | --- | --- | --- |
| ponytail | `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` | The least code that works: a ladder (exists already, standard library, platform, installed dependency, one line, minimum), a never-cut list, `shortcut:` markers with a debt ledger, a diff review that reads around the diff | `/ponytail full`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt` |
| pstack | `/plugin marketplace add cursor/plugins` then `/plugin install pstack@cursor-plugins` | Goal in, playbook out, with evidence; named principles to steer with ("apply subtract before you add"); decision log and overnight contract for unattended runs; `unslop`, `no-comments`, `tdd`, benchmark checklist | `/pstack:poteto-mode <goal and done check>`, `/pstack:poteto-help` |
| cursor-team-kit | not in Cursor's Claude Code marketplace: copy `cursor-team-kit/skills/thermo-nuclear-code-quality-review/` from `cursor/plugins` into `~/.claude/skills/`, or declare the inline marketplace shown in the dimi-skills README and `/plugin install cursor-team-kit@cursor-team-kit` | A very strict maintainability review (structure, branching, 1,000-line files, wrappers, casts, layers) plus `deslop`, `verify-this`, `fix-ci`, `loop-on-ci`, `review-and-ship`, `what-did-i-get-done`, `weekly-review` | `/thermo-nuclear-code-quality-review` (skills dir) or `/cursor-team-kit:thermo-nuclear-code-quality-review` |

Overlaps: ponytail's review and pstack's playbooks parallel `pr-self-review` and the dimi loop; suggest one per task. The thermo-nuclear review covers structure, which `pr-self-review` does not, so it runs well after it.

## Also in the plugin

- **Hooks** run on their own: format on edit, a Bash guard against pushes to protected branches, `git add -A`, staging secret or state files, and commands that would discard uncommitted work (`reset --hard`, `checkout --` of edited files, `clean -f`, `stash drop`, `rm` of edited or untracked files), a Stop gate (typecheck, lint, debug leftovers), a session banner and a where-I-stopped note.
- **Agents** Claude can delegate to: `explore`, `reviewer`, `verifier`, `spec-writer`, `implementer`, `debugger`.
- **Options**: `/plugin` → dimi → Configure options (ticket regex, default branch, checks).
