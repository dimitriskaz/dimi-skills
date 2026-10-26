#!/usr/bin/env bash
# Pre-computed state for the commit-push-pr skill. Called from its `!` injection as
#   bash commit-push-pr.sh <default_branch> <ticket_regex> <demo_branch> <demo_marker> <protected_branches>
# (unconfigured options arrive as literal `${user_config.<key>}`). Prints labelled lines; always exits 0.
. "$(dirname "$0")/../lib.sh"

# block <label> <text>: a label, then the text indented (or "none").
block() { echo "- $1:"; if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/    /'; else echo "    none"; fi; }

T=$(top)
if [ -z "$T" ]; then echo "- Branch: not a git repo"; exit 0; fi
cd "$T" || exit 0
export GIT_TERMINAL_PROMPT=0

B=$(branch_name)
SAFE=$(safe_name "$B")
DB=$(resolve_db "${1-}")
TR=$(resolve_tr "${2-}")
DEMO=$(opt "${3-}")
M=$(resolve_marker "${4-}")
PB=$(opt "${5-}" 'main|master|production')

echo "- Branch: $B"
echo "- Default branch (option default_branch, else origin/HEAD, else main): $DB"

# Protected: the default branch plus each pipe-separated entry, matched as a shell glob (as guard-bash.sh does).
PROT=no
set -f
OLDIFS=$IFS; IFS='|'
for p in $DB $PB; do
  [ -n "$p" ] || continue
  case "$B" in $p) PROT="YES — HEAD is $B, which matches $p: refuse" ;; esac
done
IFS=$OLDIFS
set +f
echo "- On default/protected branch (default $DB; protected $PB): $PROT"

if [ -z "$TR" ]; then
  echo "- Ticket key in branch name: ticket regex disabled (none)"
else
  K=$(printf '%s' "$B" | grep -oE -- "$TR" | head -1)
  echo "- Ticket key in branch name (regex $TR): ${K:-NONE — no ticket key in the branch name}"
fi

if [ -z "$DEMO" ]; then echo "- On the demo branch: no demo branch configured"
elif [ "$B" = "$DEMO" ]; then echo "- On the demo branch: YES — HEAD is the demo branch $DEMO: refuse"
else echo "- On the demo branch: no ($DEMO)"; fi

with_timeout 10 git fetch -q origin "$DB" >/dev/null 2>&1 || true
echo "- Default branch tip: $(git rev-parse --short "origin/$DB" 2>/dev/null || echo unknown)"

# --left-right --count A...B prints <only in A> <only in B>: commits behind, then ahead.
LR=$(git rev-list --left-right --count "origin/$DB...HEAD" 2>/dev/null)
if [ -n "$LR" ]; then
  set -- $LR
  echo "- Behind / ahead of origin/$DB: behind=$1 ahead=$2"
else
  echo "- Behind / ahead of origin/$DB: unknown"
fi

MB=$(git merge-base "origin/$DB" HEAD 2>/dev/null)
if [ -z "$MB" ]; then
  echo "- Merge base: unknown default branch (origin/$DB missing)"
else
  MOVED=$(git -c core.quotePath=false diff --name-only "$MB..origin/$DB" 2>/dev/null | sort -u)
  MINE=$( { git -c core.quotePath=false diff --name-only "$MB" 2>/dev/null; git -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u)
  X=$(printf '%s\n%s\n' "$MOVED" "$MINE" | grep . | sort | uniq -d)
  block "Files the default branch changed since the branch point that this change also touches (rebase risk)" "$X"

  ADDED=$(change_diff "$MB" | diff_added_lines)   # the whole change, untracked files included (never-dump files left out)
  block "Demo-marker hits in the diff ($M(, excluding .claude/**, CLAUDE.md, AGENTS.md)" \
    "$(printf '%s\n' "$ADDED" | grep -vE '^((.*/)?\.claude/[^:]*|(.*/)?(CLAUDE|AGENTS)\.md):' | grep -F -- "$M(" | cut -c1-160 | cap 20)"
  block "Working notes in added comments (ticket key, session narrative; customer terms are yours to check)" \
    "$(printf '%s\n' "$ADDED" | note_lines "$TR" | cut -c1-160 | cap 20)"
  block "Secret-looking lines in the change (path:line, values redacted; read the cited line yourself)" \
    "$(printf '%s\n' "$ADDED" | grep -iE -- "$SECRET_RE" | redact | cut -c1-160 | cap 20)"
fi

block "Untracked files that look like secrets or state (never staged)" \
  "$(git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null | grep -iE -- "$NEVER_DUMP_RE")"

HK=$( { [ -d .husky ] && ls .husky 2>/dev/null | tr '\n' ' '; [ -f .pre-commit-config.yaml ] && echo pre-commit; git config core.hooksPath 2>/dev/null; } | tr '\n' ' ' | sed 's/ *$//')
echo "- Repo git hooks present: ${HK:-none}"
block "Status (paths from the top level)" "$(git status --short 2>/dev/null)"
block "Untracked (not ignored, paths from the top level)" "$(git ls-files --others --exclude-standard 2>/dev/null)"
block "Recent commits" "$(git log --oneline -5 2>/dev/null)"

PR=''
if command -v gh >/dev/null 2>&1; then
  PR=$(with_timeout 15 gh pr view --json number,url,isDraft,title,baseRefName,headRefName 2>/dev/null)
  PRN=$(printf '%s' "$PR" | sed -nE 's/.*"number":[[:space:]]*([0-9]+).*/\1/p')
fi
echo "- Existing PR: ${PR:-none}"

# Latest self-review report: must be for this branch (or this branch's PR) and should be for this HEAD.
LATEST="$T/../self-review-$(basename "$T")/LATEST"
RP=$(cat "$LATEST" 2>/dev/null)
if [ -n "$RP" ] && [ -f "$RP" ]; then
  echo "- Latest self-review report: $RP"
  case "$(basename "$RP")" in
    "self-review-$SAFE.md") echo "    for this branch: yes" ;;
    "self-review-pr-${PRN:-none}.md") echo "    for this branch: yes (PR #$PRN)" ;;
    *) echo "    for this branch: NO — it reviews another branch; treat as no self-review" ;;
  esac
  # The tree fingerprint decides whether the change was reviewed as it stands (committing reviewed work moves
  # HEAD but not the tree); HEAD is shown for reference.
  RT=$(grep -m1 -oE 'Tree: [0-9a-f]{12}' "$RP" | sed 's/^Tree: //')
  CT=$(tree_fingerprint "${MB:-HEAD}")
  RH=$(grep -m1 -oE 'HEAD: [0-9a-f]{7,40}' "$RP" | sed 's/^HEAD: //')
  if grep -q 'Tree: — (PR mode)' "$RP" 2>/dev/null; then echo "    reviewed tree: — (PR-mode report: re-run /dimi:pr-self-review in local mode before committing more)"
  elif [ -z "$RT" ]; then echo "    reviewed tree: not recorded (report predates the Tree field) · reviewed HEAD: ${RH:-not recorded}"
  elif [ "$RT" = "$CT" ]; then echo "    reviewed tree: $RT (current: nothing changed since the review)"
  else echo "    reviewed tree: $RT — CHANGED (now $CT): edits since the review were not reviewed"; fi
  V=$(grep -m1 -E '^## Verdict' "$RP" 2>/dev/null)
  echo "    ${V:-verdict line missing}"
else
  echo "- Latest self-review report: none — no self-review ran for this checkout"
fi
exit 0
