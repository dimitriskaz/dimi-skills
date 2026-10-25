#!/usr/bin/env bash
# Stop hook: a deterministic gate before Claude ends a turn.
#   - debug leftovers in changed files (.only / fit / fdescribe in JS/TS tests, debugger in JS/TS,
#     breakpoint() in Python, DBG- probe lines left by the debug skill)
#   - typecheck for the packages whose TypeScript changed, one at a time, under a time budget,
#     with the package manager the repo uses (lockfile > packageManager field > first installed)
#   - Python lint when matching Python files changed
# Exit 2 with the reason on stderr => Claude keeps working and fixes it. Exit 0 => Claude may stop.
#
# Cheap by design: Stop fires on EVERY response, so this script
#   (a) exits immediately if it already blocked once this turn (stop_hook_active),
#   (b) exits if nothing changed vs the default branch,
#   (c) caches a signature of the working tree and skips when the last passing check covered it.
# Never blocks on missing tooling: a package manager or linter that is not installed is reported once
# as a systemMessage and the gate is skipped for that check.
# Portable: works with GNU coreutils and stock macOS (no GNU timeout / sha1sum / xargs -d required).
# Requires jq. Without it the stop_hook_active loop breaker cannot be read, so the gate exits 0.

set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ---- portable helpers --------------------------------------------------------------
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

# State lives in the plugin data dir (falls back to .claude/.cache/ for non-plugin installs; gitignore it).
PROJ_KEY=$(pwd | hash_stdin | cut -c1-12)
STATE_DIR="${CLAUDE_PLUGIN_DATA:-.claude/.cache}/stop-check"; mkdir -p "$STATE_DIR" 2>/dev/null
OK_FILE="$STATE_DIR/$PROJ_KEY.ok"

# Remember the first line of Claude's last message, so the SessionEnd note can say what the session was on.
# Written before any early exit below; an empty message leaves the previous value in place.
LAST_LINE=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null | head -n 1 | head -c 200)
[ -n "$LAST_LINE" ] && printf '%s' "$LAST_LINE" > "$STATE_DIR/$PROJ_KEY.last" 2>/dev/null

if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

# ------------------------------------------------------------- configuration ----
# Set these in the plugin's options (/plugin -> dimi -> Configure options); they arrive as
# CLAUDE_PLUGIN_OPTION_<KEY>. Env vars of the same meaning work as a fallback for non-plugin installs.
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-${STOP_DEFAULT_BRANCH:-}}"
TYPECHECK_SCRIPT="${CLAUDE_PLUGIN_OPTION_TYPECHECK_SCRIPT-${STOP_TYPECHECK_SCRIPT-typecheck}}"   # empty or `none` disables the typecheck gate
case "$TYPECHECK_SCRIPT" in none|NONE|None) TYPECHECK_SCRIPT="";; esac
TYPECHECK_FALLBACK="${CLAUDE_PLUGIN_OPTION_TYPECHECK_FALLBACK:-${STOP_TYPECHECK_CMD:-}}"
TYPECHECK_BUDGET_S="${CLAUDE_PLUGIN_OPTION_TYPECHECK_BUDGET_S:-${STOP_TYPECHECK_BUDGET_S:-150}}"
case "$TYPECHECK_BUDGET_S" in ''|*[!0-9]*) TYPECHECK_BUDGET_S=150;; esac                        # non-numeric option → default
PY_LINT_CMD="${CLAUDE_PLUGIN_OPTION_PY_LINT_CMD-${STOP_PY_LINT_CMD-ruff check .}}"               # empty or `none` disables the Python lint
case "$PY_LINT_CMD" in none|NONE|None) PY_LINT_CMD="";; esac
PY_DIR_REGEX="${CLAUDE_PLUGIN_OPTION_PY_DIR_REGEX:-${STOP_PY_DIR_REGEX:-\\.py$}}"
PY_LINT_BUDGET_S="${STOP_PY_LINT_BUDGET_S:-120}"
# --------------------------------------------------------------------------------

# Default branch: option > origin/HEAD > main
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
fi

