---
name: "pr-self-review"
description: "Pre-commit / pre-push self-review of your working tree (or an open PR) that runs the same three-stage gate your team's reviewers use — repo-policy compliance, correctness/scalability/conventions, security/data-handling — and writes a reviewer-style report with Blocker / Should fix / Minor findings plus commit-message and PR-description drafts."
argument-hint: "[#pr | branch | nothing = working tree]"
---

# Self-review before commit and push

Use when development is done and the author wants the review their teammates would give, **before** committing, pushing or opening the PR. Triggers: `/dimi:pr-self-review`, "review my changes before I commit", "self-review", "am I ready to push", "what would the reviewer find", "re-run the self-review", "review PR #42".

This is a **gate, not a GitHub action**. Never post reviews, comments or approvals to GitHub, never commit or push on the author's behalf unless asked in the fix loop. The report lives outside the repo.

Four stages, in this order:
1. **Compliance gate** (repo policy, mechanical, plus running CI's local equivalents) — section 5.
2. **Code review** (correctness, scalability, conventions) — load and follow `pr-correctness-scalability-review`.
3. **Security & data review** — load and follow `pr-security-data-review`. If the repo has its own security-review skill, run it too against the same working tree and include its result.
4. **Domain reviews when they apply** — if the diff touches agent/LLM code, run `/dimi:review-agent <changed paths>`; if it touches an MCP server, `/dimi:harden-mcp <path>`. Both run as forked subagents and return their report in this turn; wait for it. Fold their findings in, prefixed `RA-`/`HM-` (their check ids collide), mapping severities: Critical → Blocker; High → Should fix, promoted to Blocker when it meets a Blocker criterion in section 1; Medium → Minor, promoted to Should fix when it sits on a realistic path; Low → Minor. Their verdict "Ready with conditions" corresponds to our "Ready with notes". Do not re-derive their findings.

Then verify, classify, decide, report, offer the fix loop, and compound the lessons (sections 6–10).

## 0. Stance: you are not the author now

The person asking wrote this code. Review as the sceptical teammate who did not:
- Commit messages, comments, docstrings and the author's description are **claims**. Each is verified against code, tests or evidence, or reported as unverified.
- "I intended that" is not a defence; the code must show it and a test must pin it.
- Grade the consequence for a real tenant. Do not soften because the fix is tedious or the pattern predates the change (note the history separately).
- Do not skip a lens because "that part is fine". Familiarity hides asymmetries.
- Do not report what linters, type checkers and CI already catch — run them (section 5) and spend review time on what tools cannot see.

## 1. Severity and verdict (read first; it is what the rest serves)

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

## 2. Inputs and modes

**Local mode (default).** No argument, or a branch name: review the current working tree — committed-on-branch **plus staged, unstaged and untracked** changes — against the base branch. This is what will become the PR.

**PR mode.** A PR number (`#42`) or `--pr`: review the open PR as GitHub sees it. Use when the code is already pushed, or to re-check after review comments.

**Stack mode.** Several PR numbers or a range: see Appendix A. Rare; do not optimise for it.

Before judging anything, read the repo rules: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE*`, and the job names and commands in `.github/workflows/*.yml`. They are authoritative; the Repo policy block in [references/diff-and-policy.md](references/diff-and-policy.md) §4 is the starting point to edit. If `$TOP/.claude/fde-client-profile.md` exists (an engagement profile; read it from the top level, not the cwd), its risk tiers, data classes and approval rules adjust severities; profile severities map Critical or High → Blocker, Medium → Should fix, Low → Minor.

## 3. Setup

`$OUT` is the session's scratchpad directory if it gives one (set `OUT=<scratchpad path>` on the line before the block below), else `$TOP/../self-review-<repo>/` next to the checkout — absolute, never inside the repo, whatever the current directory. Never write review files inside the checkout; keep the repo's own `.gitignore` untouched.

Resolve the plugin options once, here, in the first bash block (they are substituted into this skill when it loads; the reference file cannot see them):
```bash
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
REPO=$(basename "$TOP"); SAFE=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')      # PR mode: SAFE=pr-$N
DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}
M='${user_config.demo_marker}'; case "$M" in ''|'$'*) M=DEMO-ONLY;; esac
DEMO='${user_config.demo_branch}'; case "$DEMO" in '$'*) DEMO='';; esac
TR='${user_config.ticket_regex}'; case "$TR" in ''|'$'*) TR='[A-Z][A-Z0-9]+-[0-9]+';; none|NONE) TR='';; esac
LOCAL_CI='${user_config.local_checks}'; case "$LOCAL_CI" in '$'*) LOCAL_CI='';; esac
OUT=${OUT:-$TOP/../self-review-$REPO}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd -P)
LATEST="$TOP/../self-review-$REPO/LATEST"
```

### Local mode
Run §1 of [references/diff-and-policy.md](references/diff-and-policy.md). It writes `$DIFF` (`$OUT/review.diff`: committed + staged + unstaged, plus untracked files via `--no-index`), `status.txt`, `commits.txt`, `untracked.txt`, `review.stat`, `behind.txt`, `main-moved.txt`, and sets `$BASE`. It stops with a message when `origin/$DB` is missing: tell the author (fetch, or fix the `default_branch` option) instead of reviewing a partial diff. `$DIFF` is the diff every stage reads. Binary files appear as "Binary files differ": count them, never open them.

Tell the author up front what the review covers: N commits, M staged, K unstaged, U untracked files — so they know what `git add -A` would sweep in. Untracked files that are **not** part of the change (scratch notes, `.env*`, exports, review reports, `.claude/.cache/`, Playwright auth state matching `storageState|\.auth/`) are a gate finding, not part of the review.

### PR mode
Set `N=<number>` and `SAFE=pr-$N` on the line before, then run §2 of the same file: `gh pr view` and `gh pr checks` into `$OUT`, then the three-dot diff `origin/<base>...origin/<head>` into `$DIFF` (this PR's own changes only; `gh pr diff` when the head lives on a fork).

### Budget
- **Proportional depth.** The gate must not become the slow part. Under ~150 changed lines of code: run the compliance checks, apply only the lenses for the layers actually touched, no sub-agents, and aim to finish in a few minutes; the report can be short. 150–2,000 lines: full lenses, still in this session. Over ~2,000: delegate as below. A small diff with a long review is a sign the review is padding.
- **Local checks run one at a time**, scoped to the touched packages (`cd <pkg> && <pm> run …`, with the package manager the repo uses). Never launch two heavy commands in parallel shells and never fork agents to run checks; parallel Node processes fight for CPU and both get slower.
- Reading order by risk: routes/endpoints → data access and query builders → connectors/outbound calls → jobs/workers → schema, seeds, contracts → model/view-model code → UI → tests and fixtures → docs. Binaries are counted only.
- Read the diff per file (`git diff $BASE -- path`), and for any hunk you doubt read the **whole function and its callers** in the working tree. Hunks alone produce lint, not review.
- Over ~2,000 changed lines of code: run stages 2 and 3 as two `reviewer` agents in parallel, each given `$DIFF`, the resolved policy block, the `SCALE` line and the interchange format (section 7), returning finding blocks. Tell each that the compliance gate has already run lint, typecheck and tests, so it must **not** run them (two parallel heavy checks fight for CPU). Spot-check two CONFIRMED findings from each before accepting.

## 4. Understand before judging

Write one paragraph in your own words: what the change does, how (which layers), why the approach is or is not right. Then list **claims to verify**: from commit messages and the author's description, comments and docstrings ("read once", "only the lease prevents duplicates"), headers ("see otherModule.ts"), UI copy ("Nothing was linked"), runbooks ("grant permission X for test 4"). Every claim is checked in stages 2–3.

## 5. Compliance gate

Output: a table `Rule | Status | Detail`. **Pass** meets policy. **Fail** blocks commit/push. **Note** = the reviewer must know (acceptable, or a product decision to confirm). Detail is concrete: the branch name, the commit count, which checks ran locally and which did not.

### Repo policy (resolved per repo; AGENTS.md/CLAUDE.md win)

The block lives in [references/diff-and-policy.md](references/diff-and-policy.md) §4: ticket format, forbidden paths, customer terms, ratchets, escape hatches, debug leftovers, required tests, forbidden deps, evidence dir, records deletable, local checks, never-stage list, demo branch and marker, and the `SCALE` line. Read it once, fill the *repo* values from `CLAUDE.md`/`AGENTS.md`, and print the resolved block at the top of the report. The *option* values are the `$DB`, `$M`, `$DEMO`, `$TR`, `$LOCAL_CI` resolved in section 3.

### Checks — local mode

- **Demo branch** — `[ -n "$DEMO" ] && [ "$(git rev-parse --abbrev-ref HEAD)" = "$DEMO" ]` → **Fail** and stop: the demo branch is never reviewed by this gate; `/dimi:poc` keeps it honest and `/dimi:port` brings work to production. Skip when `$DEMO` is empty.
- **Base freshness** — commits behind `origin/$DB` (`behind.txt`); files in `main-moved.txt` that this change also touches (conflict and semantic-drift risk). Behind with overlap → Note "rebase before push".
- **Branch name** carries `$TR` (skip when `$TR` is empty: the regex was set to `none`).
- **Commits so far** — each headline matches `COMMIT_FORMAT` and carries the key. If the working tree is uncommitted, draft the commit message(s) in section 9 and check them against the format.
- **One change per commit** — if the diff holds several separable features (new route + UI + refactor + fixture churn), propose a commit split now, while it is cheap: list files per proposed commit with a headline each.
- **What `git add -A` would sweep in** — go through `untracked.txt` and `status.txt`: review reports, `.env*`, scratch scripts, exports, local DB dumps, `.claude/.cache/`, Playwright auth state (`storageState|\.auth/`), IDE files, files over `MAX_FILE_BYTES`, generated files, evidence PNGs for *other* specs. Each is a Fail ("do not stage") or Note.
- **Forbidden paths and ignored files** — nothing under `FORBIDDEN_PATHS`; `git diff --name-only --diff-filter=A $BASE | xargs -r git check-ignore -v --no-index` and `git diff --cached --name-only | xargs -r git check-ignore -v --no-index` (without `--no-index`, tracked and staged paths are never reported) — a staged or committed ignored file was force-added → Fail.
- **Ratchets only go down** — `git diff --name-only $BASE` touches no `RATCHET_BASELINES`; `grep -nE '^\+' $DIFF | grep -nE '<ESCAPE_HATCHES>'` adds none, or each is listed with its justification.
- **Working notes in code** — grep the added lines for comments, docstrings, log strings, test names and identifiers that carry a ticket key, a customer or person, a date, or session narrative ("as discussed", "per the review", "step 3", "added for", "for now"), plus commented-out code and placeholder docstrings. Customer/person references → Fail; the rest → Note with the count. Ask the author to run `/dimi:tidy`, or follow `${CLAUDE_PLUGIN_ROOT}/skills/tidy/SKILL.md` §1–4 inline, before committing — a reviewer should never see the scaffolding.
- **Demo-only markers** — run §3 of [references/diff-and-policy.md](references/diff-and-policy.md): the `<marker>(` shape over `git diff "$BASE"` (excluding `.claude/**`, `CLAUDE.md`, `AGENTS.md`, which name the marker) plus untracked files. Any hit → **Fail**: a POC shortcut is about to reach the default branch. `/dimi:port` is the way across; hard-coded tenants, ids, fixture data or bypassed gates without the marker are the same Fail under the correctness/security checklists.
- **Debug leftovers** — `grep -nE '^\+' $DIFF | grep -nE '<DEBUG_LEFTOVERS>'`. `.only` or `debugger` → Fail; new `console.log`/`print` in src → Note unless it is the module's logging convention.
- **Customer names and data** — `grep -inE '<CUSTOMER_TERMS>' $DIFF` and the untracked list. Also judge content: catalogues or mappings "transcribed from a customer workbook", POC ticket ids inside keys or source refs, fixture org names that look real. History is permanent → Fail.
- **Required tests and evidence** — per `REQUIRED_TESTS`: a spec references the new feature; evidence exists and is fresh (the runner's last-run summary mentions the touched specs); a unit test or selfcheck exists and is wired into the test script.
- **Run CI's local equivalents** — from `$LOCAL_CI` (else discover from `package.json` scripts, `Makefile`, `pyproject`, `.github/workflows`), run what applies to the changed packages: lint, typecheck, unit tests/selfchecks, and the browser specs for touched features (not the whole suite unless asked). Record each as `ran: pass|fail (duration)` or `not run: <why>`. A failing local check is a Fail. Anything CI runs that you could not run (CodeQL, IaC scan) is listed as "will run in CI".
- **Scope hygiene** — binary vs code file counts; evidence re-captured for other specs; unrelated locator tweaks; behaviour changes outside the ticket → Note.
- **Dependencies** — new entries in `package.json`/lockfiles/`pyproject`/`requirements`: one line each on why; `FORBIDDEN_DEPS` grep on added lines.
- **Author's description** — if a PR body draft exists (or the author describes the change), does it say what changed and why, how it was tested, what is deferred with tickets? Missing → Note; section 9 drafts it.

### Checks — PR mode (in addition)

- **PR title** matches `COMMIT_FORMAT`; body present and accurate.
- **Base** is `$DB` (or the previous PR in a stack); three-dot diff holds only this ticket's work. Base **or head** equal to `$DEMO` (when set) → **Fail**: the demo branch never opens or receives PRs; `/dimi:port` brings the work across.
- **Draft state matches the body** — body says "draft"/"do not merge yet" while `isDraft=false` → Note.
- **No self-approval** — `author.login` has no APPROVED review. Name who still needs to approve.
- **CI** — every run check SUCCESS. List SKIPPED jobs and what they imply ("web build skipped by path filter → no browser e2e ran"). Skipped is not passed.
- **Evidence vs claim** — body's testing claims against the test runner's last-run summary, if the repo commits one (N of M specs; local vs CI).

## 6. Verify every finding

- Trace to `path:line` **in the working tree as it is now** (PR mode: at the PR head), and to the other end of the mechanism (caller, consumer, store path, the data-layer doc that says how the read behaves).
- State as **mechanism → consequence → fix**, two to four sentences a reader who has not opened the code can follow.
- **CONFIRMED** = mechanism traced in code, both ends cited. **PLAUSIBLE** = depends on vendor behaviour, runtime volumes, a lease or config you could not see, or recollection of an external API — name what would confirm it.
- A Blocker or Should fix that is only PLAUSIBLE keeps its severity and names the confirm step; never downgrade to avoid the work.
- Predates the change but is perpetuated, made heavier or made reachable by it → still counts; say so.
- Drop anything you cannot phrase as a concrete consequence. Do not pad.
- **One finding, one place.** The same defect in server and UI is reported once where it should be fixed, with `also_affects`.

Then classify each finding with section 1 and decide the verdict.

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

Write `$OUT/self-review-$SAFE.md` (`$SAFE` from section 3: the branch name with `/` replaced by `-`, or `pr-<N>`). Publish it as an artifact only if the author asks: it quotes the secret-looking lines and customer terms the gate exists to catch. Structure, exactly:
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

Then record it as the newest report, **regardless of where `$OUT` is** (`$LATEST` from section 3, defined once in [references/diff-and-policy.md](references/diff-and-policy.md) §4):
```bash
mkdir -p "$(dirname "$LATEST")"; printf '%s\n' "$(cd "$OUT" && pwd -P)/self-review-$SAFE.md" > "$LATEST"
```
`commit-push-pr` reads it to refuse pushes over open Blockers; `compound` and `address-review` find the report through it.

**Re-run mode** is keyed on `$LATEST`, never on `$OUT` (a session scratchpad changes every session; the pointer does not). Read `$LATEST`; if it points at an existing report for this branch/PR (same `$SAFE` in the file name), load its finding ids and re-check each: `Fixed` (cite the commit or hunk), `Open`, `Deferred` (cite the ticket). If a `review-worklist.md` sits beside that report (`address-review` writes it there: the reviewer's points in the interchange format, ids `REV-n`), load those too and re-check each the same way. New findings get new ids. Write the new report to `$OUT`, rewrite `$LATEST`, and lead with the delta.

## 9. Fix loop, commit messages, PR description

Offer to fix. Severity order; one finding per commit with the ticket key; Minors never mixed into behaviour commits. Ask the author to run `/dimi:tidy`, or follow `${CLAUDE_PLUGIN_ROOT}/skills/tidy/SKILL.md` §1–4 inline, before the commits so working notes never reach the reviewer. After fixing, re-run the gate (including local checks) and update the report in re-run mode. Commit or push only when the author says so.

Then draft, ready to paste:
- **Commit message(s)** in `COMMIT_FORMAT`, one per proposed commit, body listing the files and the why.
- **PR description**: what changed and why; how it was tested (which local checks ran, which specs, N of M; what CI will add); known limitations and deferred findings with ticket references; product decisions a reviewer should confirm (defaults, visibility choices). Reviewers trust a PR more when the author has already said where the bodies are.

If `commit-push-pr` is available, offer `/dimi:commit-push-pr` with these drafts (the author runs it).

## 10. Compound

The report is not finished until its lessons are captured. End by offering `/dimi:compound` (the author runs it): every Blocker and Should-fix becomes a candidate for a path-scoped rule in `.claude/rules/`, a hook (if it must never happen again) or a skill (if it is a procedure). A finding that reappears on a second branch despite a rule is escalated to a hook. Two minutes here is what makes the next ticket's self-review shorter than this one.

## Appendix A — Stacks (rare)

Order PRs by `baseRefName` (each PR's base is the previous head). Review each against **its own base**, never `main`. Review one PR at a time, writing `$OUT/pr-N.md` before starting the next; for more than two PRs, delegate each PR to a `reviewer` agent with the inputs from section 3 and the interchange format. Prepend a stack overview table (`PR | Ticket | Title | Verdict | Blockers | Should fix | Minor | Size`) and a **Themes across the stack** section: the same data in several places; the same cap or read pattern repeated; one metric defined two ways; a key or model fixed early that later PRs build on; copied plumbing; shipped-ahead tools; the same binaries churned in every PR; a claim repeated in every body. Note files a later PR needs that landed earlier, and references to files that only exist later. Merge strictly in stack order.
