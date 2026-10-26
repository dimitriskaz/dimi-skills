---
name: commit-push-pr
description: Commit the current work in the repo's ticket-key format with explicit paths, push the branch, and open or update a draft PR whose description comes from the diff and the latest self-review. Manual only; never force-pushes.
argument-hint: "[headline] [--ready] [--watch-ci] [--skip-checks] [--base <branch>]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(git *), Bash(gh *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(ruff *), Bash(pytest *), Bash(grep *), Bash(ls *), Bash(comm *), Bash(cat *), Read, Grep, Glob
---

# Commit, push, PR

The end-of-work command you run dozens of times a week. Pre-computes repo state with one state script so no turn is spent asking. Arguments: `$ARGUMENTS` may contain a commit headline override and any of the flags `--ready` (open a non-draft PR; the default is a draft), `--watch-ci` (babysit the checks after the push), `--skip-checks` (skip the local lint/typecheck in step 3) and `--base <branch>` (PR base other than the default branch, e.g. the PR branch this work is stacked on; the author passes it when a `/dimi:port` run chose a stacked base).

## Current state (pre-computed)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/commit-push-pr.sh '${user_config.default_branch}' '${user_config.ticket_regex}' '${user_config.demo_branch}' '${user_config.demo_marker}' '${user_config.protected_branches}'`

The "Latest self-review report" is the one the `LATEST` pointer names (defined in `pr-self-review/references/diff-and-policy.md` §3, written by `pr-self-review`); secret-looking lines use `SECRET_RE` from `scripts/lib.sh`, with tokens masked.

## Steps

1. **State sanity, then ticket key**: if any pre-computed line says `unknown default branch` or `not a git repo`, stop and tell the author (fetch origin, or fix the `default_branch` option); nothing below can be trusted until it is fixed. If "On default/protected branch" says `YES`, stop: work is committed on a feature branch (`git switch -c <branch named with the ticket key>` carries the uncommitted changes across), never pushed to the default or a protected branch. Then the pre-computed "Ticket key" line (`${user_config.ticket_regex}`, default `[A-Z][A-Z0-9]+-[0-9]+`; the value `none` disables the check). `NONE` → stop and ask; the Bash guard will refuse the commit anyway. Disabled → commit as `type: description` and say so.

2. **Refuse to proceed** if any of these hold, and say which:
   - the "On the demo branch" line says `YES` → stop: demo work is pushed with `/dimi:poc push` (no PR, light gate); production work starts from the default branch via `/dimi:port`;
   - the "Demo-marker hits" line is not `none` → stop; `/dimi:port` classifies and drops those hunks;
   - `behind` on the "Behind / ahead" line is above 0 **and** the overlap list above is not `none` → stop; suggest `git rebase origin/<default>` only while the branch is unpushed (a rebased pushed branch needs a force-push, which the Bash guard blocks), otherwise `git merge origin/<default>`; then re-run the local checks, then this command. Behind with no overlap is a warning in the report, not a refusal (team policy decides whether to rebase anyway);
   - untracked files that look like they are not part of the change (`.env*`, dumps, exports, review reports, evidence for other specs, `.claude/.cache/`, Playwright auth state matching `storageState|\.auth/`) → ask which to include; never stage them by default;
   - the "Secret-looking lines" line is not `none` → stop and show the hits for a decision (values are redacted above; read the cited line in the file): a real secret is removed, and rotated if it was ever committed, before anything is committed; a false positive (a variable named `token`, a `password` form field) is noted in the report and the command continues;
   - a customer or person name, or session narrative, in an added comment, docstring, log string or test name (the "Working notes in added comments" line above; check the repo's customer terms from `CLAUDE.md`/`AGENTS.md` against the added lines yourself) → stop; ask the author to run `/dimi:tidy`, or follow that file's §1–4 inline, first; a plain ticket key inside a comment is a warning (ticket context belongs in the commit message);
   - the latest self-review report (the "Latest self-review report" line) has the verdict `Not ready` or `Request changes` (PR mode's word for it) or lists open Blockers → stop and list them. Its "for this branch" says `NO` → it reviews another branch: treat it as no report. Its "reviewed tree" says `CHANGED` → warn that the edits since were not self-reviewed, and offer `/dimi:pr-self-review` before pushing (`not recorded` → the same warning, softer). No report → warn in the final report that no self-review ran; do not refuse.

3. **Checks**: run the repo's lint and typecheck for the touched packages unless `--skip-checks` is in `$ARGUMENTS`. A failure stops the command; do not commit over it. The repo's own git hooks (husky, pre-commit, lint-staged, commit-msg) run untouched on commit and push: never pass `--no-verify`, and if a hook fails, fix the cause and re-run — do not retry with the hook disabled.

4. **Commits**: propose the split (one logical change per commit; refactor before behaviour; UI after the API it needs). For each commit:
   - stage **explicit paths** (`git add path/one path/two`) — never `-A`, `.` or `-u`;
   - message `type(KEY): description` in the imperative, under 72 characters, with a body of two to five lines on the *why* and anything a reviewer should look at first;
   - show the planned commits and wait for a yes before running them. The `allowed-tools` grant lasts only the turn that invoked this skill, so after the yes the `git commit` / `git push` commands may prompt for permission; that is expected — never work around it.

5. **Push**: `git push -u origin <branch>`. Never `--force` or `--force-with-lease`; if the push is rejected, stop and explain.

6. **PR**:
   - If no PR exists: `gh pr create --draft --base <base> --title "type(KEY): <headline>" --body-file <tmp>` (drop `--draft` only when `--ready` was passed). `<base>` is `--base <branch>` from `$ARGUMENTS` when the author passed it (a stacked PR, e.g. the base a `/dimi:port` run chose: say "stacked on #n; retarget to the default branch after it merges" in the body), else the default branch; if the branch looks stacked and no `--base` was passed, ask. Never the demo branch, whichever way it was named → refuse.
   - If a PR exists: read its body first (`gh pr view <n> --json body -q .body`). Teammates and bots fill sections too: keep every section and line you did not write (template checkboxes, reviewer notes, links), and replace only the sections below with fresh content. Show the existing body and the new one (or a diff of the two) and wait for a yes; only then `gh pr edit <n> --body-file <tmp>`. Do not change its title unless asked.
   - Body template (fill from the diff and, if present, the handover note in the self-review report):
     ```
     ## What
     <two or three sentences: the user-visible change and the approach>
     ## Why
     <the ticket's problem in one or two sentences; link the ticket>
     ## How it was tested
     <local checks run and results; specs run (N of M, local vs CI); what CI will add>
     ## Reviewer notes
     <where to look first; product decisions to confirm (defaults, visibility); known limitations>
     ## Deferred
     <findings knowingly left, each with a ticket reference>
     ```
   - Add the PR template's own sections if the repo has one (`.github/PULL_REQUEST_TEMPLATE*`); do not delete anything the template requires.

7. **CI** (optional): with `--watch-ci` in `$ARGUMENTS`, run `gh pr checks <n> --watch --fail-fast` (give it up to 20 minutes) and report each check as pass / fail / skipped, noting what a skipped job implies (a skipped web build means no browser e2e ran). On a failure, show the failing job's last 40 lines (`gh run view <id> --log-failed`) and stop; fixing is a separate step. Without the flag, end with the one-liner to babysit it instead: `/loop 10m check CI on PR #<n> and fix failures`.

8. **Report** in five lines: commits made, branch pushed, PR URL and draft state, checks run locally, CI status if watched, anything refused or warned (e.g. behind the default branch without overlap, no self-review report, a report for an older HEAD).

Never post review comments, never approve, never merge. Those are the team's.
