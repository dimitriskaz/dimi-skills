# Diff build and repo policy (shared by the review skills)

Read by `pr-self-review` and by every skill that reviews "the change": `pr-correctness-scalability-review`, `pr-security-data-review`, `ui-states-review`, `tidy`; `plan-from-ticket`, `compound` and `address-review` read §4 only. `commit-push-pr` computes its state in `scripts/state/commit-push-pr.sh` with the helpers in `scripts/lib.sh`: a change to the default-branch, ticket-regex, marker or secret rules here is mirrored there. One copy, so every stage reads the same diff against the same policy.

The mechanical steps live in `scripts/review.sh`, called from each skill's `SKILL.md` with the plugin options filled in (`${user_config.*}` is substituted only in a `SKILL.md` body, never in this file). Each is one plain command, so it needs no approval prompt; `build` saves the context to `<Out>/context.env`, every later `review.sh` step takes only the printed `Out` path, and other commands use the literal values `build` prints, because each Bash call is a fresh shell and a command that expands a variable cannot be pre-approved.

## 1. Build the diff — local mode (working tree against the default branch)

`review.sh build <skill> <out or ''> <default_branch> <demo_marker> <demo_branch> <ticket_regex> <local_checks> [PR number]`:
- fetches the default branch and diffs the working tree (committed + staged + unstaged) against its merge-base, then appends every untracked file (`git diff --no-index`) except secret and state files (`.env*`, keys, Playwright auth state, `.claude/.cache/`), which are listed but never dumped;
- writes `review.diff`, `status.txt`, `commits.txt`, `untracked.txt`, `review.stat`, `behind.txt` (commits behind the default branch) and `main-moved.txt` (files the default branch changed since the branch point) into the output directory;
- prints the Review context (`Top`, `Out`, `Diff`, `Base`, `Head` — `working tree` in local mode — `Report`, options), the scope line and the report header line `Branch: … · HEAD: … · Tree: …` (`Tree` fingerprints the content of every changed path, so `commit-push-pr` can tell whether anything changed after the review);
- stops with a message when `origin/<default branch>` is missing, instead of reviewing a partial diff.

The output directory is the session's scratchpad if the skill passes it, else `<top>/../<skill>-<repo>/` next to the checkout — absolute, never inside the repo, whatever the cwd. Binary files appear as "Binary files differ": count them, never open them. Read per file with `git diff <Base> -- <path>` when a hunk needs its context (PR mode: §2).

## 2. Build the diff — PR mode (the PR as GitHub sees it)

The same command with the PR number appended. It writes `pr.json` and `checks.txt`, fetches the head as `pull/<N>/head` (fork PRs work) and diffs `origin/<base>...` that head — the PR's own changes only. A remote without pull refs falls back to `gh pr diff`. The header line comes from GitHub (`Tree: —`). `Head` is the fetched head ref: read the PR's code with `git diff <Base> <Head> -- <path>` and `git show <Head>:<path>`, never the local working tree.

## 3. Mechanical gates

`review.sh gates '<Out>'` reads the added lines of the built diff — untracked files included in local mode, the PR's own changes in PR mode (never your working tree) — and prints, as `path:line:text`:
- **demo-only markers**: the `<MARKER>(` shape `poc` writes, excluding `.claude/**`, `CLAUDE.md` and `AGENTS.md` (which name the marker);
- **secret-shaped lines**, values masked (`SECRET_RE` and `redact` in `scripts/lib.sh`, the only copy) — stop for a decision, never auto-refuse;
- **added files that match an ignore rule** (force-added), listed from git (binary and empty files included);
- **untracked secret/state files and working artefacts** (plans, notes, reports) that must never be staged.

`review.sh notes '<Out>' '<CUSTOMER_TERMS>'` lists added comments carrying a ticket key, a customer term or session narrative. `review.sh record '<Out>'` points `LATEST` (`<top>/../self-review-<repo>/LATEST`, one absolute path: the newest self-review report — written by pr-self-review, read by commit-push-pr, compound and address-review) at the report; `review.sh worklist '<Out>'` copies `address-review`'s worklist beside it; `review.sh latest <default_branch>` (no build needed) prints it, its `Branch:` line, the default branch and this branch's report file name.

## 4. Repo policy block

Resolved per repo; `AGENTS.md`/`CLAUDE.md` win. Values marked *option* come from the plugin options (`/plugin` → dimi → Configure options), printed by `review.sh build` in the Review context. Values marked *repo* are read from the repo's `CLAUDE.md`/`AGENTS.md` (or `.claude/rules/`) at run time — put them there, never in the plugin's copy; the examples are placeholders, never defaults to assume. Print the resolved block at the top of the report.

```
DEFAULT_BRANCH       = option default_branch (empty if not configured → origin/HEAD, else main)
TICKET_KEY_REGEX     = option ticket_regex (default [A-Z][A-Z0-9]+-[0-9]+; `none` disables)   # in branch, PR title, every commit
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
LOCAL_CI             = option local_checks (empty if not configured → discover from package.json scripts, Makefile, pyproject, .github/workflows)
MAX_FILE_BYTES       = 1000000
NEVER_STAGE          = env files ((^|/)\.env(\.|$)), key files, exported tokens, local DB dumps, review reports, .claude/worktrees/ (agent worktrees), .claude/.cache/ (the hooks' cache dir), Playwright auth state (storageState|\.auth/)
DEMO_BRANCH          = option demo_branch (empty if not configured)   # never a PR base or head; never reviewed by this gate — /dimi:poc there
DEMO_MARKER          = option demo_marker (default DEMO-ONLY)                 # gates grep the shape <MARKER>( — section 3

# Scale assumptions used by the checklist skills (one realistic tenant, one year in). Placeholders only: the repo's CLAUDE.md
# supplies every noun and number; the line below shows the shape, never values to assume
SCALE = <entities> N; <jobs> N/day, some hourly; history append-only (runs x items); <edges> N+;
        <records per kind> up to N; N concurrent users per page; N server instances (no in-process state); N s gateway timeout
```
