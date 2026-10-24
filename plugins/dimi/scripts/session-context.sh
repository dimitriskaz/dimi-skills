#!/usr/bin/env bash
# SessionStart (startup | resume | compact): print a compact orientation block.
# Plain stdout from a SessionStart hook is added to Claude's context, so this is how
# critical working state survives /clear, resume and compaction without bloating CLAUDE.md.

set -u
INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null)

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ------------------------------------------------------------- configuration ----
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-${STOP_DEFAULT_BRANCH:-}}"
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
TICKET_REGEX="${CLAUDE_PLUGIN_OPTION_TICKET_REGEX:-${GUARD_TICKET_REGEX:-[A-Z][A-Z0-9]+-[0-9]+}}"
LOCAL_CHECKS="${CLAUDE_PLUGIN_OPTION_LOCAL_CHECKS:-see CLAUDE.md Commands section}"
# --------------------------------------------------------------------------------

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
TICKET=$(printf '%s' "$BRANCH" | grep -oE "$TICKET_REGEX" | head -1)
BASE=$(git merge-base "origin/$DEFAULT_BRANCH" HEAD 2>/dev/null || git rev-parse HEAD)
BEHIND=$(git rev-list --count "HEAD..origin/$DEFAULT_BRANCH" 2>/dev/null || echo "?")
COMMITS=$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
CHANGED=$( { git diff --name-only "$BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | grep -v '^\.claude/\.cache/' | sort -u )
N_CHANGED=$(printf '%s\n' "$CHANGED" | grep -c . || true)
UNTRACKED=$(git ls-files --others --exclude-standard | grep -v '^\.claude/\.cache/' | grep -c . || true)

echo "## Working state ($SOURCE)"
echo "Branch: $BRANCH  ·  Ticket: ${TICKET:-none in branch name}  ·  Commits on branch: $COMMITS  ·  Behind $DEFAULT_BRANCH: $BEHIND"
echo "Changed vs $DEFAULT_BRANCH: $N_CHANGED files ($UNTRACKED untracked)"
if [ "$N_CHANGED" -gt 0 ]; then
  printf '%s\n' "$CHANGED" | head -30 | sed 's/^/  - /'
  [ "$N_CHANGED" -gt 30 ] && echo "  … and $((N_CHANGED - 30)) more"
fi
echo "Local checks: $LOCAL_CHECKS"
echo "Rules: CLAUDE.md is authoritative. Stage explicit paths, never 'git add -A'. Commit as type(${TICKET:-KEY}): description."
echo "Loop: /dimi:plan-from-ticket → build → /dimi:ui-states-review (UI) → /dimi:tidy → /dimi:pr-self-review → /dimi:commit-push-pr → /dimi:address-review → /dimi:compound. Rules in .claude/rules/ load per path."
[ -f .claude/fde-client-profile.md ] && echo "Client profile present: .claude/fde-client-profile.md — its constraints override defaults."
if [ "$SOURCE" = "compact" ]; then
  echo "Context was just compacted: re-read the plan/notes for this ticket before continuing, and re-verify any claim you were relying on."
fi
exit 0
