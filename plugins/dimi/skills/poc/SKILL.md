---
name: poc
description: Keep a long-lived demo/POC branch alive and honest — mark demo-only code with a greppable marker, keep a ledger of what is demo-only, owed, or already ported to the default branch, merge the default branch into the demo branch without rewriting shared history, and push straight to the demo branch with a light gate (secrets and customer data only). Use when you say "mark this as demo only", "sync the demo branch with main", "what's left to productionise", "push the demo".
argument-hint: "init | mark <paths> [--why ...] | sync | push [headline] | status"
disable-model-invocation: true
---

# POC: the demo branch is a first-class citizen, not a liability

A demo branch has one job: be demo-able tomorrow. It is allowed shortcuts a production PR is not — a hard-coded tenant, a stubbed permission, fixture data, a skipped approval. What it is *not* allowed is to lose track of which shortcuts those are, or to drift so far from the default branch that nothing on it can be ported. This skill keeps three things true: every shortcut is **marked**, every feature has a **ledger** entry (demo-only / owed / ported), and the branch is **synced** with the default branch by merge, never rebase.

`port` is the other direction (demo → production); it reads the marks and the ledger this skill maintains.

## Current state (pre-computed)

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo"`
- Demo branch (`${user_config.demo_branch}`, empty if not configured): !`DEMO='${user_config.demo_branch}'; case "$DEMO" in '$'*) DEMO='';; esac; echo "${DEMO:-unset}"; true`
- Marker: !`M='${user_config.demo_marker}'; case "$M" in ''|'$'*) M=DEMO-ONLY;; esac; echo "$M"; true`
- Default branch: !`DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); echo "${DB:-main}"; true`
- Ledger on the demo branch: !`DEMO='${user_config.demo_branch}'; case "$DEMO" in '$'*) DEMO='';; esac; if [ -n "$DEMO" ] && { git cat-file -e "$DEMO:docs/poc-ledger.md" 2>/dev/null || git cat-file -e "origin/$DEMO:docs/poc-ledger.md" 2>/dev/null; }; then echo yes; else echo no; fi; true`

Below, `$DEMO`, `$M` and `$DB` are these values. If the demo branch is `unset`, only `init` may run: it asks for the branch name, records it in the ledger header, and tells the author to set `${user_config.demo_branch}` in the plugin options so `port`, `commit-push-pr` and `pr-self-review` see it too. Every other subcommand stops with that message.

## Conventions (set once with `init`)

- **Demo branch**: `${user_config.demo_branch}` (empty if not configured); `init` also records the name in the ledger header. Pushed to a shared remote, so: **merge-only, never rebase, never force-push**. The Bash guard blocks force-push, and blocks `git rebase` while on the demo branch; this skill never runs either.
- **Marker**: `${user_config.demo_marker}` (default `DEMO-ONLY`). Every shortcut carries a comment in the file's comment syntax: `// <MARKER>(<feature>): <why this is acceptable here and what the real version needs>`. Greppable, scoped to a feature, with the reason. `pr-self-review` **fails** a production diff that contains `<MARKER>(`, so a shortcut cannot leak to the default branch unnoticed.
- **Ledger**: `docs/poc-ledger.md` **on the demo branch only** (never on the default branch). Header: demo branch, default branch, marker, created date, last sync, and the **umbrella ticket** (see below). One row per feature:
  ```
  | feature | status | demo paths | marks | ticket | ported in | notes |
  | spreadsheet import links | owed | services/import/**, apps/web/imports/** | 3 | PROJ-120 | — | needs real matching rules |
  | coverage dashboard | ported | apps/web/coverage/** | 0 | PROJ-98 | PR #42 | |
  | fake SSO login | demo-only | apps/web/auth/demo-login.tsx | 1 | — | never | demo auth; production uses the real IdP |
  ```
  Status values: `owed` (must be productionised), `demo-only` (never ported, by decision), `ported` (production PR exists; the demo copy is now a liability to re-sync), `drifted` (production and demo versions differ in behaviour — `status` detects this).
- **Ticket key**: the Bash guard refuses any commit whose message lacks a key matching `${user_config.ticket_regex}`. `<KEY>` below is the ledger row's `ticket` when the feature has one, else the umbrella ticket from the ledger header (a demo/POC ticket the team opens once).
- The demo branch worktree: `git worktree add ../<repo>-demo <demo-branch>`, then start `claude` in that directory, so production and demo work never share a checkout.

## `init`
Ask for the demo branch if `$DEMO` is unset and for the umbrella ticket key. Create the ledger with the header (demo branch, default branch, marker, created date, umbrella ticket) and an empty table; add a `.claude/rules/` line on the demo branch only: "Shortcuts carry `<MARKER>(<feature>): <why>`; register each feature in `docs/poc-ledger.md`". Commit as `chore(<KEY>): init POC ledger`. Offer `/dimi:compound` (do not run it) to add the production-side rule ("`<MARKER>(` never appears in a production PR") to the default branch's rules if it is not there.

