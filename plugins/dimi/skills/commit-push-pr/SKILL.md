---
name: commit-push-pr
description: Commit the current work in the repo's ticket-key format with explicit paths, push the branch, and open or update a draft PR whose description comes from the diff and the latest self-review. Manual only; never force-pushes.
argument-hint: "[headline] [--ready] [--watch-ci] [--skip-checks] [--base <branch>]"
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(pnpm *), Bash(npm *), Bash(yarn *), Bash(ruff *), Bash(pytest *), Bash(grep *), Bash(ls *), Bash(comm *), Bash(cat *), Read, Grep, Glob
---

# Commit, push, PR

The end-of-work command you run dozens of times a week. Pre-computes repo state with inline bash so no turn is spent asking. Arguments: `$ARGUMENTS` may contain a commit headline override and any of the flags `--ready` (open a non-draft PR; the default is a draft), `--watch-ci` (babysit the checks after the push), `--skip-checks` (skip the local lint/typecheck in step 3) and `--base <branch>` (PR base other than the default branch, e.g. the PR branch this work is stacked on; the author passes it when a `/dimi:port` run chose a stacked base).

## Current state (pre-computed)

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo"`
- Default branch (`${user_config.default_branch}`, else origin/HEAD, else main): !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; echo "$DB"; true`
- Ticket key in branch name (regex `${user_config.ticket_regex}`): !`TR='${user_config.ticket_regex}'; case "$TR" in ''|'$'*) TR='[A-Z][A-Z0-9]+-[0-9]+';; none|NONE) TR='';; esac; if [ -z "$TR" ]; then echo "ticket regex disabled (none)"; else git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -oE "$TR" | head -1 | grep . || echo "NONE — no ticket key in the branch name"; fi; true`
- On the demo branch (`${user_config.demo_branch}`, empty if not configured): !`DEMO='${user_config.demo_branch}'; case "$DEMO" in '$'*) DEMO='';; esac; B=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); if [ -z "$DEMO" ]; then echo "no demo branch configured"; elif [ "$B" = "$DEMO" ]; then echo "YES — HEAD is the demo branch $DEMO: refuse"; else echo "no ($DEMO)"; fi; true`
- Default branch tip: !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; if command -v timeout >/dev/null 2>&1; then timeout 10 git fetch -q origin "$DB"; else git fetch -q origin "$DB"; fi 2>/dev/null || true; git rev-parse --short "origin/$DB" 2>/dev/null || echo "unknown"`
- Ahead / behind default branch: !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; git rev-list --left-right --count "origin/$DB...HEAD" 2>/dev/null || echo "unknown"`
- Files the default branch changed since the branch point that this change also touches (rebase risk): !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); B=$(git merge-base "origin/$DB" HEAD 2>/dev/null) || { echo "unknown default branch (origin/$DB missing)"; exit 0; }; X=$( { git diff --name-only "$B..origin/$DB" 2>/dev/null | sort -u; { git diff --name-only "$B" 2>/dev/null; git -C "$TOP" ls-files --others --exclude-standard; } | sort -u; } | sort | uniq -d); echo "${X:-none}"; true`
- Demo-marker hits in the diff (`${user_config.demo_marker}(`, excluding `.claude/**`, `CLAUDE.md`, `AGENTS.md`): !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; M='${user_config.demo_marker}'; case "$M" in ''|'$'*) M=DEMO-ONLY;; esac; TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); B=$(git merge-base "origin/$DB" HEAD 2>/dev/null) || { echo "unknown default branch (origin/$DB missing)"; exit 0; }; H=$( { git diff "$B" -- ':(top)' ':(exclude,top).claude/**' ':(exclude,top)CLAUDE.md' ':(exclude,top)AGENTS.md' | grep -nE "^\+.*${M}\("; ( cd "$TOP" && git ls-files --others --exclude-standard | grep -vE '^(\.claude/|CLAUDE\.md$|AGENTS\.md$)' | while IFS= read -r f; do grep -nHE "${M}\(" "$f" 2>/dev/null; done ); } | head -20); echo "${H:-none}"; true`
- Secret-looking lines in the tracked diff and in untracked files (`SECRET_RE` from `pr-self-review/references/diff-and-policy.md` §4; values redacted, read the cited line yourself): !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}; TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); B=$(git merge-base "origin/$DB" HEAD 2>/dev/null) || { echo "unknown default branch (origin/$DB missing)"; exit 0; }; SECRET_RE='(-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? ?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|(api[_-]?key|secret|password|passwd|token|private[_-]?key)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_=-]{8,})'; H=$( { git diff "$B" 2>/dev/null | grep -niE "$SECRET_RE"; ( cd "$TOP" && git ls-files --others --exclude-standard | grep -vE '(^|/)\.env(\.|$)|\.(pem|key|p12)$|storageState|\.auth/|^\.claude/\.cache/' | while IFS= read -r f; do grep -niHE "$SECRET_RE" "$f" 2>/dev/null; done ); } | sed -E 's/^(([^:]*:)?[0-9]+:[^=:]*[=:][[:space:]]*).{4,}$/\1<redacted>/' | cut -c1-140 | head -20); echo "${H:-none}"; true`
- Untracked files that look like secrets or state (never staged): !`TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); git -C "$TOP" ls-files --others --exclude-standard 2>/dev/null | grep -iE '(^|/)\.env(\.|$)|(\.pem|\.key|\.p12|credentials|\.sqlite|\.dump|\.bak)$|storageState|\.auth/|^\.claude/\.cache/' || echo none`
- Repo git hooks present: !`H=$( { ls .husky 2>/dev/null | tr '\n' ' '; [ -f .pre-commit-config.yaml ] && echo pre-commit; git config core.hooksPath 2>/dev/null; } | tr '\n' ' '); echo "${H:-none}"; true`
- Status (paths from the top level): !`TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; git -C "$TOP" status --short 2>/dev/null || echo "n/a"`
- Untracked (not ignored, paths from the top level): !`TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); git -C "$TOP" ls-files --others --exclude-standard 2>/dev/null || echo "n/a"`
- Recent commits: !`git log --oneline -5 2>/dev/null || echo "n/a"`
- Existing PR: !`gh pr view --json number,url,isDraft,title,baseRefName,headRefName 2>/dev/null || echo none`
- Latest self-review report (`$LATEST` pointer, defined in `pr-self-review/references/diff-and-policy.md` §4 and written by `pr-self-review`) and its verdict: !`TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 0; }; REPO=$(basename "$TOP"); LATEST="$TOP/../self-review-$REPO/LATEST"; RP=$(cat "$LATEST" 2>/dev/null); if [ -n "$RP" ] && [ -f "$RP" ]; then echo "$RP"; grep -m1 -E '^## Verdict' "$RP" 2>/dev/null; else echo "none — no self-review ran for this checkout"; fi; true`

