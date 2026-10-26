#!/usr/bin/env bash
# Stop hook: a deterministic gate before Claude ends a turn.
#   - debug leftovers in changed files (.only / fit / fdescribe in JS/TS tests, debugger in JS/TS,
#     breakpoint() in Python, DBG- probe lines left by the debug skill)
#   - typecheck for the packages whose TypeScript changed, one at a time, under a time budget,
#     with the package manager the repo uses (nearest lockfile or packageManager field > first installed)
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
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P) || exit 0   # before any cd: $0 may be relative

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
PROJ_DIR=$(pwd -P)   # user-configured commands without {files} run here, as they always have
# Work from the top level: git diff prints top-level-relative paths, so a project opened in a
# monorepo subfolder would otherwise fail every [ -f "$f" ] and check only untracked files.
cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 0
# Stay inside the hook's own 300 s timeout (hooks.json): past it Claude Code cancels the hook and
# discards its output, so nothing is cached and every later turn would wait the full 300 s again.
HOOK_LIMIT_S="${STOP_HOOK_LIMIT_S:-270}"; case "$HOOK_LIMIT_S" in ''|*[!0-9]*) HOOK_LIMIT_S=270;; esac
DEADLINE=$(( $(date +%s) + HOOK_LIMIT_S ))

# ---- portable helpers (hash_stdin, project_key, with_timeout, change_diff …: scripts/lib.sh) -----
. "$HERE/lib.sh" 2>/dev/null || exit 0
run_with_timeout() { with_timeout "$1" bash -c "$2" </dev/null; }   # <seconds> <command string>
# within_deadline <seconds>: the budget, lowered to what is left before DEADLINE.
within_deadline() { local want="$1" left=$(( DEADLINE - $(date +%s) )); [ "$left" -lt "$want" ] && want=$left; echo "$want"; }
# ------------------------------------------------------------------------------------

# State lives in the plugin data dir (falls back to .claude/.cache/ for non-plugin installs; gitignore it).
PROJ_KEY=$(project_key)
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
PY_LINT_DEFAULT='ruff check --force-exclude {files}'   # {files} kept outside ${x-…}: a literal } would end it; --force-exclude: ruff ignores the repo's excludes for named files otherwise
PY_LINT_CMD="${CLAUDE_PLUGIN_OPTION_PY_LINT_CMD-${STOP_PY_LINT_CMD-$PY_LINT_DEFAULT}}"            # empty or `none` disables; {files} = the changed Python files
case "$PY_LINT_CMD" in none|NONE|None) PY_LINT_CMD="";; esac
PY_DIR_REGEX="${CLAUDE_PLUGIN_OPTION_PY_DIR_REGEX:-${STOP_PY_DIR_REGEX:-\\.py$}}"
PY_LINT_BUDGET_S="${STOP_PY_LINT_BUDGET_S:-120}"
# --------------------------------------------------------------------------------

# Default branch: option > origin/HEAD > main
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
fi

# Base: origin's default branch > the local default branch (no remote yet) > HEAD (uncommitted work only)
BASE=$(git merge-base "origin/$DEFAULT_BRANCH" HEAD 2>/dev/null || git merge-base "$DEFAULT_BRANCH" HEAD 2>/dev/null || git rev-parse HEAD 2>/dev/null)
CHANGED=$( { git -c core.quotePath=false diff --name-only "$BASE" 2>/dev/null; git -c core.quotePath=false ls-files --others --exclude-standard; } | grep -v '^\.claude/\.cache/' | sort -u )
[ -z "$CHANGED" ] && exit 0

# Signature of the current tree (content of every changed path, hashed by one git process); skip if the
# last passing check already covered it.
SIG=$(tree_fingerprint "$BASE")
if [ -f "$OK_FILE" ] && [ "$(cat "$OK_FILE" 2>/dev/null)" = "$SIG" ]; then
  exit 0
fi

