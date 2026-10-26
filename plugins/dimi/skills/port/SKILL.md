---
name: port
description: Productionise a feature from a demo/POC branch onto the default branch — compute the real feature delta (minus what is already upstream or in your open PRs), build the "available surface" of main plus your unmerged PRs in a throwaway integration worktree, classify every POC hunk as reuse / rewrite / drop against the house rules, decide the PR base (main, or stacked on the open PR it depends on), implement through plan-from-ticket, and update the POC ledger. Use when you say "port this to main", "productionise the demo feature", "build the real version of what's on the demo branch".
argument-hint: "<feature or paths> [--from <demo-branch-or-worktree>] [--base main|<pr-branch>]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Port: from demo-able to mergeable

The POC on the demo branch proves the idea; it cannot be cherry-picked, because it was built on shortcuts and on a stale base, and because "what exists on main" now includes your own PRs that are open but not merged. This skill turns one feature into a production change deliberately: it works out what the feature actually is, what is already there, what to reuse, what to rewrite and what to drop, picks the right base, and then hands the build to the normal loop.

Triggers: `/dimi:port <feature>`, "port the import links to main", "productionise …". Companion of `poc` (which marks shortcuts and keeps the ledger this skill reads).

## Current state (pre-computed)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/poc.sh '${user_config.demo_branch}' '${user_config.demo_marker}' '${user_config.default_branch}'`

Below, `<demo>`, `<marker>`, `<default branch>` and `<top>` are these values. Write them literally into every command: the Bash tool keeps no shell variables between calls, and a literal command is one the author can pre-approve.

## 0. Inputs and constraints

- **Demo source**: `--from` (branch name, or a worktree path — resolve it with `git -C <path> rev-parse --abbrev-ref HEAD`), else `<demo>`. If `<demo>` is `unset` and there is no `--from`: look for a branch carrying the ledger (`for b in $(git branch -r --format='%(refname:short)'); do git cat-file -e "$b:docs/poc-ledger.md" 2>/dev/null && echo "$b"; done`) and read its header; none or several → ask.
- **Feature**: paths, a commit range, or a ledger row name. Resolve to a path set using the ledger's `demo paths` column when it exists.
- Read `CLAUDE.md`, `.claude/rules/`, `.claude/fde-client-profile.md` (constraints), and the ledger on the demo branch (`git show <demo>:docs/poc-ledger.md`).
- Work in a **production worktree** on a fresh branch; never on the demo branch. All reading of the demo branch is through `git show <demo>:<path>` and `git diff`, so nothing demo-side is ever checked out into the production tree.
- `<out>` is the session's scratchpad directory if it gives one, else `<top>/../port-<repo>/` next to the checkout (never inside the repo). Write it as an absolute path, so the worktree commands below work from any subdirectory and never depend on the cwd. `<KEY>` is the ticket key in the new branch's name (matching `${user_config.ticket_regex}`); none → ask.

## 1. The real delta

