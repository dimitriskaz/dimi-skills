# Diff build and repo policy (shared by the review skills)

Read by `pr-self-review` and by every skill that reviews "the change": `pr-correctness-scalability-review`, `pr-security-data-review`, `ui-states-review`, `tidy`; `plan-from-ticket`, `compound` and `address-review` read §4 only. `commit-push-pr` cannot read files from its pre-computed injections, so it inlines the same snippets verbatim: a change here is mirrored there. One copy, so every stage reads the same diff against the same policy.

Plugin options (`${user_config.*}`) are substituted only in a `SKILL.md` body, never in this file. The invoking skill resolves `DB` (default branch), `M` (demo marker), `DEMO` (demo branch), `TR` (ticket regex) and `LOCAL_CI` first — its `SKILL.md` carries the guarded lines — and the snippets below reuse those variables, falling back to the defaults when they are unset.

## 1. Build the diff — local mode (working tree against the default branch)

`$OUT` is the invoking skill's output directory: the session's scratchpad directory if it gives one (set `OUT=<scratchpad path>` on the line before the block), else `$TOP/../<skill>-<repo>/` next to the checkout, absolute and never inside the repo. Unset, it defaults to `self-review`'s directory. Every path is top-level-relative (`$TOP`), never cwd-relative, so the blocks work from any subdirectory; a missing `origin/$DB` stops the block instead of reviewing a partial diff.

```bash
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
REPO=$(basename "$TOP")
OUT=${OUT:-$TOP/../self-review-$REPO}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd -P)
DIFF="$OUT/review.diff"
# default branch: option (set by the invoking skill) > origin/HEAD > main
case "${DB:-}" in ''|'$'*) DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||');; esac; DB=${DB:-main}
if command -v timeout >/dev/null 2>&1; then timeout 10 git fetch -q origin "$DB"; else git fetch -q origin "$DB"; fi 2>/dev/null || true
BASE=$(git merge-base "origin/$DB" HEAD 2>/dev/null) || { echo "origin/$DB not found: run git fetch origin $DB, or fix the default_branch option" >&2; exit 1; }
git -C "$TOP" status --short > "$OUT/status.txt"                    # committed / staged / unstaged / untracked, paths from the top level
git log --oneline "$BASE..HEAD" > "$OUT/commits.txt"
git diff "$BASE" > "$DIFF"                                          # committed + staged + unstaged vs base (whole repo, whatever the cwd)
git -C "$TOP" ls-files --others --exclude-standard > "$OUT/untracked.txt"
# untracked files join the diff via --no-index; secret and state files are listed in untracked.txt but never dumped
while IFS= read -r f; do
  case "$f" in .env|.env.*|*/.env|*/.env.*|*.pem|*.key|*.p12|*storageState*|*.auth/*|.claude/.cache/*) continue;; esac
  git -C "$TOP" diff --no-index -- /dev/null "$f" || true          # --no-index exits 1 whenever the file differs
done < "$OUT/untracked.txt" >> "$DIFF" 2>/dev/null
git diff --stat "$BASE" > "$OUT/review.stat"
git rev-list --count "HEAD..origin/$DB" > "$OUT/behind.txt" 2>/dev/null || echo "?" > "$OUT/behind.txt"   # commits behind the default branch (rebase need)
git diff --name-only "$BASE..origin/$DB" > "$OUT/main-moved.txt" 2>/dev/null || true                     # files the default branch changed since the branch point
```

`$DIFF` is the diff every stage reads. Binary files appear as "Binary files differ": count them, never open them. Read per file with `git diff "$BASE" -- <path>` when a hunk needs its context.

## 2. Build the diff — PR mode (the PR as GitHub sees it)

```bash
N=${N:?set N=<PR number> on the line before this block}
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
REPO=$(basename "$TOP")
OUT=${OUT:-$TOP/../self-review-$REPO}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd -P)
DIFF="$OUT/review.diff"
gh pr view "$N" --json number,title,body,isDraft,author,baseRefName,headRefName,additions,deletions,changedFiles,commits,reviews,statusCheckRollup,files,url > "$OUT/pr.json"
gh pr checks "$N" > "$OUT/checks.txt" 2>&1 || true                  # non-zero when a check failed; the file still has the table
BASE_REF=$(jq -r .baseRefName "$OUT/pr.json"); HEAD_REF=$(jq -r .headRefName "$OUT/pr.json")
if git fetch -q origin "$BASE_REF" "$HEAD_REF" 2>/dev/null; then
  git diff "origin/$BASE_REF...origin/$HEAD_REF" > "$DIFF"          # three-dot: this PR's own changes
  git log --oneline "origin/$BASE_REF..origin/$HEAD_REF" > "$OUT/commits.txt"
  BASE=$(git merge-base "origin/$BASE_REF" "origin/$HEAD_REF")
else                                                                 # head lives on a fork: take the diff from GitHub
  gh pr diff "$N" > "$DIFF"
  gh pr view "$N" --json commits -q '.commits[] | "\(.oid[0:7]) \(.messageHeadline)"' > "$OUT/commits.txt"
  git fetch -q origin "$BASE_REF" 2>/dev/null || true; BASE="origin/$BASE_REF"
fi
```

