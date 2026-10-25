#!/usr/bin/env bash
# SessionStart (startup | resume | compact): print a compact orientation block.
# Plain stdout from a SessionStart hook is added to Claude's context, so this is how
# critical working state survives /clear, resume and compaction without bloating CLAUDE.md.

set -u
if ! command -v jq >/dev/null 2>&1; then
  echo "dimi: jq is not on PATH, so the plugin's hooks (Bash guard, Stop gate, session notes) are inactive until it is installed."
  exit 0
fi
INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null)

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ------------------------------------------------------------- configuration ----
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-${STOP_DEFAULT_BRANCH:-}}"
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
TICKET_REGEX="${CLAUDE_PLUGIN_OPTION_TICKET_REGEX-${GUARD_TICKET_REGEX-[A-Z][A-Z0-9]+-[0-9]+}}"
case "$TICKET_REGEX" in none|NONE|None) TICKET_REGEX="";; esac
LOCAL_CHECKS="${CLAUDE_PLUGIN_OPTION_LOCAL_CHECKS:-see CLAUDE.md Commands section}"
DEMO_BRANCH="${CLAUDE_PLUGIN_OPTION_DEMO_BRANCH:-}"
# --------------------------------------------------------------------------------

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
TICKET=""; [ -n "$TICKET_REGEX" ] && TICKET=$(printf '%s' "$BRANCH" | grep -oE -- "$TICKET_REGEX" | head -1)
BASE=$(git merge-base "origin/$DEFAULT_BRANCH" HEAD 2>/dev/null || git rev-parse HEAD)
BEHIND=$(git rev-list --count "HEAD..origin/$DEFAULT_BRANCH" 2>/dev/null || echo "?")
COMMITS=$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
CHANGED=$( { git diff --name-only "$BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | grep -v '^\.claude/\.cache/' | sort -u )
N_CHANGED=$(printf '%s\n' "$CHANGED" | grep -c . || true)
UNTRACKED=$(git ls-files --others --exclude-standard | grep -v '^\.claude/\.cache/' | grep -c . || true)

echo "## Working state ($SOURCE)"
_hash() { if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -c1-40; elif command -v shasum >/dev/null 2>&1; then shasum -a 1 | cut -c1-40; else cksum | cut -d' ' -f1; fi; }
_notes="${CLAUDE_PLUGIN_DATA:-.claude/.cache}/sessions/$(pwd | _hash | cut -c1-12).log"
if [ "$SOURCE" != "compact" ] && [ -f "$_notes" ]; then echo "Last session here: $(tail -n 1 "$_notes")"; fi
echo "Branch: $BRANCH  ·  Ticket: ${TICKET:-none in branch name}  ·  Commits on branch: $COMMITS  ·  Behind $DEFAULT_BRANCH: $BEHIND"
echo "Changed vs $DEFAULT_BRANCH: $N_CHANGED files ($UNTRACKED untracked)"
if [ "$N_CHANGED" -gt 0 ]; then
  printf '%s\n' "$CHANGED" | head -30 | sed 's/^/  - /'
  [ "$N_CHANGED" -gt 30 ] && echo "  … and $((N_CHANGED - 30)) more"
fi
echo "Local checks: $LOCAL_CHECKS"
if [ -n "$TICKET_REGEX" ]; then
  echo "Rules: CLAUDE.md is authoritative. Stage explicit paths, never 'git add -A'. Commit as type(${TICKET:-KEY}): description."
else
  echo "Rules: CLAUDE.md is authoritative. Stage explicit paths, never 'git add -A'. Commit as type: description (no ticket key required here)."
fi
echo "Loop: /dimi:plan-from-ticket → (/dimi:grill-me) → build → /dimi:ui-states-review (UI) → /dimi:tidy → /dimi:pr-self-review → /dimi:commit-push-pr → /dimi:address-review → /dimi:compound · red? /dimi:debug · docs: /dimi:walkthrough, /dimi:release-notes · demo branch: /dimi:poc, /dimi:port · agents: /dimi:agent-evals. Rules in .claude/rules/ load per path."
if [ -n "$DEMO_BRANCH" ] && [ "$BRANCH" = "$DEMO_BRANCH" ]; then
  echo "This is the demo branch ($DEMO_BRANCH): merge-only, pushed with /dimi:poc push, never a PR base. Production work happens on a feature branch from $DEFAULT_BRANCH."
fi
[ -f .claude/fde-client-profile.md ] && echo "Client profile present: .claude/fde-client-profile.md — its constraints override defaults."
if [ "$SOURCE" = "compact" ]; then
  echo "Context was just compacted: re-read the plan/notes for this ticket before continuing, and re-verify any claim you were relying on."
fi
exit 0