```bash
git fetch origin                                                                   # then: origin/<default branch> missing → stop, fetch it or fix the default_branch option
git log --oneline origin/<default branch>..<demo> -- ':(top)<path>' …                   # demo commits touching the feature; ':(top)' = repo-relative paths, whatever the cwd
git log --oneline --cherry-mark --right-only origin/<default branch>...<demo> -- ':(top)<path>' …   # '=' = already upstream by patch-id, '+' = demo-only
gh pr list --author @me --state open --limit 100 --json number,title,headRefName,baseRefName,files   # my unmerged PRs
```
Remove from the delta: commits marked `=` (already upstream). Files that also appear in an open PR of yours are **flagged, not removed**: compare the demo hunk with `git diff origin/<default branch>...origin/<pr-branch> -- <file>` (three dots: the PR's own changes since it branched, not everything `<default branch>` gained since) and drop only hunks that are byte-identical to the PR's (those belong to that PR; note the dependency); everything else in the file stays in the delta. What remains is the **feature delta**: list it by file with the demo commits behind each.

## 2. The available surface (local only)

Production code must be written against what *will* exist, not against today's `main` alone:
```bash
git worktree add <out>/integration origin/<default branch> && touch <out>/integration/.dimi-port-integration   # the marker is how cleanup finds it
git -C <out>/integration merge --no-ff --no-edit origin/<open PR branch>     # once per open PR; on a conflict: git -C <out>/integration merge --abort, and report it
( cd <out>/integration && <the repo's install command, e.g. pnpm install --frozen-lockfile> )   # a fresh worktree has no dependencies; tests will not run without this
```
Never `cd` into the worktree: every command there goes through `git -C <out>/integration …` or a subshell `( cd <out>/integration && … )`, so the shell stays in the production checkout — §4's cherry-picks and §5's commits land there, and the cleanup line works (run from inside the worktree it deletes the cwd and every later git command fails). This integration worktree is for reading and running tests only. It is never pushed and never a PR base. If two of your PRs conflict with each other, that is a finding in its own right — report it. Whenever this skill stops early (a conflict here, the two-PR case in §3, the author says no), run the cleanup line from Output first, from the production checkout, so the next run can recreate the worktree.

## 3. Decide the base

- No file of the feature delta touches an open PR, and no symbol it needs exists only in one → **base on `<default branch>`** (the recommended default).
- The feature needs code from exactly one open PR → **stack on that PR's branch** (`--base <pr-branch>`, `gh pr create --base <pr-branch>`), one level deep; say in the PR body "stacked on #n; retarget to `<default branch>` after it merges"; after #n merges, the author runs `gh pr edit --base <default branch>` then `git merge origin/<default branch>` (no rebase: a pushed branch would need a force push, which the guard blocks). Nothing to run now.
- It needs two or more → clean up the worktree, stop and show the dependency graph; the usual answer is to port the dependency first or to wait for a merge.
- Never base on the demo branch.

## 4. Classify every POC hunk

Read each hunk of the feature delta with the production rules in mind (the lenses in `${CLAUDE_PLUGIN_ROOT}/skills/pr-correctness-scalability-review/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/pr-security-data-review/SKILL.md`, `.claude/rules/`). Three buckets:

| Bucket | Test | Action |
|---|---|---|
| **Drop** | Carries the demo marker (`<marker>(`); hard-coded tenant, ids, URLs, credentials or fixture data; a bypassed gate; a stubbed service; demo-only UI | Not ported. If the ledger says `demo-only`, nothing more; if `owed`, the *real* mechanism goes on the rewrite list |
| **Rewrite** | The idea is right, the implementation is a shortcut: copied plumbing instead of the shared helper; ad-hoc query instead of the data layer; no idempotency, no caps, unread shown as empty, missing tests; built against a stale version of a module that has since changed on `<default branch>` | Re-implement in the production worktree against the canonical pattern, reading the integration worktree; the POC is the spec, not the code |
| **Reuse** | Clean, follows the canonical pattern as it exists on `<default branch>` today, has tests, no marks | When the whole commit qualifies, the cherry-pick block below; else `git show <demo>:<path>` and apply the hunk. Either way remove any `<marker>(` line and commit with the message reworded without `[demo]`, keeping a `(cherry picked from commit <sha>)` line in the body for provenance |

Cherry-pick of a whole demo commit. Almost every demo commit also touches `docs/poc-ledger.md` (`poc push` requires the ledger row in the same commit) and the ledger does not exist on `<default branch>`, so a plain `git cherry-pick` stops with `CONFLICT (modify/delete): docs/poc-ledger.md` — handle it:
```bash
git cherry-pick -x -n <sha> || true
git rm -q -f --ignore-unmatch -- ':(top)docs/poc-ledger.md'                               # the ledger never reaches the production branch
git diff --name-only --diff-filter=U                                                     # anything listed = other conflicts
```
On other conflicts, resolve them, or `git reset -q --merge` and port the commit hunk by hunk with `git show <demo>:<path>`.
`-n` leaves the result staged, so the commit is yours: `git commit -m "<type>(<KEY>): <reworded subject>" -m "(cherry picked from commit <full sha>)"` — `-m` discards the message `-x` prepared, so the provenance line is added by hand.

Expect mostly *rewrite*. A port where everything is *reuse* means the POC was already production-grade (fine) or the classification was lazy (check again). Record the table; it becomes the PR's "Origin" section.

## 5. Build it through the normal loop

1. `/dimi:plan-from-ticket` with the rewrite list as the problem statement and the POC as reference material: identity keys, run-it-twice, scale, failure modes, settings placement, tests that fail without the change, commit plan. The plan must name what the POC got wrong and what the production version does instead.
2. Implement on the new branch (in the production worktree; the integration worktree is for `grep`/`read` and for running the touched tests against the future surface). Reuse hunks first, then rewrites, one commit per logical change.
3. `/dimi:ui-states-review` if UI; POC hunks carry narrative, so ask the author to run `/dimi:tidy`, or follow `${CLAUDE_PLUGIN_ROOT}/skills/tidy/SKILL.md` §1–4 inline; then `/dimi:pr-self-review` — which also fails on any surviving demo marker.
4. Ask the author to run `/dimi:commit-push-pr --base <branch from §3>` (not model-invocable); hand them the **Origin** section for the PR body: demo branch and commits, the reuse/rewrite/drop table, and the shortcuts deliberately *not* ported.

## 6. Close the loop on the demo branch

Ask the author to run `/dimi:poc ledger <feature> in-review --pr <n>` in the demo worktree (this skill never checks out, commits to or pushes the demo branch, and `poc` is not model-invocable). The row becomes `ported` once the PR merges — the next `poc sync` sets it, or the author runs `/dimi:poc ledger <feature> ported --pr <n>`. From then on the demo copy is a liability; `poc sync` will prefer the production version where the two collide, and `poc status` will flag drift. If the feature stays partly demo-only (e.g. demo auth), split the row: the production part `in-review`, the shortcut `demo-only` with its reason.

## Output

```
## Port — <feature>: <demo> → <base>
Feature delta: <n> commits, <m> files · already upstream: <k> · in open PRs: <list>
Available surface: <default branch> + PRs #a #b (integration merge: clean | conflicts: …)
Base: <default branch | stacked on #n (retarget after merge)>
| hunk / file | bucket | why | done via |
Plan: <path> · Branch: <name> · PR: <url or "not opened yet">
Ledger: <feature> → in-review (#n), `ported` after merge · demo-only remainder: …
Not ported on purpose: <list with reasons>
```
Then clean up (also on every early stop), from the production checkout, never from inside the worktree. It finds the worktree itself — only one this skill created (detached and carrying its `.dimi-port-integration` marker), never a worktree of yours — so it works wherever `OUT` pointed:
```bash
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 1; }
git worktree list --porcelain | awk '/^worktree /{ p = substr($0, 10) } /^detached/{ print p }' \
  | while IFS= read -r w; do [ -f "$w/.dimi-port-integration" ] && git worktree remove --force "$w" && echo "removed $w"; done; git worktree prune
```

## Rules
- The demo branch is read, never checked out into the production tree, never rebased, never committed to or pushed by this skill; ledger updates are the author's, through `/dimi:poc ledger` in the demo worktree.
- A demo marker in the production diff is a Blocker; so is a hard-coded tenant or fixture that was "just for now".
- Reuse requires the canonical pattern *as it is on `<default branch>` today*; a hunk that was clean against last month's main may now be a copy.
