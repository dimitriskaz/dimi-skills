#!/usr/bin/env bash
# PostToolUse (Edit|Write): format and auto-fix the one file Claude just touched.
# Fast and never blocking: this hook always exits 0. Heavier checks live in stop-check.sh.
#
# Toggle: plugin option eslint_fix_on_edit=0 (or env HOOK_ESLINT_FIX=0) skips eslint --fix on edits (type-aware eslint configs can be slow).

set -u
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# Portable timeout: GNU timeout > gtimeout > perl alarm > none
tmo() { local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'my $s=shift; my $p=fork; if(!$p){ setpgrp(0,0); exec @ARGV } $SIG{ALRM}=sub{ kill "TERM", -$p; exit 124 }; alarm $s; waitpid $p,0; exit(($?>>8)&255)' "$s" "$@"
  else "$@"; fi; }

# Resolve a tool: repo-local bin first, then PATH.
bin() {
  if [ -x "node_modules/.bin/$1" ]; then printf '%s' "node_modules/.bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then printf '%s' "$1"
  else return 1
  fi
}

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.yaml|*.yml|*.html)
    if P=$(bin prettier); then
      tmo 20 "$P" --log-level warn --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    if [ "${CLAUDE_PLUGIN_OPTION_ESLINT_FIX_ON_EDIT:-${HOOK_ESLINT_FIX:-1}}" = "1" ] && E=$(bin eslint); then
      tmo 25 "$E" --fix --no-warn-ignored "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      tmo 20 ruff format -q "$FILE" >/dev/null 2>&1 || true
      tmo 20 ruff check -q --fix "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