## 3. Demo-marker gate

`poc` writes the marker as `<MARKER>(<feature>): <why>`, so the gate greps the shape with the parenthesis, not the bare word, and excludes the plugin's own rule files (which name the marker). The `:(top)` pathspecs and the subshell make it cover the whole repo from any subdirectory.

```bash
: "${BASE:?run section 1 or 2 first}"; TOP=${TOP:-$(git rev-parse --show-toplevel)}
case "${M:-}" in ''|'$'*) M=DEMO-ONLY;; esac
git diff "$BASE" -- ':(top)' ':(exclude,top).claude/**' ':(exclude,top)CLAUDE.md' ':(exclude,top)AGENTS.md' | grep -nE "^\+.*${M}\(" || true
( cd "$TOP" && git ls-files --others --exclude-standard | grep -vE '^(\.claude/|CLAUDE\.md$|AGENTS\.md$)' \
  | while IFS= read -r f; do grep -nHE "${M}\(" "$f" 2>/dev/null; done ) || true
```

Any line printed is a **Fail** / stop: a POC shortcut is about to reach the default branch. `/dimi:port` is the way across.

## 4. Repo policy block

Resolved per repo; `AGENTS.md`/`CLAUDE.md` win. Values marked *option* come from the plugin options (`/plugin` → dimi → Configure options), already resolved by the invoking skill into `$DB`, `$M`, `$DEMO`, `$TR`, `$LOCAL_CI`. Values marked *repo* are read from `CLAUDE.md`/`AGENTS.md`; the examples are placeholders, never defaults to assume. Print the resolved block at the top of the report.

Shared one-liners, defined here once and copied **verbatim** wherever a skill or injection needs them (`$TOP` and `$REPO` as in §1):
```bash
LATEST="$TOP/../self-review-$REPO/LATEST"   # holds one absolute path: the newest self-review report. Written by pr-self-review; read by commit-push-pr, compound, address-review
SECRET_RE='(-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? ?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|(api[_-]?key|secret|password|passwd|token|private[_-]?key)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_=-]{8,})'
# grep -niE "$SECRET_RE" "$DIFF" | sed -E 's/^(([^:]*:)?[0-9]+:[^=:]*[=:][[:space:]]*).{4,}$/\1<redacted>/' | cut -c1-140   # show hits redacted; stop for a decision, never auto-refuse
```

```
DEFAULT_BRANCH       = option default_branch ($DB; empty if not configured → origin/HEAD, else main)
TICKET_KEY_REGEX     = option ticket_regex ($TR; default [A-Z][A-Z0-9]+-[0-9]+; `none` disables)   # in branch, PR title, every commit
COMMIT_FORMAT        = type(KEY): description                   # type: feat|fix|chore|refactor|test|docs
FORBIDDEN_PATHS      = repo: paths policy says never to commit, e.g. docs/private-notes/**, plus anything .gitignore'd by policy
CUSTOMER_TERMS       = repo: customer/client names, engagement ticket prefixes, "customer's workbook"-style phrases
RATCHET_BASELINES    = repo: lint/type baseline files whose counts may only go down
ESCAPE_HATCHES       = ': any', 'as any', '@ts-ignore', '@ts-expect-error', 'eslint-disable', '# type: ignore', '# noqa'
DEBUG_LEFTOVERS      = '.only(', 'fit(', 'fdescribe(', 'debugger', 'console.log(', 'print(' (outside CLIs), 'breakpoint()', 'test.skip' without reason
REQUIRED_TESTS       = repo: e.g. UI feature -> browser spec + committed evidence; new pure module -> unit test wired into the test script
FORBIDDEN_DEPS       = repo: banned libraries, data sources, patterns (e.g. payload-keyed indexes, migrations where seeds are expected)
EVIDENCE_DIR         = repo: where test evidence/screenshots live; only this ticket's should change
RECORDS_DELETABLE    = repo: yes|no — if no, every record-creation bug is permanent: raise severity
LOCAL_CI             = option local_checks ($LOCAL_CI; empty if not configured → discover from package.json scripts, Makefile, pyproject, .github/workflows)
MAX_FILE_BYTES       = 1000000
NEVER_STAGE          = env files ((^|/)\.env(\.|$)), key files, exported tokens, local DB dumps, review reports, .claude/.cache/ (the hooks' cache dir), Playwright auth state (storageState|\.auth/)
DEMO_BRANCH          = option demo_branch ($DEMO; empty if not configured)   # never a PR base or head; never reviewed by this gate — /dimi:poc there
DEMO_MARKER          = option demo_marker ($M; default DEMO-ONLY)             # gates grep the shape <MARKER>( — section 3

# Scale assumptions used by the checklist skills (one realistic tenant, one year in). Placeholders only: the repo's CLAUDE.md
# supplies every noun and number; the line below shows the shape, never values to assume
SCALE = <entities> N; <jobs> N/day, some hourly; history append-only (runs x items); <edges> N+;
        <records per kind> up to N; N concurrent users per page; N server instances (no in-process state); N s gateway timeout
```
