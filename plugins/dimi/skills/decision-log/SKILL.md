---
name: decision-log
description: Keep an append-only decision log for long or unattended work (a cloud session, a /loop, an overnight run, a multi-hour migration) so the person who comes back can audit what was decided and why from the evidence, not from the transcript — one row per fork, verified unit, pivot, revert, blocker or fixed gate — and read it back in the morning with what needs attention first. Use when starting work nobody will watch, when asked "what did you decide and why", or to set the done condition and escape hatch before a long run.
when_to_use: "Triggers: /dimi:decision-log, \"log your decisions\", \"run this overnight\", \"keep going until done\", \"what did you decide last night\", \"show me your trail\", \"audit the run\"."
argument-hint: "[start <goal> | add | read | commit]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Decision log

A long run is only trustworthy if someone can check it afterwards without reading the whole transcript. The log is one TSV row per decision: when, which phase, what was decided, why, a pointer that proves it, and the result. It is append-only; a mistake is corrected by a new row that supersedes the old one, never by editing history.

## Before an unattended run: the contract

Do not start a run nobody will watch until these four are written at the top of the log (`start` row):
- **Goal** in one sentence.
- **Done check** that can pass or fail: "zero callers of the old parser", "every fixture passes", "the export has the same row count as the source". A duration is not a done check. A done check never relaxes to declare victory; if it cannot be met, the run stops and says why.
- **Permissions** already answered: what may be committed, pushed or deleted without asking (the Bash guard still holds).
- **Escape hatch**: when to stop (two killed hypotheses, as `debug` says; a check that cannot run; N hours), and what to leave behind (a checkpoint commit on the branch and a resume note).

## Logging

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/decision-log.sh start '<goal> · done: <check> · stop: <escape hatch>'
bash ${CLAUDE_PLUGIN_ROOT}/scripts/decision-log.sh add '<phase>' '<decision>' '<why>' '<evidence>' '<result>'
bash ${CLAUDE_PLUGIN_ROOT}/scripts/decision-log.sh read [n]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/decision-log.sh path
```
The script timestamps each row, strips tabs and newlines, and neutralises cells that would act as spreadsheet formulas. The file lives in the plugin's data directory for this repository (never in the working tree); `path` prints it.

Log a row at every point where a reader would ask "why did it go this way": a fork between approaches, a unit finished and verified, a pivot or a revert, a blocker, a gate fixed. In a loop, one row per iteration. Skip the obvious. Cells, in plain words:
- **phase**: the step of the plan or the loop iteration.
- **decision**: what was done or chosen, one line.
- **why**: the reason a teammate would accept.
- **evidence**: a pointer, never a paragraph: a commit, `path:line`, a test name, a report path, a number with its command.
- **result**: `green`, `reverted`, `blocked: <what>`, `inconclusive`, `open`.

Prefer evidence from a committed script or test over a one-off check; a reader can re-run the former.

## Reading it back (`read`)

Before handing back, or when the person returns: check every row of this run against what happened. A row with no real action behind it, evidence that does not resolve, or a fork that was taken and never logged gets a superseding row. Then summarise, leading with an **Attention** list: decisions waiting on the person, each with its evidence and its risk; blockers; anything reverted. Then the done check: met, or not met and why. Then the rows in order. "No flags" is a valid result and is stated as such.

## Keeping it

The log stays out of git by default. Commit it only when a reviewer needs the trail to trust the result: `commit` copies it to the repo's docs or evidence folder (the author names the place; the author commits).