## `mark <paths> [--why ...]`
For the given files or hunks: find each shortcut (hard-coded ids, tenants or URLs; bypassed gates; stubbed services; fixture data in `src`; skipped validation; `TODO for demo`), add the marker comment with feature name and reason (ask for the feature name if it is not obvious from the ledger), and add or update the ledger row with the mark count. Show the diff; commit on the demo branch as `chore(<KEY>): mark demo-only code for <feature>` after a yes. Never mark on the default branch.

## `sync`
Bring the default branch into the demo branch without rewriting history:
1. `git fetch origin`, then `git log --format='%h %an %s' <demo>..origin/<demo>`. If it prints anything, someone pushed to the demo branch: show the commits and ask before continuing, regardless of author. Then `git pull --ff-only`; if `--ff-only` fails (local demo commits not yet pushed), `git merge --no-ff origin/<demo>` instead — never rebase.
2. `git merge --no-ff origin/$DB` (merge, never rebase). On conflicts, resolve per the ledger: for features marked `ported`, **prefer the default branch's version** and delete the demo copy if the production one now covers it (the ledger says where); for `owed` and `demo-only`, prefer the demo version and keep the marks; for anything else, show the conflict and ask.
3. Run the narrowest checks for the touched packages (typecheck, the touched tests), one at a time. The demo may be allowed to be rough, but it must boot.
4. Update the ledger: features whose production PR merged become `ported`; note the merge in the header ("last sync: <sha> on <date>").
5. Push with a plain `git push` after showing the summary. Never `--force`.

## `push [headline]`
Commit the current demo work and push straight to the demo branch — no PR, no review gate — with the **light gate** only, in this order:
1. `git rev-parse --abbrev-ref HEAD` must equal `$DEMO`; anything else → stop (feature branches ship through `/dimi:commit-push-pr`).
2. Secrets in the change (tracked diff and untracked files, values redacted — read the cited line yourself) → stop and show the hits for a decision; never auto-refuse:
   ```bash
   TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
   DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}
   M='${user_config.demo_marker}'; case "$M" in ''|'$'*) M=DEMO-ONLY;; esac
   SECRET_RE='(-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? ?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|(api[_-]?key|secret|password|passwd|token|private[_-]?key)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_=-]{8,})'
   redact() { sed -E 's/^([0-9]+:[^=:]*[=:][[:space:]]*).{4,}$/\1<redacted>/' | cut -c1-140; }
   git diff HEAD -U0 -- ':(top)' | grep -niE "^\+.*$SECRET_RE" | redact || true                     # staged + unstaged, whole repo
   git -C "$TOP" ls-files --others --exclude-standard | grep -vE '(^|/)\.env(\.|$)|\.(pem|key|p12)$|storageState|\.auth/|^\.claude/\.cache/' \
     | while IFS= read -r f; do grep -niE "$SECRET_RE" "$TOP/$f" 2>/dev/null | redact | sed "s|^|$f:|"; done; true   # untracked, minus never-stage files
   ```
3. Untracked files that are not part of the change (`.env*`, dumps, exports, review reports, anything matching `storageState|\.auth/`, `.claude/.cache/`) → never stage; ask which of the rest to include.
4. Customer or personal data in code, fixtures or screenshots → stop; the demo tenant's invented data is fine, a real customer's is not.
5. Unmarked shortcuts in the changed files → offer `mark` first (a shortcut without a marker is the thing `port` will miss).
6. The ledger has a row for every feature touched (add or update it in the same commit).
Then `git add <explicit paths>`, `git commit -m "<type>(<KEY>): <headline> [demo]"`, `git push`. The `[demo]` suffix keeps demo commits recognisable in `git log`.

## `status`
The report a stand-up needs:
```
## POC status — <demo branch> vs <default> (last sync <sha>, <n> commits behind, <m> ahead)
| feature | status | marks | ported in | drift |
...
Owed: <k> features (<total marks> shortcuts to replace) · Demo-only: <j> · Ported: <i> (of which drifted: <d>)
Unmarked shortcuts found: <list of suspicious hunks with path:line> → author: `/dimi:poc mark <paths>`
```
```bash
DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}
M='${user_config.demo_marker}'; case "$M" in ''|'$'*) M=DEMO-ONLY;; esac
git fetch -q origin; git rev-parse -q --verify "origin/$DB" >/dev/null || { echo "origin/$DB not found: run git fetch origin $DB, or fix the default_branch option" >&2; exit 1; }
git rev-list --left-right --count "origin/$DB...<demo>"                                 # behind<TAB>ahead
git diff -I "$M\(" "origin/$DB" <demo> -- ':(top)<path>' …                             # drift of one ported feature, marker lines ignored; ':(top)' = repo-relative paths
```
`drift` compares a `ported` feature's demo paths with the production version, ignoring marker lines (`-I` needs a recent git; if yours rejects it, pipe the diff through `grep -v "$M("`). Behaviour differences are listed so the next `sync` can retire the demo copy.

## Rules
- Nothing here ever touches the default branch or opens a PR; `port` and `commit-push-pr` do that.
- The ledger is the single source of truth for "what is left"; if the ledger and the code disagree, `status` says so rather than guessing.
- `status` warns when `git rev-list --count <demo>..origin/$DB` is above 50 or the ledger's last-sync date is older than 14 days: ports get expensive fast.
