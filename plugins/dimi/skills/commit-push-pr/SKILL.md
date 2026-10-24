---
name: commit-push-pr
description: Commit the current work in the repo's ticket-key format with explicit paths, push the branch, and open or update a draft PR whose description comes from the diff and the latest self-review. Manual only; never force-pushes.
argument-hint: "[headline] [--ready] [--watch-ci] [--skip-checks]"
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(ruff *), Bash(pytest *), Read, Grep, Glob
---

# Commit, push, PR

The end-of-work command you run dozens of times a week. Pre-computes repo state with inline bash so no turn is spent asking. Arguments: `$ARGUMENTS` may contain a commit headline override and/or `--ready` to open a non-draft PR. Default is a draft.

## Current state (pre-computed)

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo"`
- Default branch: !`DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); echo "${DB:-main}"`
- Default branch tip: !`DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; git fetch -q origin "$DB" 2>/dev/null; git rev-parse --short "origin/$DB" 2>/dev/null || echo "unknown"`
- Ahead / behind default branch: !`DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); git rev-list --left-right --count "origin/${DB:-main}...HEAD" 2>/dev/null || echo "unknown"`
- Files main changed since the branch point that this change also touches (rebase risk): !`DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; B=$(git merge-base "origin/$DB" HEAD 2>/dev/null); X=$(comm -12 <(git diff --name-only "$B..origin/$DB" 2>/dev/null | sort) <({ git diff --name-only $B 2>/dev/null; git ls-files --others --exclude-standard; } | sort -u)); echo "${X:-none}"`
- Repo git hooks present: !`H=$( { ls .husky 2>/dev/null | tr '\n' ' '; [ -f .pre-commit-config.yaml ] && echo pre-commit; git config core.hooksPath 2>/dev/null; } | tr '\n' ' '); echo "${H:-none}"`
- Status: !`git status --short 2>/dev/null || echo "n/a"`
- Untracked (not ignored): !`git ls-files --others --exclude-standard 2>/dev/null || echo "n/a"`
- Recent commits: !`git log --oneline -5 2>/dev/null || echo "n/a"`
- Existing PR: !`gh pr view --json number,url,isDraft,title,baseRefName 2>/dev/null || echo none`
- Latest self-review report: !`ls -t ../self-review-*/self-review-*.md 2>/dev/null | head -1; true`

## Steps

1. **Ticket key** from the branch name using the ticket regex from the plugin option `ticket_regex` (see the `pr-self-review` policy block). No key → stop and ask; the Bash guard will refuse the commit anyway.

2. **Refuse to proceed** if any of these hold, and say which:
   - behind the default branch **and** the overlap list above is not empty → stop; suggest `git rebase origin/<default>`, then re-run the local checks, then this command. Behind with no overlap is a warning in the report, not a refusal (team policy decides whether to rebase anyway);
   - untracked files that look like they are not part of the change (`.env*`, dumps, exports, review reports, evidence for other specs) → ask which to include; never stage them by default;
   - a secret-looking string in the diff (`grep -nE '(secret|password|token|api[_-]?key)' `) → stop;
   - a customer or person name, or session narrative, in an added comment, docstring, log string or test name (see `/dimi:tidy` §1 greps) → stop and run `/dimi:tidy` first; a plain ticket key inside a comment is a warning (ticket context belongs in the commit message);
   - the latest self-review report for this branch has open Blockers → stop and list them.

3. **Checks**: run the repo's lint and typecheck for the touched packages unless `--skip-checks` is in `$ARGUMENTS`. A failure stops the command; do not commit over it. The repo's own git hooks (husky, pre-commit, lint-staged, commit-msg) run untouched on commit and push: never pass `--no-verify`, and if a hook fails, fix the cause and re-run — do not retry with the hook disabled.

4. **Commits**: propose the split (one logical change per commit; refactor before behaviour; UI after the API it needs). For each commit:
   - stage **explicit paths** (`git add path/one path/two`) — never `-A`, `.` or `-u`;
   - message `type(KEY): description` in the imperative, under 72 characters, with a body of two to five lines on the *why* and anything a reviewer should look at first;
   - show the planned commits and wait for a yes before running them.

5. **Push**: `git push -u origin <branch>`. Never `--force` or `--force-with-lease`; if the push is rejected, stop and explain.

6. **PR**:
   - If no PR exists: `gh pr create --draft --base <default branch> --title "type(KEY): <headline>" --body-file <tmp>` (drop `--draft` only when `--ready` was passed). Base is the default branch unless the branch is stacked on another PR branch, in which case ask.
   - If a PR exists: update the body with `gh pr edit <n> --body-file <tmp>`; do not change its title unless asked.
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

8. **Report** in five lines: commits made, branch pushed, PR URL and draft state, checks run locally, CI status if watched, anything refused or warned (e.g. behind main without overlap).

Never post review comments, never approve, never merge. Those are the team's.