## Steps

1. **State sanity, then ticket key**: if any pre-computed line says `unknown default branch` or `not a git repo`, stop and tell the author (fetch origin, or fix the `default_branch` option); nothing below can be trusted until it is fixed. Then the pre-computed "Ticket key" line (`${user_config.ticket_regex}`, default `[A-Z][A-Z0-9]+-[0-9]+`; the value `none` disables the check). `NONE` → stop and ask; the Bash guard will refuse the commit anyway. Disabled → commit as `type: description` and say so.

2. **Refuse to proceed** if any of these hold, and say which:
   - the "On the demo branch" line says `YES` → stop: demo work is pushed with `/dimi:poc push` (no PR, light gate); production work starts from the default branch via `/dimi:port`;
   - the "Demo-marker hits" line is not `none` → stop; `/dimi:port` classifies and drops those hunks;
   - behind the default branch **and** the overlap list above is not empty → stop; suggest `git rebase origin/<default>` only while the branch is unpushed (a rebased pushed branch needs a force-push, which the Bash guard blocks), otherwise `git merge origin/<default>`; then re-run the local checks, then this command. Behind with no overlap is a warning in the report, not a refusal (team policy decides whether to rebase anyway);
   - untracked files that look like they are not part of the change (`.env*`, dumps, exports, review reports, evidence for other specs, `.claude/.cache/`, Playwright auth state matching `storageState|\.auth/`) → ask which to include; never stage them by default;
   - the "Secret-looking lines" line is not `none` → stop and show the hits for a decision (values are redacted above; read the cited line in the file): a real secret is removed, and rotated if it was ever committed, before anything is committed; a false positive (a variable named `token`, a `password` form field) is noted in the report and the command continues;
   - a customer or person name, or session narrative, in an added comment, docstring, log string or test name (greps in `${CLAUDE_PLUGIN_ROOT}/skills/tidy/SKILL.md` §1) → stop; ask the author to run `/dimi:tidy`, or follow that file's §1–4 inline, first; a plain ticket key inside a comment is a warning (ticket context belongs in the commit message);
   - the latest self-review report (the "Latest self-review report" line) has the verdict `Not ready` or lists open Blockers → stop and list them. No report → warn in the final report that no self-review ran; do not refuse.

3. **Checks**: run the repo's lint and typecheck for the touched packages unless `--skip-checks` is in `$ARGUMENTS`. A failure stops the command; do not commit over it. The repo's own git hooks (husky, pre-commit, lint-staged, commit-msg) run untouched on commit and push: never pass `--no-verify`, and if a hook fails, fix the cause and re-run — do not retry with the hook disabled.

4. **Commits**: propose the split (one logical change per commit; refactor before behaviour; UI after the API it needs). For each commit:
   - stage **explicit paths** (`git add path/one path/two`) — never `-A`, `.` or `-u`;
   - message `type(KEY): description` in the imperative, under 72 characters, with a body of two to five lines on the *why* and anything a reviewer should look at first;
   - show the planned commits and wait for a yes before running them. The `allowed-tools` grant lasts only the turn that invoked this skill, so after the yes the `git commit` / `git push` commands may prompt for permission; that is expected — never work around it.

5. **Push**: `git push -u origin <branch>`. Never `--force` or `--force-with-lease`; if the push is rejected, stop and explain.

6. **PR**:
   - If no PR exists: `gh pr create --draft --base <base> --title "type(KEY): <headline>" --body-file <tmp>` (drop `--draft` only when `--ready` was passed). `<base>` is `--base <branch>` from `$ARGUMENTS` when the author passed it (a stacked PR, e.g. the base a `/dimi:port` run chose: say "stacked on #n; retarget to the default branch after it merges" in the body), else the default branch; if the branch looks stacked and no `--base` was passed, ask. Never the demo branch, whichever way it was named → refuse.
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

8. **Report** in five lines: commits made, branch pushed, PR URL and draft state, checks run locally, CI status if watched, anything refused or warned (e.g. behind the default branch without overlap, no self-review report).

Never post review comments, never approve, never merge. Those are the team's.
