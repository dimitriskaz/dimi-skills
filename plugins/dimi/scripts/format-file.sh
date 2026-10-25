#!/usr/bin/env bash
# PostToolUse (Edit|Write): format and auto-fix the one file Claude just touched.
# Fast and never blocking: this hook always exits 0. Heavier checks live in stop-check.sh.
#
# Toggle: plugin option eslint_fix_on_edit=0 (or env HOOK_ESLINT_FIX=0) skips eslint --fix on edits (type-aware eslint configs can be slow).
# Prettier runs only when the repo has adopted it (a local node_modules/.bin/prettier or a prettier config),
# so a globally installed prettier never reflows files in a repo that does not use it.

set -u
command -v jq >/dev/null 2>&1 || exit 0
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

# Prettier is adopted when it is installed locally or the repo carries a config for it.
prettier_adopted() {
  [ -x node_modules/.bin/prettier ] && return 0
  local c
  for c in .prettierrc .prettierrc.json .prettierrc.yaml .prettierrc.yml .prettierrc.json5 .prettierrc.js .prettierrc.cjs .prettierrc.mjs .prettierrc.toml prettier.config.js prettier.config.cjs prettier.config.mjs .prettierrc.ts prettier.config.ts; do
    [ -f "$c" ] && return 0
  done
  [ -f package.json ] && jq -e '.prettier != null or (.devDependencies.prettier // .dependencies.prettier) != null' package.json >/dev/null 2>&1 && return 0
  return 1
}

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.yaml|*.yml|*.html)
    if prettier_adopted && P=$(bin prettier); then
      tmo 20 "$P" --log-level warn --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    case "${CLAUDE_PLUGIN_OPTION_ESLINT_FIX_ON_EDIT:-${HOOK_ESLINT_FIX:-1}}" in
      0|false|no|off|False|FALSE|No|NO|Off|OFF) ;;                 # anything else (1, true, yes, on) runs eslint --fix
      *) if E=$(bin eslint); then tmo 25 "$E" --fix --no-warn-ignored "$FILE" >/dev/null 2>&1 || true; fi ;;
    esac
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      tmo 20 ruff format -q "$FILE" >/dev/null 2>&1 || true
      tmo 20 ruff check -q --fix "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
