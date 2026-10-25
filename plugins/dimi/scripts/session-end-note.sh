#!/usr/bin/env bash
# SessionEnd: leave a one-line note of where this session stopped, so the next session's banner
# (session-context.sh) can say "last time you were here: …". Must be fast: SessionEnd hooks share a
# 1.5 s budget by default, and a plugin's own `timeout` does not raise it (only the user's settings do).
# Everything here is a cheap git read plus one append (~35 ms).
# Requires jq (for the reason field); without it, exit quietly like the other hooks.

set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
REASON=$(printf '%s' "$INPUT" | jq -r '.reason // "unknown"' 2>/dev/null); REASON=${REASON:-unknown}
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

hash_stdin() { if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -c1-40; elif command -v shasum >/dev/null 2>&1; then shasum -a 1 | cut -c1-40; else cksum | cut -d' ' -f1; fi; }
PROJ_KEY=$(pwd | hash_stdin | cut -c1-12)
STATE_DIR="${CLAUDE_PLUGIN_DATA:-.claude/.cache}"
NOTES="$STATE_DIR/sessions/$PROJ_KEY.log"; mkdir -p "$(dirname "$NOTES")" 2>/dev/null || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
N_CHANGED=$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | grep -v '^\.claude/\.cache/' | grep -c . || true)
LAST=""
# The Stop hook leaves the first line of the last assistant message; consume it so a later session that ends
# before any Stop does not report this session's message as its own.
if [ -f "$STATE_DIR/stop-check/$PROJ_KEY.last" ]; then
  LAST=$(head -c 160 "$STATE_DIR/stop-check/$PROJ_KEY.last" 2>/dev/null | tr '\n' ' ')
  rm -f "$STATE_DIR/stop-check/$PROJ_KEY.last" 2>/dev/null
fi
WHEN=$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || date)

printf '%s · %s · %s · %s uncommitted · last: %s\n' "$WHEN" "$REASON" "$BRANCH" "$N_CHANGED" "${LAST:-—}" >> "$NOTES"
# keep the log short
tail -n 20 "$NOTES" > "$NOTES.tmp" 2>/dev/null && mv "$NOTES.tmp" "$NOTES"
exit 0
