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
| poc | `/dimi:poc init\|mark\|sync\|push\|ledger\|status` | **yes** | Keep a long-lived demo branch honest: mark shortcuts, ledger, merge main in, push |
| port | `/dimi:port <feature>` | **yes** | Bring a feature from the demo branch to the default branch properly |

Order: plan-from-ticket → (grill-me) → build → ui-states-review → tidy → pr-self-review → commit-push-pr → address-review → compound. `debug` whenever something is red.

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

## Also in the plugin

- **Hooks** run on their own: format on edit, a Bash guard against pushes to protected branches and `git add -A`, a Stop gate (typecheck, lint, debug leftovers), a session banner and a where-I-stopped note.
- **Agents** Claude can delegate to: `explore`, `reviewer`, `verifier`, `spec-writer`, `implementer`, `debugger`.
- **Options**: `/plugin` → dimi → Configure options (ticket regex, default branch, checks).
