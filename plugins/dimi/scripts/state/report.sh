#!/usr/bin/env bash
# Facts for the report skill, gathered mechanically so the report never guesses them. Called from its `!` injection as
#   bash report.sh <default_branch> <ticket_regex> [range]
# (unconfigured options arrive as literal `${user_config.<key>}`; range such as v1.2.0..HEAD overrides the branch delta).
# Prints labelled lines; always exits 0.
. "$(dirname "$0")/../lib.sh"

block() { echo "- $1:"; if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/    /'; else echo "    none"; fi; }

T=$(top)
if [ -z "$T" ]; then echo "- Repository: not a git repository (a codebase report still works from the files; a ticket report needs git)"; exit 0; fi
cd "$T" || exit 0
export GIT_TERMINAL_PROMPT=0

REPO=$(basename "$T")
B=$(branch_name)
DB=$(resolve_db "${1-}")
TR=$(resolve_tr "${2-}")
RANGE=$(opt "${3-}")
HEAD_SHA=$(git rev-parse -q --verify --short HEAD 2>/dev/null || echo 'no commits yet')

echo "- Repository: $REPO ($T)"
echo "- Branch: $B · HEAD: $HEAD_SHA · default branch: $DB"
echo "- Date: $(date +%Y-%m-%d)"
if [ -n "$TR" ] && valid_ere "$TR"; then
  K=$(printf '%s' "$B" | grep -oE -- "$TR" | head -1)
  echo "- Ticket key in branch name (regex $TR): ${K:-none}"
else
  echo "- Ticket key: ticket regex disabled or invalid"
fi
echo "- Remote: $(git remote get-url origin 2>/dev/null | sed -E 's#(https?://|git@)([^/:]+)[:/]#\2/#; s#\.git$##' || echo none)"

# The delta: an explicit range, else this branch against the default branch (merge base), else nothing.
with_timeout 10 git fetch -q origin "$DB" >/dev/null 2>&1 || true
BASE=
if [ -n "$RANGE" ]; then
  echo "- Range: $RANGE"
  LOG=$(git log --no-merges --format='%h %ad %s' --date=short "$RANGE" 2>/dev/null | cap 60)
  STAT=$(git_diff --numstat "$RANGE" 2>/dev/null)
elif git rev-parse -q --verify "origin/$DB" >/dev/null 2>&1 && [ "$B" != "$DB" ]; then
  BASE=$(git merge-base "origin/$DB" HEAD 2>/dev/null)
  echo "- Range: origin/$DB..HEAD (merge base ${BASE:0:7}) plus uncommitted and untracked work"
  LOG=$(git log --no-merges --format='%h %ad %s' --date=short "origin/$DB..HEAD" 2>/dev/null | cap 60)
  STAT=$( { git_diff --numstat "$BASE" 2>/dev/null; git -c core.quotePath=false ls-files --others --exclude-standard | grep -vE -- "$NEVER_DUMP_RE|$LOCAL_STATE_RE" | while IFS= read -r f; do [ -f "$f" ] && printf '%s\t0\t%s\n' "$(grep -c '' "$f" 2>/dev/null || echo 0)" "$f"; done; } )
else
  echo "- Range: none (on the default branch or no origin/$DB); a ticket report needs a branch or an explicit range"
  LOG=; STAT=
fi
block "Commits in the range (hash date subject)" "$LOG"
if [ -n "$STAT" ]; then
  TOT=$(printf '%s\n' "$STAT" | awk -F'\t' '{ if ($1 ~ /^[0-9]+$/) a += $1; if ($2 ~ /^[0-9]+$/) d += $2; n++ } END { printf "%d files, +%d / -%d lines", n, a, d }')
  echo "- Changed: $TOT"
  block "Changed files (added deleted path; '-' means binary)" "$(printf '%s\n' "$STAT" | sort -t"$(printf '\t')" -k1,1nr | cap 80)"
  block "Test files in the change" "$(printf '%s\n' "$STAT" | cut -f3 | grep -iE '(^|/)(tests?|__tests__|spec|e2e)(/|$)|\.(test|spec)\.[a-z]+$|_test\.(go|py|rs)$|^tests?/' | cap 40)"
fi
echo "- Uncommitted: $(git status --porcelain 2>/dev/null | grep -vE -- "$LOCAL_STATE_RE" | wc -l | tr -d ' ') paths (staged, unstaged or untracked)"

# Reports other dimi skills already wrote for this checkout: the report reads them rather than redoing the work.
R=$(cat "$T/../self-review-$REPO/LATEST" 2>/dev/null)
if [ -f "$R" ]; then echo "- Latest self-review report: $R ($(grep -m1 '^Branch:' "$R" | cut -c1-120))"; else echo "- Latest self-review report: none"; fi
for d in "$T/../plan-from-ticket-$REPO" "$T/../walkthrough-$REPO" "$T/../self-review-$REPO"; do
  [ -d "$d" ] && block "Files in $(basename "$d")" "$(ls -t "$d" 2>/dev/null | grep -v '^LATEST$' | cap 10)"
done

# Codebase shape, for a codebase report: languages by file count, size, tests, manifests, churn hotspots.
FILES=$(git ls-files 2>/dev/null)
echo "- Tracked files: $(printf '%s\n' "$FILES" | grep -c .)"
block "Languages (files by extension, top 12)" "$(printf '%s\n' "$FILES" | sed -nE 's/.*\.([A-Za-z0-9]+)$/\1/p' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head -12 | awk '{ printf "%s %s\n", $2, $1 }')"
block "Top-level layout" "$(printf '%s\n' "$FILES" | awk -F/ 'NF > 1 { print $1 "/" } NF == 1 { print $1 }' | sort | uniq -c | sort -rn | head -20 | awk '{ printf "%s (%s)\n", $2, $1 }')"
block "Manifests and entry points" "$(printf '%s\n' "$FILES" | grep -E '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|go\.mod|Cargo\.toml|pom\.xml|build\.gradle(\.kts)?|Gemfile|composer\.json|Dockerfile|docker-compose[^/]*\.ya?ml|Makefile|\.github/workflows/[^/]+|README\.md|CLAUDE\.md|AGENTS\.md)$' | cap 30)"
echo "- Test files (by name): $(printf '%s\n' "$FILES" | grep -ciE '(^|/)(tests?|__tests__|spec|e2e)(/|$)|\.(test|spec)\.[a-z]+$|_test\.(go|py|rs)$')"
block "Churn hotspots, last 180 days (commits touching the file; size × churn is where bugs live)" \
  "$(git log --since='180 days ago' --no-merges --format= --name-only 2>/dev/null | grep . | sort | uniq -c | sort -rn | head -15 | awk '{ printf "%s %s\n", $2, $1 }')"
block "Largest source files (lines)" "$(printf '%s\n' "$FILES" | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|kt|rb|php|cs|swift|scala|sql|sh)$' | grep -vE '(^|/)(dist|build|vendor|node_modules|generated)/|\.min\.|lock' | xargs -r wc -l 2>/dev/null | grep -v ' total$' | sort -rn | head -10 | awk '{ printf "%s %s\n", $2, $1 }')"
# git log, not shortlog: shortlog reads stdin when it is not a terminal and hangs under the skill injection.
echo "- Contributors, last 180 days: $(git log --since='180 days ago' --no-merges --format=%ae 2>/dev/null | sort -u | wc -l | tr -d ' ')"
echo "- First and last commit: $(git log --reverse --format=%ad --date=short 2>/dev/null | head -1 || echo none) → $(git log -1 --format=%ad --date=short 2>/dev/null || echo none)"

# Client profile: decides what a client-facing report may show.
p="$T/.claude/fde-client-profile.md"
if [ -f "$p" ]; then echo "- Client profile: $p (read it before a client-facing report)"; else echo "- Client profile: none"; fi
exit 0