# Packages whose typecheck already timed out on this branch are skipped until the branch changes
# ("ask once, then stop blocking" really means once per branch, not once per edit).
BRANCH_NOW=$(branch_name); BRANCH_NOW=${BRANCH_NOW:-?}
TIMEDOUT_FILE="$STATE_DIR/$PROJ_KEY.timedout"
if [ -f "$TIMEDOUT_FILE" ] && [ "$(head -n 1 "$TIMEDOUT_FILE" 2>/dev/null)" != "$BRANCH_NOW" ]; then rm -f "$TIMEDOUT_FILE"; fi
already_timed_out() { [ -f "$TIMEDOUT_FILE" ] && tail -n +2 "$TIMEDOUT_FILE" | grep -qxF -- "$1"; }
mark_timed_out() { [ -f "$TIMEDOUT_FILE" ] || printf '%s\n' "$BRANCH_NOW" > "$TIMEDOUT_FILE"; printf '%s\n' "$1" >> "$TIMEDOUT_FILE"; }
# timed_out <key> <label> <seconds it was given> <its own budget>: a check that used up its own budget asks
# once and is skipped for the rest of the branch; one cut short by the overall Stop limit (other checks took
# the time) is only skipped for this tree and runs again after the next edit.
timed_out() {
  if [ "$3" -lt "$4" ]; then add_skipped "$2 (cut off by the ${HOOK_LIMIT_S}s Stop limit; it runs again after the next edit)"
  else TIMED_OUT="$TIMED_OUT $1"; mark_timed_out "$1"; fi
}

