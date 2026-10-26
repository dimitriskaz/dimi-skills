---
name: compound
description: Turn this change's review findings, corrections and surprises into durable rules in .claude/rules/ (path-scoped where possible), hooks for must-nevers, or skills for procedures — so the same mistake is never made twice. Run after pr-self-review or after a reviewer round, before merging.
argument-hint: "[pr number or branch]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Compound: make the next ticket cheaper than this one

The fourth step of the loop Plan → Work → Assess → **Compound**. Planning and assessing are already covered by `plan-from-ticket` and `pr-self-review`; this skill closes the loop by writing what was learned somewhere Claude will read it next time. Triggers: `/dimi:compound`, "capture the learnings", "make sure this doesn't happen again", after merging a PR that had review findings.

Rules are advisory context; they are the right home for *judgement* Claude should apply. Anything that must happen or must never happen goes to a hook or a permission rule instead. Keep that distinction or the rules directory becomes a second, ignored CLAUDE.md.

## 1. Collect the raw material

Gather, in this order, and list each item in one line:
1. **Findings from the latest self-review** for this branch (Blocker and Should-fix first). It is the one the checkout's `LATEST` pointer names (written by `pr-self-review`); its `Branch:` line must name this branch (or its PR), else it is another change's report. A reviewer worklist `review-worklist-<name>.md` (same name part as the report) from `address-review` may sit beside it. Find it, and the default branch to diff against, with:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh latest '${user_config.default_branch}'
   ```
   Use the printed values literally in later commands (each Bash call is a fresh shell).
2. **Reviewer comments on the PR**: `gh pr view --comments` and `gh api repos/{owner}/{repo}/pulls/<n>/comments` (inline review comments). Include anything the reviewer had to explain.
3. **Corrections the author made this session**: ask once — "What did you have to correct me on, or redo, while building this?" — and accept a short answer.
4. **Plan vs reality**: where the implementation diverged from the `plan-from-ticket` plan, and why.
5. **Surprises**: anything that cost more than ten minutes to discover (a convention, a command, a quirk of the data layer).

## 2. Triage every item into exactly one bucket

| Bucket | Test | Destination |
|---|---|---|
| **One-off** | Would not recur on a different ticket | Drop it |
| **Judgement** | Claude should *decide differently* next time in some area of the code | `.claude/rules/<topic>.md`, path-scoped |
| **Cross-cutting judgement** | Applies to every file | `.claude/rules/<topic>.md`, no `paths` (rare; costs context every session) |
| **Must-never / must-always** | A rule Claude has now broken twice, or the cost of one violation is high | A hook (repo-specific: a `hooks` entry in the repo's `.claude/settings.json`; generic: a change to the dimi plugin's `scripts/`) or `permissions.deny` — propose it; do not write a rule for it |
| **Procedure** | A multi-step thing you'd want done the same way again | Skill (`.claude/skills/<name>/SKILL.md`) |
| **Repo fact** | A command, a path, a convention Claude can't infer | The repo's `CLAUDE.md`/`AGENTS.md` (Commands section, or the *repo* values the Repo policy block in `${CLAUDE_PLUGIN_ROOT}/skills/pr-self-review/references/diff-and-policy.md` §4 is resolved from at run time) or `.claude/rules/`; never edit the plugin's copy |
| **Engagement constraint** | A client/business rule: approved models, regions, risk tier for an action class, retention | `.claude/fde-client-profile.md` (via `/dimi:client-profile`), never a rule |

Be stingy. A rule nobody needed is context tax forever. If in doubt, drop it and see whether it recurs.

## 3. Write rules well

**File per topic**, named for the topic, not the incident: `data-reads.md`, `ui-states.md`, `connectors.md`, `imports.md`. Grep existing rules first (`grep -rn "<keyword>" .claude/rules/`) and **merge into an existing file** rather than adding a sibling; rewrite a rule rather than appending a second one about the same thing.

**Scope by path** to where the mistake happened, as narrowly as still useful:
```markdown
---
paths:
  - "services/**/*.ts"
  - "apps/*/src/**/*.{ts,tsx}"
---
```

**One rule = one line**, imperative, with the why in one clause and the shape of the mistake in one example:
```markdown
# Data reads

- Never read whole result history on a list/detail route or page load; it grows forever. Write a latest-per-key summary at collect time instead (e.g. latest result per key).
- Any read with a cap must either error past the cap or mark the numbers derived from it as partial. A banner with exact-looking numbers is wrong.
- Normalise ids (trim, case) with the same helper on store and on lookup. 'ABC-01 ' stored untrimmed is duplicated on every re-import.
```

**Budgets** (rules load into context): a path-scoped file stays under ~30 lines; the sum of unscoped rules stays under ~60 lines. When adding a rule would breach a budget, delete or merge one first. Suggest the author run `/context` or `/doctor` to see the rules' context cost.

**Prune on the way through**: for each existing rule in a file you touch, ask "would removing this cause a mistake today?" If Claude already behaves that way, delete it.

**Never** put non-rule content in `.claude/rules/` — every `.md` there is loaded. No README, no changelog (git history is the changelog), no examples longer than a line.

## 4. Escalate repeat offenders

If a finding appears in the self-review of two different branches **despite a rule**, the rule is not working. Write the hook instead (repo-level in `.claude/settings.json`, or propose a change to the plugin's `stop-check.sh` / `guard-bash.sh` if it is generic) and delete the rule. Say explicitly in the output that this escalation happened.

## 5. Output

- The diff of `.claude/rules/` (added, merged, deleted), each change tagged with the item that caused it.
- Hooks or skills proposed, with a one-line reason each, as separate follow-ups — do not write them silently.
- Items dropped as one-offs, in one line, so the author can object.
- Offer to commit as `chore(<KEY>): compound learnings from <PR or branch>`, staging explicit paths under `.claude/rules/` only — never `.claude/.cache/` (the hooks' cache dir) or anything matching `storageState|\.auth/`.

Two minutes at the end of every PR is the whole investment. Over a quarter it is the difference between a reviewer who keeps finding the same things and one who doesn't.
