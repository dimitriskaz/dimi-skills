---
name: "pr-self-review"
description: "Pre-commit / pre-push self-review of your working tree (or an open PR) that runs the same three-stage gate your team's reviewers use — repo-policy compliance, correctness/scalability/conventions, security/data-handling — and writes a reviewer-style report with Blocker / Should fix / Minor findings plus commit-message and PR-description drafts."
argument-hint: "[#pr | branch | nothing = working tree]"
---

# Self-review before commit and push

Use when development is done and the author wants the review their teammates would give, **before** committing, pushing or opening the PR. Triggers: `/pr-self-review`, "review my changes before I commit", "self-review", "am I ready to push", "what would the reviewer find", "re-run the self-review", "review PR #42".

This is a **gate, not a GitHub action**. Never post reviews, comments or approvals to GitHub, never commit or push on the author's behalf unless asked in the fix loop. The report lives outside the repo.

Three stages, in this order:
1. **Compliance gate** (repo policy, mechanical, plus running CI's local equivalents) — section 4.
2. **Code review** (correctness, scalability, conventions) — load and follow `pr-correctness-scalability-review`.
3. **Security & data review** — load and follow `pr-security-data-review`. If the repo has its own security-review skill, run it too against the same working tree and include its result.
4. **Domain reviews when they apply** — if the diff touches agent/LLM code, run `/dimi:review-agent <changed paths>`; if it touches an MCP server, `/dimi:harden-mcp <path>`. Fold their findings in, prefixed `RA-`/`HM-` (their check ids collide), mapping severities: Critical → Blocker; High → Should fix, promoted to Blocker when it meets a Blocker criterion in section 6; Medium → Minor, promoted to Should fix when it sits on a realistic path; Low → Minor. Their verdict "Ready with conditions" corresponds to our "Ready with notes". Do not re-derive their findings.

Then verify, classify, decide, report, offer the fix loop, and compound the lessons (sections 5–10).

## 0. Stance: you are not the author now

The person asking wrote this code. Review as the sceptical teammate who did not:
- Commit messages, comments, docstrings and the author's description are **claims**. Each is verified against code, tests or evidence, or reported as unverified.
- "I intended that" is not a defence; the code must show it and a test must pin it.
- Grade the consequence for a real tenant. Do not soften because the fix is tedious or the pattern predates the change (note the history separately).
- Do not skip a lens because "that part is fine". Familiarity hides asymmetries.
- Do not report what linters, type checkers and CI already catch — run them (section 4) and spend review time on what tools cannot see.

## 1. Inputs and modes

**Local mode (default).** No argument, or a branch name: review the current working tree — committed-on-branch **plus staged, unstaged and untracked** changes — against the base branch. This is what will become the PR.

**PR mode.** A PR number (`#42`) or `--pr`: review the open PR as GitHub sees it. Use when the code is already pushed, or to re-check after review comments.

**Stack mode.** Several PR numbers or a range: see Appendix A. Rare; do not optimise for it.

Before judging anything, read the repo rules: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE*`, and the job names and commands in `.github/workflows/*.yml`. They are authoritative; the policy block in section 4 is the starting point to edit. If `.claude/fde-client-profile.md` exists (an engagement profile), its risk tiers, data classes and approval rules adjust severities.

## 2. Setup

`$OUT` is a directory **outside the repo**: the scratchpad directory if the session gives one, else `../self-review-<repo>/`. Never write review files inside the checkout. Keep the repo's own `.gitignore` untouched.

### Local mode
`$DB` is the default branch: the plugin option `default_branch`, else `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'`, else `main`.
```bash
DB=${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')}; DB=${DB:-main}
git fetch origin "$DB"
BASE=$(git merge-base "origin/$DB" HEAD)
git status --short > $OUT/status.txt                    # what is committed / staged / unstaged / untracked
git log --oneline $BASE..HEAD > $OUT/commits.txt
git diff $BASE > $OUT/review.diff                       # committed + staged + unstaged vs base
git ls-files --others --exclude-standard > $OUT/untracked.txt
while read -r f; do git diff --no-index -- /dev/null "$f"; done < $OUT/untracked.txt >> $OUT/review.diff 2>/dev/null
git diff --stat $BASE > $OUT/review.stat
git rev-list --count "HEAD..origin/$DB"                 # commits behind the default branch (rebase need)
git diff --name-only "$BASE..origin/$DB" > $OUT/main-moved.txt   # files the default branch changed since you branched
```
`$OUT/review.diff` is the diff every stage reads (`$DIFF`). Binary files appear as "Binary files differ": count them, never open them.

Tell the author up front what the review covers: N commits, M staged, K unstaged, U untracked files — so they know what `git add -A` would sweep in. Untracked files that are **not** part of the change (scratch notes, `.env`, exports, review reports) are a gate finding, not part of the review.

### PR mode
```bash
gh pr view N --json number,title,body,isDraft,author,baseRefName,headRefName,additions,deletions,changedFiles,commits,reviews,statusCheckRollup,files,url > $OUT/pr.json
gh pr checks N > $OUT/checks.txt
git fetch origin <baseRefName> <headRefName>
git diff origin/<base>...origin/<head> > $OUT/review.diff      # three-dot: this PR's own changes
git log --oneline origin/<base>..origin/<head> > $OUT/commits.txt
```

### Budget
- **Proportional depth.** The gate must not become the slow part. Under ~150 changed lines of code: run the compliance checks, apply only the lenses for the layers actually touched, no sub-agents, and aim to finish in a few minutes; the report can be short. 150–2,000 lines: full lenses, still in this session. Over ~2,000: delegate as below. A small diff with a long review is a sign the review is padding.
- **Local checks run one at a time**, scoped to the touched packages (`pnpm --filter ./<pkg> …`). Never launch two heavy commands in parallel shells and never fork agents to run checks; parallel Node processes fight for CPU and both get slower.
- Reading order by risk: routes/endpoints → data access and query builders → connectors/outbound calls → jobs/workers → schema, seeds, contracts → model/view-model code → UI → tests and fixtures → docs. Binaries are counted only.
- Read the diff per file (`git diff $BASE -- path`), and for any hunk you doubt read the **whole function and its callers** in the working tree. Hunks alone produce lint, not review.
- Over ~2,000 changed lines of code: run stages 2 and 3 as two sub-agents in parallel, each given `$DIFF`, the policy block, the `SCALE` line and the interchange format (section 7), returning finding blocks. Spot-check two CONFIRMED findings from each before accepting.

## 3. Understand before judging

Write one paragraph in your own words: what the change does, how (which layers), why the approach is or is not right. Then list **claims to verify**: from commit messages and the author's description, comments and docstrings ("read once", "only the lease prevents duplicates"), headers ("see otherModule.ts"), UI copy ("Nothing was linked"), runbooks ("grant permission X for test 4"). Every claim is checked in stages 2–3.

## 4. Compliance gate

Output: a table `Rule | Status | Detail`. **Pass** meets policy. **Fail** blocks commit/push. **Note** = the reviewer must know (acceptable, or a product decision to confirm). Detail is concrete: the branch name, the commit count, which checks ran locally and which did not.

### Repo policy (resolved per repo; AGENTS.md/CLAUDE.md win)

Values marked *option* come from the plugin options (`/plugin` → dimi → Configure options); otherwise from the repo's `CLAUDE.md`. Values marked *repo* are read from `CLAUDE.md`/`AGENTS.md`; the examples are placeholders, never defaults to assume.
```
DEFAULT_BRANCH       = option default_branch (default main)
TICKET_KEY_REGEX     = option ticket_regex, e.g. PROJ-[0-9]+     # in branch, PR title, every commit
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
LOCAL_CI             = option local_checks, else discover from package.json scripts, Makefile, pyproject, .github/workflows
MAX_FILE_BYTES       = 1000000

# Scale assumptions used by the checklist skills (one realistic tenant, one year in) — repo: adjust in CLAUDE.md
SCALE = assets 20k; tests 300 nightly, some hourly; result history append-only (runs x tests); edges 100k+;
        records per kind up to 50k; 10 concurrent users per page; >1 server instance (no in-process state); 30s gateway timeout
```

### Checks — local mode

- **Base freshness** — commits behind `origin/$DB`; files in `main-moved.txt` that this change also touches (conflict and semantic-drift risk). Behind with overlap → Note "rebase before push".
- **Branch name** carries `TICKET_KEY_REGEX`.
- **Commits so far** — each headline matches `COMMIT_FORMAT` and carries the key. If the working tree is uncommitted, draft the commit message(s) in section 9 and check them against the format.
- **One change per commit** — if the diff holds several separable features (new route + UI + refactor + fixture churn), propose a commit split now, while it is cheap: list files per proposed commit with a headline each.
- **What `git add -A` would sweep in** — go through `untracked.txt` and `status.txt`: review reports, `.env*`, scratch scripts, exports, local DB dumps, IDE files, files over `MAX_FILE_BYTES`, generated files, evidence PNGs for *other* specs. Each is a Fail ("do not stage") or Note.
- **Forbidden paths and ignored files** — nothing under `FORBIDDEN_PATHS`; `git diff --name-only --diff-filter=A $BASE | xargs -r git check-ignore -v` and `git diff --cached --name-only | xargs -r git check-ignore -v` — a staged or committed ignored file was force-added → Fail.
- **Ratchets only go down** — `git diff --name-only $BASE` touches no `RATCHET_BASELINES`; `grep -nE '^\+' $DIFF | grep -nE '<ESCAPE_HATCHES>'` adds none, or each is listed with its justification.
- **Working notes in code** — grep the added lines for comments, docstrings, log strings, test names and identifiers that carry a ticket key, a customer or person, a date, or session narrative ("as discussed", "per the review", "step 3", "added for", "for now"), plus commented-out code and placeholder docstrings. Customer/person references → Fail; the rest → Note with the count. Fix with `/dimi:tidy` before committing — a reviewer should never see the scaffolding.
- **Debug leftovers** — `grep -nE '^\+' $DIFF | grep -nE '<DEBUG_LEFTOVERS>'`. `.only` or `debugger` → Fail; new `console.log`/`print` in src → Note unless it is the module's logging convention.
- **Customer names and data** — `grep -inE '<CUSTOMER_TERMS>' $DIFF` and the untracked list. Also judge content: catalogues or mappings "transcribed from a customer workbook", POC ticket ids inside keys or source refs, fixture org names that look real. History is permanent → Fail.
- **Required tests and evidence** — per `REQUIRED_TESTS`: a spec references the new feature; evidence exists and is fresh (the runner's last-run summary mentions the touched specs); a unit test or selfcheck exists and is wired into the test script.
- **Run CI's local equivalents** — from `LOCAL_CI`, run what applies to the changed packages: lint, typecheck, unit tests/selfchecks, and the browser specs for touched features (not the whole suite unless asked). Record each as `ran: pass|fail (duration)` or `not run: <why>`. A failing local check is a Fail. Anything CI runs that you could not run (CodeQL, IaC scan) is listed as "will run in CI".
- **Scope hygiene** — binary vs code file counts; evidence re-captured for other specs; unrelated locator tweaks; behaviour changes outside the ticket → Note.
- **Dependencies** — new entries in `package.json`/lockfiles/`pyproject`/`requirements`: one line each on why; `FORBIDDEN_DEPS` grep on added lines.
- **Author's description** — if a PR body draft exists (or the author describes the change), does it say what changed and why, how it was tested, what is deferred with tickets? Missing → Note; section 9 drafts it.

### Checks — PR mode (in addition)

- **PR title** matches `COMMIT_FORMAT`; body present and accurate.
- **Base** is `DEFAULT_BRANCH` (or the previous PR in a stack); three-dot diff holds only this ticket's work.
- **Draft state matches the body** — body says "draft"/"do not merge yet" while `isDraft=false` → Note.
- **No self-approval** — `author.login` has no APPROVED review. Name who still needs to approve.
- **CI** — every run check SUCCESS. List SKIPPED jobs and what they imply ("web build skipped by path filter → no browser e2e ran"). Skipped is not passed.
- **Evidence vs claim** — body's testing claims against the test runner's last-run summary, if the repo commits one (N of M specs; local vs CI).

## 5. Verify every finding

- Trace to `path:line` **in the working tree as it is now** (PR mode: at the PR head), and to the other end of the mechanism (caller, consumer, store path, the data-layer doc that says how the read behaves).
- State as **mechanism → consequence → fix**, two to four sentences a reader who has not opened the code can follow.
- **CONFIRMED** = mechanism traced in code, both ends cited. **PLAUSIBLE** = depends on vendor behaviour, runtime volumes, a lease or config you could not see, or recollection of an external API — name what would confirm it.
- A Blocker or Should fix that is only PLAUSIBLE keeps its severity and names the confirm step; never downgrade to avoid the work.
- Predates the change but is perpetuated, made heavier or made reachable by it → still counts; say so.
- Drop anything you cannot phrase as a concrete consequence. Do not pad.
- **One finding, one place.** The same defect in server and UI is reported once where it should be fixed, with `also_affects`.

## 6. Classify and decide

Every finding gets **severity · category · confidence**. Categories: `correctness`, `scalability`, `conventions`, `security`, `data-handling`.

**Blocker** — fix before push:
- Duplicate, lost or corrupted durable records at `SCALE` (untrimmed ids re-duplicating on re-import; inventory past a cap re-created every run; links dropped across chunks). With `RECORDS_DELETABLE = no`, any record-creation bug is a Blocker.
- Customer names/data or personal data committed, or flowing into run outputs, logs, exports or model context.
- A security gate bypassed by an alternate path; a tenant boundary at risk.
- The change fails its own headline promise for a real tenant (the bug it exists to fix recurs; an integration times out and never produces a result on a real-size account).
- A wrong key or model locked into durable records (dedupe keys, missing source-instance id on results, hard-coded sets gating generic logic).

**Should fix** — before push unless deferred with a ticket:
- Correctness bug on a realistic path; verify step passing on mismatch; old runs shown against current thresholds.
- Read/write pattern that degrades with history or tenant size; caps that silently truncate; N+1 or serial awaits in one request; polling without cache; read-then-write without lock.
- Missing server-side validation or audit for verdict-affecting settings.
- Copied plumbing; a second implementation of the same rule or metric.
- Behaviour change outside the ticket; shipped surface with no consumer (especially one that can return personal data).
- Required test or evidence missing; a local check failing.

**Minor** — fix or file:
- Edge cases unlikely at `SCALE` (clock skew, date-only parsing, mid-walk churn); dead code, dead flags, stale fixtures, dangling references; token/component drift, ARIA misuse, UI state nits, free-text inputs for constrained values; unrelated churn; pre-existing patterns kept.

**Verdict.** *Not ready* if any Blocker, **or** if the Should-fix set together means the change does not deliver what its title claims for a real tenant (zero Blockers but wrong headline numbers at scale is still Not ready). Otherwise *Ready with notes*. In PR mode use the team's words: *Request changes* / *Approve with comments*.

## 7. Interchange format (what the checklist skills and sub-agents return)
```
FINDING
id: <branch-or-pr>-<seq>     # stable across re-runs: never renumber; retire ids instead
severity: Blocker | Should fix | Minor
category: correctness | scalability | conventions | security | data-handling
confidence: CONFIRMED | PLAUSIBLE
title: <the defect, not the symptom>
where: path/to/file.ts:123 [, other/end.ts:456]
mechanism: <what the code does>
consequence: <what happens to a real tenant>
fix: <one clause>
confirm: <PLAUSIBLE only: what would confirm it>
predates: yes|no
also_affects: <optional>
END
```
Then `STRENGTHS:` bullets and `CHECKED_CLEAN:` bullets (category — one-line reason).

## 8. Report

Write `$OUT/self-review-<branch-or-pr>.md` (publish as an artifact too if the tool exists). Structure, exactly:
```
# Self-review: <branch or #N> (TICKET) — <title or draft title>
<repo> · reviewed <date> · local working tree | PR head · gate only, nothing posted
Scope: N commits · M staged · K unstaged · U untracked · +adds/−dels · F files (B binary)

## Verdict: Not ready | Ready with notes   (Blockers B · Should fix S · Minor M)
<One paragraph: what it does, what is right, what is wrong and why it matters.>

## Findings (K)
1 · Blocker · category · CONFIRMED            [id]
**Title**
`path:line` — mechanism. consequence. fix.

## Compliance gate
| Rule | Status | Detail |

## Local checks run
| Check | Result | Notes |

## Strengths
## Checked, nothing found
```
Strengths and Checked-nothing-found are mandatory: they show coverage and tell the reviewer where not to spend time. List only what you actually checked.

**Re-run mode.** If `$OUT` already holds a report for this branch/PR, load its finding ids and re-check each: `Fixed` (cite the commit or hunk), `Open`, `Deferred` (cite the ticket). New findings get new ids. Lead with the delta.

## 9. Fix loop, commit messages, PR description

Offer to fix. Severity order; one finding per commit with the ticket key; Minors never mixed into behaviour commits. Run `/dimi:tidy` before the commits so working notes never reach the reviewer. After fixing, re-run the gate (including local checks) and update the report in re-run mode. Commit or push only when the author says so.

Then draft, ready to paste:
- **Commit message(s)** in `COMMIT_FORMAT`, one per proposed commit, body listing the files and the why.
- **PR description**: what changed and why; how it was tested (which local checks ran, which specs, N of M; what CI will add); known limitations and deferred findings with ticket references; product decisions a reviewer should confirm (defaults, visibility choices). Reviewers trust a PR more when the author has already said where the bodies are.

If `commit-push-pr` is available, offer to run it with these drafts.

## 10. Compound

The report is not finished until its lessons are captured. End by offering `/compound`: every Blocker and Should-fix becomes a candidate for a path-scoped rule in `.claude/rules/`, a hook (if it must never happen again) or a skill (if it is a procedure). A finding that reappears on a second branch despite a rule is escalated to a hook. Two minutes here is what makes the next ticket's self-review shorter than this one.

## Appendix A — Stacks (rare)

Order PRs by `baseRefName` (each PR's base is the previous head). Review each against **its own base**, never `main`. Review one PR at a time, writing `$OUT/pr-N.md` before starting the next; for more than two PRs, delegate each PR to a sub-agent with the inputs from section 2 and the interchange format. Prepend a stack overview table (`PR | Ticket | Title | Verdict | Blockers | Should fix | Minor | Size`) and a **Themes across the stack** section: the same data in several places; the same cap or read pattern repeated; one metric defined two ways; a key or model fixed early that later PRs build on; copied plumbing; shipped-ahead tools; the same binaries churned in every PR; a claim repeated in every body. Note files a later PR needs that landed earlier, and references to files that only exist later. Merge strictly in stack order.