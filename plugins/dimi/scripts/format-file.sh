#!/usr/bin/env bash
# PostToolUse (Edit|Write): format and auto-fix the one file Claude just touched.
# Fast and never blocking: this hook always exits 0. Heavier checks live in stop-check.sh.
#
# Toggle: plugin option eslint_fix_on_edit=0 (or env HOOK_ESLINT_FIX=0) skips eslint --fix on edits (type-aware eslint configs can be slow).
# Prettier runs only when the repo has adopted it (a local node_modules/.bin/prettier or a prettier config),
# so a globally installed prettier never reflows files in a repo that does not use it.

set -u
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P) || exit 0   # before any cd: $0 may be relative
. "$HERE/lib.sh" 2>/dev/null || exit 0   # json_get (jq > python3 > node), with_timeout (GNU timeout > gtimeout > perl alarm > none)
json_tool || exit 0
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | json_get tool_input file_path)
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# Resolve a tool: repo-local bin first, then PATH.
bin() {
  if [ -x "node_modules/.bin/$1" ]; then printf '%s' "node_modules/.bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then printf '%s' "$1"
  else return 1
  fi
}

# Prettier is adopted when it is installed locally or a config for it sits in the file's folder or any parent up to
# the project dir (a monorepo package can carry its own config).
prettier_adopted() {
  [ -x node_modules/.bin/prettier ] && return 0
  local c d proj; proj=$(pwd -P)
  d=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P) || d=$proj
  case "$d/" in "$proj"/*) ;; *) d=$proj ;; esac                 # a file outside the project: look at the project only
  while :; do
    [ -x "$d/node_modules/.bin/prettier" ] && return 0
    for c in .prettierrc .prettierrc.json .prettierrc.yaml .prettierrc.yml .prettierrc.json5 .prettierrc.js .prettierrc.cjs .prettierrc.mjs .prettierrc.toml prettier.config.js prettier.config.cjs prettier.config.mjs .prettierrc.ts prettier.config.ts; do
      [ -f "$d/$c" ] && return 0
    done
    [ -f "$d/package.json" ] && [ -n "$(json_get prettier < "$d/package.json")$(json_get devDependencies prettier < "$d/package.json")$(json_get dependencies prettier < "$d/package.json")" ] && return 0
    [ "$d" = "$proj" ] || [ "$d" = / ] && break
    d=$(dirname "$d")
  done
  return 1
}

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.yaml|*.yml|*.html)
    if prettier_adopted && P=$(bin prettier); then
      with_timeout 20 "$P" --log-level warn --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    case "${CLAUDE_PLUGIN_OPTION_ESLINT_FIX_ON_EDIT:-${HOOK_ESLINT_FIX:-1}}" in
      0|false|no|off|False|FALSE|No|NO|Off|OFF) ;;                 # anything else (1, true, yes, on) runs eslint --fix
      *) if E=$(bin eslint); then
           # --no-warn-ignored exists only in flat-config ESLint (9+, or 8 with flat config); eslintrc-mode 8 rejects it and fixes nothing.
           OUT=$(with_timeout 25 "$E" --fix --no-warn-ignored "$FILE" 2>&1)
           case "$OUT" in *"Invalid option"*warn-ignored*|*"warn-ignored"*"flat config"*) with_timeout 25 "$E" --fix "$FILE" >/dev/null 2>&1 || true ;; esac
         fi ;;
    esac
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      with_timeout 20 ruff format -q --force-exclude "$FILE" >/dev/null 2>&1 || true
      # --unfixable F401: an import added in one edit and used in the next must not be deleted in between.
      with_timeout 20 ruff check -q --fix --unfixable F401 --force-exclude "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
