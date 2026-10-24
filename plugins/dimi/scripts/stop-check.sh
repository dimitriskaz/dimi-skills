#!/usr/bin/env bash
# Stop hook: a deterministic gate before Claude ends a turn.
#   - debug leftovers in changed files (.only / fit / fdescribe in JS/TS tests, debugger in JS/TS, breakpoint() in Python)
#   - typecheck for the packages whose TypeScript changed, one at a time, under a time budget
#   - Python lint when matching Python files changed
# Exit 2 with the reason on stderr => Claude keeps working and fixes it. Exit 0 => Claude may stop.
#
# Cheap by design: Stop fires on EVERY response, so this script
#   (a) exits immediately if it already blocked once this turn (stop_hook_active),
#   (b) exits if nothing changed vs the default branch,
#   (c) caches a signature of the working tree and skips when the last passing check covered it.
# Portable: works with GNU coreutils and stock macOS (no GNU timeout / sha1sum / xargs -d required).

set -u
INPUT=$(cat)
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ------------------------------------------------------------- configuration ----
# Set these in the plugin's options (/plugin -> dimi -> Configure options); they arrive as
# CLAUDE_PLUGIN_OPTION_<KEY>. Env vars of the same meaning work as a fallback for non-plugin installs.
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-${STOP_DEFAULT_BRANCH:-}}"
TYPECHECK_SCRIPT="${CLAUDE_PLUGIN_OPTION_TYPECHECK_SCRIPT-${STOP_TYPECHECK_SCRIPT:-typecheck}}"   # empty string disables the typecheck gate
TYPECHECK_FALLBACK="${CLAUDE_PLUGIN_OPTION_TYPECHECK_FALLBACK:-${STOP_TYPECHECK_CMD:-}}"
TYPECHECK_BUDGET_S="${CLAUDE_PLUGIN_OPTION_TYPECHECK_BUDGET_S:-${STOP_TYPECHECK_BUDGET_S:-150}}"
PY_LINT_CMD="${CLAUDE_PLUGIN_OPTION_PY_LINT_CMD:-${STOP_PY_LINT_CMD:-ruff check .}}"
PY_DIR_REGEX="${CLAUDE_PLUGIN_OPTION_PY_DIR_REGEX:-${STOP_PY_DIR_REGEX:-\\.py$}}"
PY_LINT_BUDGET_S="${STOP_PY_LINT_BUDGET_S:-120}"
# --------------------------------------------------------------------------------

# ---- portable helpers ----------------------------------------------------------
# Default branch: option > origin/HEAD > main
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
fi
# hash: sha1sum (GNU) > shasum (macOS) > cksum
hash_stdin() {
  if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -c1-40
  elif command -v shasum >/dev/null 2>&1; then shasum -a 1 | cut -c1-40
  else cksum | cut -d' ' -f1; fi
}
# run_with_timeout <seconds> <command string>: GNU timeout > gtimeout > perl alarm > no timeout. Exit 124 on timeout.
run_with_timeout() {
  local secs="$1" cmd="$2"
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" bash -c "$cmd" </dev/null
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" bash -c "$cmd" </dev/null
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'my $s=shift; my $pid=fork; if(!$pid){ setpgrp(0,0); exec @ARGV } $SIG{ALRM}=sub{ kill "TERM", -$pid; waitpid $pid,0; exit 124 }; alarm $s; waitpid $pid,0; exit(($?>>8) & 255)' "$secs" bash -c "$cmd" </dev/null
  else bash -c "$cmd" </dev/null; fi
}
# ------------------------------------------------------------------------------------