REASONS=""; HARD_FAIL=0; SKIPPED=""
add_reason() { REASONS="${REASONS}
== $1 ==
$2
"; }
add_skipped() { SKIPPED="${SKIPPED}${SKIPPED:+; }$1"; }

# Regexes here are POSIX ERE only (no \b, \s, \w): stock macOS grep is not GNU grep.
# 1. Debug leftovers, by file class (avoids false positives such as Python model.fit()), in the lines
# this branch added only: a pre-existing match in a touched file is not this change's to fix, and
# blocking on it would block every turn.
# The lines this change added, committed or not, untracked files included: one git process for the whole tree.
ADDED=$(change_diff "$BASE" | diff_added_lines)
# grep_added <path regex> <text regex>: "file:line:text" for added lines of matching files whose text matches.
grep_added() {
  [ -n "$ADDED" ] || return 0
  # patterns go through ENVIRON, not awk -v, which would eat their backslashes
  printf '%s\n' "$ADDED" | PRE="$1" RE="$2" awk '{ i = index($0, ":"); f = substr($0, 1, i - 1); r = substr($0, i + 1); j = index(r, ":"); t = substr(r, j + 1); if (f ~ ENVIRON["PRE"] && t ~ ENVIRON["RE"]) print }' | head -8
}
# Test files only: a helper under e2e/ or tests/ may legitimately call something.only(); a *.test.* or *.spec.* file may not.
JS_TEST='(\.(test|spec)\.(ts|tsx|js|jsx|mjs|cjs)|/__tests__/[^/]+\.(ts|tsx|js|jsx|mjs|cjs))$'
JS='\.(ts|tsx|js|jsx|mjs|cjs)$'
PY_FILES=$(printf '%s\n' "$CHANGED" | grep -E '\.py$' || true)
LEFT=$( { grep_added "$JS_TEST" '(\.only\(|(^|[^[:alnum:]_$])fdescribe\(|(^|[^.[:alnum:]_$])fit\()'
          grep_added "$JS" '^[[:space:]]*debugger([^[:alnum:]_$]|$)'
          grep_added '\.py$' '(^|[^[:alnum:]_])breakpoint\(\)'
          grep_added '\.(ts|tsx|js|jsx|mjs|cjs|py)$' '(^|[^[:alnum:]_])DBG-[A-Za-z0-9_-]+'; } | head -8 || true)
if [ -n "$LEFT" ]; then add_reason "Debug leftovers (remove before stopping)" "$LEFT"; HARD_FAIL=1; fi

# 2. Typecheck, scoped to the packages whose TypeScript changed, serially, under a budget
# Package manager: walking up from the package, the first lockfile or package.json "packageManager" > first installed.
pkg_manager() { # <package dir relative to the repo root>
  local cur="$1" pm=""
  while :; do
    if [ -f "$cur/pnpm-lock.yaml" ]; then echo pnpm; return; fi
    if [ -f "$cur/yarn.lock" ]; then echo yarn; return; fi
    if [ -f "$cur/package-lock.json" ] || [ -f "$cur/npm-shrinkwrap.json" ]; then echo npm; return; fi
    if [ -f "$cur/bun.lockb" ] || [ -f "$cur/bun.lock" ]; then echo bun; return; fi
    pm=$(jq -r '.packageManager // empty' "$cur/package.json" 2>/dev/null | sed 's/@.*//')
    if [ -n "$pm" ]; then echo "$pm"; return; fi
    if [ "$cur" = "." ] || [ "$cur" = "/" ]; then break; fi
    cur=$(dirname "$cur")
  done
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
      OWN_S=$(( TYPECHECK_BUDGET_S - ($(date +%s) - START) )); LEFT_S=$(within_deadline "$OWN_S")
      if [ "$OWN_S" -le 0 ]; then add_skipped "typecheck in $d (other packages used the ${TYPECHECK_BUDGET_S}s typecheck budget; it runs again after the next edit)"; continue; fi
      if [ "$LEFT_S" -le 0 ]; then timed_out "$d" "typecheck in $d" "$LEFT_S" "$OWN_S"; continue; fi
      CMD="cd '$d' && $PM run $TYPECHECK_SCRIPT"
      OUT=$(run_with_timeout "$LEFT_S" "$CMD" 2>&1); RC=$?
      if [ $RC -eq 124 ]; then timed_out "$d" "typecheck in $d" "$LEFT_S" "$OWN_S"
      elif [ $RC -eq 127 ]; then add_skipped "typecheck in $d (command not found: $(printf '%s\n' "$OUT" | tail -1 | head -c 120))"
      elif [ $RC -ne 0 ]; then add_reason "Typecheck failed in $d: $CMD (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
      fi
    done <<< "$RUNNABLE"
  elif [ -n "$TYPECHECK_FALLBACK" ]; then
    FB_BIN=${TYPECHECK_FALLBACK%% *}
    if ! command -v "$FB_BIN" >/dev/null 2>&1; then add_skipped "typecheck fallback ($FB_BIN is not installed)"
    elif already_timed_out "repo"; then add_skipped "typecheck fallback (timed out earlier on this branch; run it yourself)"
    elif LEFT_S=$(within_deadline "$TYPECHECK_BUDGET_S"); [ "$LEFT_S" -le 0 ]; then timed_out repo "typecheck fallback" "$LEFT_S" "$TYPECHECK_BUDGET_S"
    else
      OUT=$(run_with_timeout "$LEFT_S" "cd $(printf "'%s'" "$PROJ_DIR") && $TYPECHECK_FALLBACK" 2>&1); RC=$?
      if [ $RC -eq 124 ]; then timed_out repo "typecheck fallback" "$LEFT_S" "$TYPECHECK_BUDGET_S"
      elif [ $RC -eq 127 ]; then add_skipped "typecheck fallback (command not found)"
      elif [ $RC -ne 0 ]; then add_reason "Typecheck failed: $TYPECHECK_FALLBACK (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
      fi
    fi
  fi
fi

# 3. Python lint when changed Python files match the Python path regex.
# `{files}` in the command becomes the changed, existing Python files that match (quoted), so lint
# errors that predate this branch elsewhere in the repo do not block every turn.
PY_MATCH=$(printf '%s\n' "$PY_FILES" | grep -E "$PY_DIR_REGEX" | while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done)
if [ -n "$PY_LINT_CMD" ] && [ -n "$PY_MATCH" ]; then
  PY_BIN=${PY_LINT_CMD%% *}
  N_PY=$(printf '%s\n' "$PY_MATCH" | grep -c .)
  PY_ARGS=$(printf '%s\n' "$PY_MATCH" | while IFS= read -r f; do printf "'%s' " "$(printf '%s' "$f" | sed "s/'/'\\\\''/g")"; done)
  case "$PY_LINT_CMD" in
    *'{files}'*)   # named files, from the top level; past ~30 KB of arguments (Windows caps a command line at 32 KB) lint the repo instead
      if [ "${#PY_ARGS}" -gt 30000 ]; then PY_ARGS=.; fi
      PRE=${PY_LINT_CMD%%\{files\}*}; POST=${PY_LINT_CMD#*\{files\}}   # split, not ${x//…/…}: its replacement treats & and quotes differently across bash versions
      PY_RUN="$PRE$PY_ARGS$POST"; PY_SHOW="$PRE<$N_PY changed .py files>$POST" ;;
    *) PY_RUN="cd $(printf "'%s'" "$PROJ_DIR") && $PY_LINT_CMD"; PY_SHOW=$PY_LINT_CMD ;;   # as configured, from the project dir
  esac
  if ! command -v "$PY_BIN" >/dev/null 2>&1; then add_skipped "python lint ($PY_BIN is not installed)"
  elif already_timed_out "python-lint"; then add_skipped "python lint (timed out earlier on this branch; run it yourself)"
  elif LEFT_S=$(within_deadline "$PY_LINT_BUDGET_S"); [ "$LEFT_S" -le 0 ]; then timed_out python-lint "python lint" "$LEFT_S" "$PY_LINT_BUDGET_S"
  else
    OUT=$(run_with_timeout "$LEFT_S" "$PY_RUN" 2>&1); RC=$?
    if [ $RC -eq 124 ]; then timed_out python-lint "python lint" "$LEFT_S" "$PY_LINT_BUDGET_S"
    elif [ $RC -eq 127 ]; then add_skipped "python lint (command not found)"
    elif [ $RC -ne 0 ]; then add_reason "Python lint failed: $PY_SHOW (last 40 lines)" "$(printf '%s\n' "$OUT" | tail -40)"; HARD_FAIL=1
    fi
  fi
fi

# 4. Timeouts: ask once per branch, then stop blocking — but only cache as passing when nothing else failed
if [ -n "$TIMED_OUT" ]; then
  add_reason "Check exceeded its time budget for:$TIMED_OUT" "Run it yourself, scoped and one at a time (typecheck: cd <pkg> && <pm> run $TYPECHECK_SCRIPT; python-lint: ${PY_SHOW:-$PY_LINT_CMD}), report the result, then continue. This check is skipped for the rest of this branch. Consider an incremental 'tsc -b' setup if a typecheck timeout recurs."
  [ $HARD_FAIL -eq 0 ] && printf '%s' "$SIG" > "$OK_FILE"
fi

if [ -n "$REASONS" ]; then
  printf 'Stop gate failed. Fix these before finishing (do not suppress errors or add escape hatches):%s\n' "$REASONS" >&2
  [ -n "$SKIPPED" ] && printf 'Skipped (tool missing or timed out earlier): %s\n' "$SKIPPED" >&2
  exit 2
fi

printf '%s' "$SIG" > "$OK_FILE"
# Skipped checks are reported once per tree signature as a warning, never as a block.
if [ -n "$SKIPPED" ]; then
  jq -cn --arg m "dimi stop-check skipped: $SKIPPED. Install a missing tool, or set its option to 'none' to silence that skip." '{systemMessage: $m}'
fi
exit 0