BASE=$(git merge-base "origin/$DEFAULT_BRANCH" HEAD 2>/dev/null || git rev-parse HEAD)
CHANGED=$( { git diff --name-only "$BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | grep -v '^\.claude/\.cache/' | sort -u )
[ -z "$CHANGED" ] && exit 0

# Signature of the current tree; skip if the last passing check already covered it.
# Files over 1 MB contribute their name only (one find call for all of them), so a large fixture does not slow every Stop.
LARGE=$(printf '%s\n' "$CHANGED" | tr '\n' '\0' | xargs -0 find 2>/dev/null -maxdepth 0 -type f -size +1024k 2>/dev/null || true)
SIG=$( { git diff "$BASE" 2>/dev/null
         printf '%s\n' "$CHANGED" | while IFS= read -r f; do
           [ -f "$f" ] || continue
           if printf '%s\n' "$LARGE" | grep -qxF -- "$f"; then printf '%s large\n' "$f"; else cat "$f" 2>/dev/null; fi
         done; } | hash_stdin )
if [ -f "$OK_FILE" ] && [ "$(cat "$OK_FILE" 2>/dev/null)" = "$SIG" ]; then
  exit 0
fi

# Packages whose typecheck already timed out on this branch are skipped until the branch changes
# ("ask once, then stop blocking" really means once per branch, not once per edit).
BRANCH_NOW=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
TIMEDOUT_FILE="$STATE_DIR/$PROJ_KEY.timedout"
if [ -f "$TIMEDOUT_FILE" ] && [ "$(head -n 1 "$TIMEDOUT_FILE" 2>/dev/null)" != "$BRANCH_NOW" ]; then rm -f "$TIMEDOUT_FILE"; fi
already_timed_out() { [ -f "$TIMEDOUT_FILE" ] && tail -n +2 "$TIMEDOUT_FILE" | grep -qxF -- "$1"; }
mark_timed_out() { [ -f "$TIMEDOUT_FILE" ] || printf '%s\n' "$BRANCH_NOW" > "$TIMEDOUT_FILE"; printf '%s\n' "$1" >> "$TIMEDOUT_FILE"; }

REASONS=""; HARD_FAIL=0; SKIPPED=""
add_reason() { REASONS="${REASONS}\n== $1 ==\n$2\n"; }
add_skipped() { SKIPPED="${SKIPPED}${SKIPPED:+; }$1"; }

# 1. Debug leftovers, by file class (avoids false positives such as Python model.fit())
grep_files() { # <regex> <newline-separated files>
  local re="$1" files="$2" out=""
  [ -z "$files" ] && return 0
  out=$(printf '%s\n' "$files" | while IFS= read -r f; do [ -f "$f" ] && grep -nHE "$re" "$f" 2>/dev/null; done | head -8)
  printf '%s' "$out"
}
# Test files only: a helper under e2e/ or tests/ may legitimately call something.only(); a *.test.* or *.spec.* file may not.
JS_TEST_FILES=$(printf '%s\n' "$CHANGED" | grep -E '(\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)$|/__tests__/[^/]+\.(ts|tsx|js|jsx|mjs|cjs)$)' || true)
JS_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' || true)
PY_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.py$' || true)
CODE_FILES=$(printf '%s\n' "$JS_FILES" "$PY_FILES" | grep -v '^$' || true)
LEFT=$( { grep_files '(\.only\(|\bfdescribe\(|\bfit\()' "$JS_TEST_FILES"; echo
          grep_files '^\s*debugger\b' "$JS_FILES"; echo
          grep_files '\bbreakpoint\(\)' "$PY_FILES"; echo
          grep_files '\bDBG-[A-Za-z0-9_-]+' "$CODE_FILES"; } | grep -v '^$' | head -8 || true)
if [ -n "$LEFT" ]; then add_reason "Debug leftovers (remove before stopping)" "$LEFT"; HARD_FAIL=1; fi

# 2. Typecheck, scoped to the packages whose TypeScript changed, serially, under a budget
# Package manager: nearest lockfile walking up from the package > root package.json "packageManager" > first installed.
pkg_manager() { # <package dir relative to the repo root>
  local cur="$1" pm=""
  while :; do
    if [ -f "$cur/pnpm-lock.yaml" ]; then echo pnpm; return; fi
    if [ -f "$cur/yarn.lock" ]; then echo yarn; return; fi
    if [ -f "$cur/package-lock.json" ] || [ -f "$cur/npm-shrinkwrap.json" ]; then echo npm; return; fi
    if [ -f "$cur/bun.lockb" ] || [ -f "$cur/bun.lock" ]; then echo bun; return; fi
    if [ "$cur" = "." ] || [ "$cur" = "/" ]; then break; fi
    cur=$(dirname "$cur")
  done
  pm=$(jq -r '.packageManager // empty' package.json 2>/dev/null | sed 's/@.*//')
  if [ -n "$pm" ]; then echo "$pm"; return; fi
  for pm in pnpm npm yarn bun; do if command -v "$pm" >/dev/null 2>&1; then echo "$pm"; return; fi; done
  echo npm
}
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
      PM=$(pkg_manager "$d")
      if ! command -v "$PM" >/dev/null 2>&1; then add_skipped "typecheck in $d ($PM is not installed)"; continue; fi
      if already_timed_out "$d"; then add_skipped "typecheck in $d (timed out earlier on this branch; run it yourself)"; continue; fi
      LEFT_S=$(( TYPECHECK_BUDGET_S - ($(date +%s) - START) ))
      if [ "$LEFT_S" -le 0 ]; then TIMED_OUT="$TIMED_OUT $d"; mark_timed_out "$d"; continue; fi
      CMD="cd '$d' && $PM run $TYPECHECK_SCRIPT"
      OUT=$(run_with_timeout "$LEFT_S" "$CMD" 2>&1); RC=$?
      if [ $RC -eq 124 ]; then TIMED_OUT="$TIMED_OUT $d"; mark_timed_out "$d"
      elif [ $RC -eq 127 ]; then add_skipped "typecheck in $d (command not found: $(printf '%s\n' "$OUT" | tail -1 | head -c 120))"
      elif [ $RC -ne 0 ]; then add_reason "Typecheck failed in $d: $CMD (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
      fi
    done <<< "$RUNNABLE"
  elif [ -n "$TYPECHECK_FALLBACK" ]; then
    FB_BIN=${TYPECHECK_FALLBACK%% *}
    if ! command -v "$FB_BIN" >/dev/null 2>&1; then add_skipped "typecheck fallback ($FB_BIN is not installed)"
    elif already_timed_out "repo"; then add_skipped "typecheck fallback (timed out earlier on this branch; run it yourself)"
    else
      OUT=$(run_with_timeout "$TYPECHECK_BUDGET_S" "$TYPECHECK_FALLBACK" 2>&1); RC=$?
      if [ $RC -eq 124 ]; then TIMED_OUT=" repo"; mark_timed_out "repo"
      elif [ $RC -eq 127 ]; then add_skipped "typecheck fallback (command not found)"
      elif [ $RC -ne 0 ]; then add_reason "Typecheck failed: $TYPECHECK_FALLBACK (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
      fi
    fi
  fi
fi

# 3. Python lint when changed Python files match the Python path regex
if [ -n "$PY_LINT_CMD" ] && [ -n "$PY_FILES" ] && printf '%s\n' "$PY_FILES" | grep -qE "$PY_DIR_REGEX"; then
  PY_BIN=${PY_LINT_CMD%% *}
  if ! command -v "$PY_BIN" >/dev/null 2>&1; then add_skipped "python lint ($PY_BIN is not installed)"
  else
    OUT=$(run_with_timeout "$PY_LINT_BUDGET_S" "$PY_LINT_CMD" 2>&1); RC=$?
    if [ $RC -eq 124 ]; then TIMED_OUT="$TIMED_OUT python-lint"
    elif [ $RC -eq 127 ]; then add_skipped "python lint (command not found)"
    elif [ $RC -ne 0 ]; then add_reason "Python lint failed: $PY_LINT_CMD (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
    fi
  fi
fi

# 4. Timeouts: ask once per branch, then stop blocking — but only cache as passing when nothing else failed
if [ -n "$TIMED_OUT" ]; then
  add_reason "Check exceeded its time budget for:$TIMED_OUT" "Run it yourself, scoped and one at a time (e.g. cd <pkg> && <pm> run $TYPECHECK_SCRIPT), report the result, then continue. This check is skipped for the rest of this branch. Consider an incremental 'tsc -b' setup if this recurs."
  [ $HARD_FAIL -eq 0 ] && printf '%s' "$SIG" > "$OK_FILE"
fi

if [ -n "$REASONS" ]; then
  printf 'Stop gate failed. Fix these before finishing (do not suppress errors or add escape hatches):%b\n' "$REASONS" >&2
  [ -n "$SKIPPED" ] && printf 'Skipped (tool missing or timed out earlier): %s\n' "$SKIPPED" >&2
  exit 2
fi

printf '%s' "$SIG" > "$OK_FILE"
# Skipped checks are reported once per tree signature as a warning, never as a block.
if [ -n "$SKIPPED" ]; then
  jq -cn --arg m "dimi stop-check skipped: $SKIPPED. Install the tool, or set the option to 'none' to silence this." '{systemMessage: $m}'
fi
exit 0