BASE=$(git merge-base "origin/$DEFAULT_BRANCH" HEAD 2>/dev/null || git rev-parse HEAD)
CHANGED=$( { git diff --name-only "$BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | grep -v '^\.claude/\.cache/' | sort -u )
[ -z "$CHANGED" ] && exit 0

# Signature of the current tree; skip if the last passing check already covered it.
PROJ_KEY=$(pwd | hash_stdin | cut -c1-12)
STATE_DIR="${CLAUDE_PLUGIN_DATA:-.claude/.cache}/stop-check"; mkdir -p "$STATE_DIR" 2>/dev/null
OK_FILE="$STATE_DIR/$PROJ_KEY.ok"
SIG=$( { git diff "$BASE" 2>/dev/null; printf '%s\n' "$CHANGED" | while IFS= read -r f; do [ -f "$f" ] && cat "$f" 2>/dev/null; done; } | hash_stdin )
if [ -f "$OK_FILE" ] && [ "$(cat "$OK_FILE" 2>/dev/null)" = "$SIG" ]; then
  exit 0
fi

REASONS=""; HARD_FAIL=0
add_reason() { REASONS="${REASONS}\n== $1 ==\n$2\n"; }

# 1. Debug leftovers, by file class (avoids false positives such as Python model.fit())
grep_files() { # <regex> <newline-separated files>
  local re="$1" files="$2" out=""
  [ -z "$files" ] && return 0
  out=$(printf '%s\n' "$files" | while IFS= read -r f; do [ -f "$f" ] && grep -nHE "$re" "$f" 2>/dev/null; done | head -8)
  printf '%s' "$out"
}
JS_TEST_FILES=$(printf '%s\n' "$CHANGED" | grep -E '(\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)$|/__tests__/|/e2e/|/tests?/)' | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
JS_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
PY_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.py$' || true)
LEFT=$( { grep_files '(\.only\(|\bfdescribe\(|\bfit\()' "$JS_TEST_FILES"; echo; grep_files '^\s*debugger\b' "$JS_FILES"; echo; grep_files '\bbreakpoint\(\)' "$PY_FILES"; } | grep -v '^$' | head -8 || true)
if [ -n "$LEFT" ]; then add_reason "Debug leftovers (remove before stopping)" "$LEFT"; HARD_FAIL=1; fi

# 2. Typecheck, scoped to the packages whose TypeScript changed, serially, under a budget
TIMED_OUT=""
TS_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.(ts|tsx)$' || true)
if [ -n "$TS_FILES" ] && [ -n "$TYPECHECK_SCRIPT" ]; then
  PKGS=$(printf '%s\n' "$TS_FILES" | while IFS= read -r f; do
    d=$(dirname "$f")
    while [ "$d" != "." ] && [ "$d" != "/" ] && [ ! -f "$d/package.json" ]; do d=$(dirname "$d"); done
    [ -f "$d/package.json" ] && echo "$d"
  done | sort -u)
  RUNNABLE=$(printf '%s\n' "$PKGS" | while IFS= read -r d; do
    [ -n "$d" ] && jq -e --arg s "$TYPECHECK_SCRIPT" '.scripts[$s] != null' "$d/package.json" >/dev/null 2>&1 && echo "$d"
  done)
  START=$(date +%s)
  if [ -n "$RUNNABLE" ]; then
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      LEFT_S=$(( TYPECHECK_BUDGET_S - ($(date +%s) - START) ))
      if [ "$LEFT_S" -le 0 ]; then TIMED_OUT="$TIMED_OUT $d"; continue; fi
      if [ "$d" = "." ]; then CMD="pnpm run $TYPECHECK_SCRIPT"; else CMD="pnpm --filter ./$d run $TYPECHECK_SCRIPT"; fi
      OUT=$(run_with_timeout "$LEFT_S" "$CMD" 2>&1); RC=$?
      if [ $RC -eq 124 ]; then TIMED_OUT="$TIMED_OUT $d"
      elif [ $RC -ne 0 ]; then add_reason "Typecheck failed in $d: $CMD (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
      fi
    done <<< "$RUNNABLE"
  elif [ -n "$TYPECHECK_FALLBACK" ]; then
    OUT=$(run_with_timeout "$TYPECHECK_BUDGET_S" "$TYPECHECK_FALLBACK" 2>&1); RC=$?
    if [ $RC -eq 124 ]; then TIMED_OUT=" repo"
    elif [ $RC -ne 0 ]; then add_reason "Typecheck failed: $TYPECHECK_FALLBACK (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
    fi
  fi
fi

# 3. Python lint when matching Python changed
if printf '%s\n' "$CHANGED" | grep -qE "$PY_DIR_REGEX"; then
  OUT=$(run_with_timeout "$PY_LINT_BUDGET_S" "$PY_LINT_CMD" 2>&1); RC=$?
  if [ $RC -eq 124 ]; then TIMED_OUT="$TIMED_OUT python-lint"
  elif [ $RC -ne 0 ]; then add_reason "Python lint failed: $PY_LINT_CMD (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
  fi
fi

# 4. Timeouts: ask once, then stop blocking — but only cache as passing when nothing else failed
if [ -n "$TIMED_OUT" ]; then
  add_reason "Check exceeded its time budget for:$TIMED_OUT" "Run it yourself, scoped and one at a time (e.g. pnpm --filter ./<pkg> run $TYPECHECK_SCRIPT), report the result, then continue. Consider an incremental 'tsc -b' setup if this recurs."
  [ $HARD_FAIL -eq 0 ] && printf '%s' "$SIG" > "$OK_FILE"
fi

if [ -n "$REASONS" ]; then
  printf 'Stop gate failed. Fix these before finishing (do not suppress errors or add escape hatches):%b\n' "$REASONS" >&2
  exit 2
fi

printf '%s' "$SIG" > "$OK_FILE"
exit 0
