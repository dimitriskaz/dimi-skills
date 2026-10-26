#!/usr/bin/env bash
# Shared helpers for the hook scripts, scripts/review.sh and the skill state scripts in state/.
#
# Skills call a script from a `!` injection or a bash block as one plain command, e.g.
#   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/<skill>.sh '${user_config.a}' '${user_config.b}'`
# pre-approved by `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)` in the skill's allowed-tools: inline compound
# shell fails Claude Code's injection check, and a command that expands a variable cannot be pre-approved.
# An option that is not configured arrives as the literal text `${user_config.<key>}`, so every value starting
# with `$` is treated as unset. State scripts must always exit 0: a failing injection aborts the skill.

# ---- options -------------------------------------------------------------------------------------------
# opt <value> [default]: the value, or the default when it is empty or an unsubstituted placeholder.
opt() { case "${1-}" in ''|'$'*) printf '%s' "${2-}" ;; *) printf '%s' "$1" ;; esac; }

# resolve_db <value>: configured default branch > origin/HEAD > main.
resolve_db() {
  local db; db=$(opt "${1-}")
  [ -z "$db" ] && db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  printf '%s' "${db:-main}"
}

# resolve_tr <value>: the ticket regex as POSIX ERE ('' when set to none); `\d` is read as [0-9] (grep -E has no \d).
resolve_tr() {
  local tr; tr=$(opt "${1-}" '[A-Z][A-Z0-9]+-[0-9]+')
  case "$tr" in none|NONE|None) tr='' ;; esac
  printf '%s' "$tr" | sed 's/\\d/[0-9]/g'
}

# resolve_marker <value>: the demo-only marker, DEMO-ONLY by default.
resolve_marker() { opt "${1-}" DEMO-ONLY; }

# valid_ere <regex>: true when grep -E accepts it (an invalid user regex must not read as "nothing found").
valid_ere() { printf 'x\n' | grep -E -- "$1" >/dev/null 2>&1; [ $? -le 1 ]; }

# ---- repository ----------------------------------------------------------------------------------------
# top: the repository top level, or nothing outside a git repository.
top() { git rev-parse --show-toplevel 2>/dev/null; }

# branch_name: the current branch (also on an unborn branch), else detached-<sha>, else nothing.
branch_name() {
  git symbolic-ref --short HEAD 2>/dev/null && return 0
  local s; s=$(git rev-parse --short=12 HEAD 2>/dev/null) && printf 'detached-%s\n' "$s"
}

# safe_name <branch>: the branch as one file-name component, one-to-one and valid on Windows too
# (% first, then / \ : * ? " < > |), so feat/a-b and feat-a/b never share a report.
safe_name() {
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's|/|%2F|g' -e 's|\\|%5C|g' -e 's/:/%3A/g' -e 's/\*/%2A/g' \
    -e 's/?/%3F/g' -e 's/"/%22/g' -e 's/</%3C/g' -e 's/>/%3E/g' -e 's/|/%7C/g'
}

# hash_stdin: a hex hash of stdin (sha1sum > shasum > cksum: GNU, stock macOS, anything).
hash_stdin() {
  if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -c1-40
  elif command -v shasum >/dev/null 2>&1; then shasum -a 1 | cut -c1-40
  else cksum | awk '{ printf "%08x%08x\n", $1, $2 }'; fi
}
# project_key: the name the hooks share for this repository's state files. Run it from the top level.
project_key() { pwd | hash_stdin | cut -c1-12; }

# with_timeout <seconds> <cmd…>: GNU timeout > gtimeout > perl alarm > no timeout. Exit 124 on timeout;
# the perl path kills the whole process group, so a package manager's children die with it.
with_timeout() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'my $s=shift; my $pid=fork; if(!$pid){ setpgrp(0,0); exec @ARGV } $SIG{ALRM}=sub{ kill "TERM", -$pid; waitpid $pid,0; exit 124 }; alarm $s; waitpid $pid,0; exit(($?>>8) & 255)' "$s" "$@"
  else "$@"; fi
}

# ---- the change ----------------------------------------------------------------------------------------
# NEVER_DUMP_RE: untracked files whose content never enters a diff or a scan output (listed by name only).
# LOCAL_STATE_RE: paths the tooling itself leaves in the repo (hook state, agent worktrees under .claude/worktrees/),
# never part of the change.
LOCAL_STATE_RE='^\.claude/(\.cache|worktrees)/'

NEVER_DUMP_RE='(^|/)\.env(\.|$)|(^|/)\.(npmrc|netrc|pypirc|pgpass)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)|(^|/)credentials|\.(pem|key|p12|pfx|jks|keystore|kdbx|tfstate|sqlite|sqlite3|db|dump|bak)$|\.tfstate\.backup$|storageState|(^|/)\.auth/|^\.claude/\.cache/'

# git_diff <args…>: git diff in a fixed, parseable format whatever the user's config (paths unquoted, a/ b/
# prefixes, no colour, no external diff tool).
git_diff() { git -c core.quotePath=false -c diff.noprefix=false -c diff.mnemonicPrefix=false -c color.ui=never diff --no-color --no-ext-diff "$@"; }

# change_diff <base>: the whole change against <base> — committed, staged, unstaged and untracked — as one
# diff, run from the top level. Untracked files join through a throwaway index (git add -N), never the real one;
# NEVER_DUMP_RE files and binaries are left out.
change_diff() {
  local base="$1" ix rc
  ix=$(mktemp 2>/dev/null) || { git_diff "$base"; return; }
  rm -f "$ix"; cp "$(git rev-parse --git-path index)" "$ix" 2>/dev/null   # no index yet: git starts an empty one
  git ls-files --others --exclude-standard 2>/dev/null | grep -vE -- "$NEVER_DUMP_RE" | grep -vE -- "$LOCAL_STATE_RE" \
    | GIT_INDEX_FILE="$ix" git add -N --pathspec-from-file=- 2>/dev/null
  GIT_INDEX_FILE="$ix" git_diff "$base"; rc=$?
  rm -f "$ix"; return $rc
}

# diff_added_lines: a unified diff on stdin -> "path:line:text" for each added line (file line numbers).
# Headers are read only between hunks: inside one, the @@ counts say how many lines belong to it, so an added
# line whose text starts with "++ " or "--- " is never mistaken for a file header.
diff_added_lines() {
  awk '
    function hunk(h,  a) { split(h, a, ","); n = substr(a[1], 2) + 0; nl = (2 in a) ? a[2] + 0 : 1 }
    ol > 0 || nl > 0 {
      c = substr($0, 1, 1)
      if (c == "+") { if (f != "") print f ":" n ":" substr($0, 2); n++; nl-- }
      else if (c == "-") ol--
      else if (c == " " || $0 == "") { n++; ol--; nl-- }
      next
    }
    /^\+\+\+ / { f = substr($0, 5); sub(/\t.*$/, "", f); if (f == "/dev/null") f = ""; else sub(/^b\//, "", f); next }
    /^@@ / { split($2, o, ","); ol = (2 in o) ? o[2] + 0 : 1; hunk($3) }'
}

# diff_new_files: NUL-separated paths of the files a unified diff (stdin) adds; binary and empty files included.
diff_new_files() {
  awk '
    function hunk(h,  a) { split(h, a, ","); nl = (2 in a) ? a[2] + 0 : 1 }
    ol > 0 || nl > 0 { c = substr($0, 1, 1); if (c == "+") nl--; else if (c == "-") ol--; else if (c == " " || $0 == "") { ol--; nl-- }; next }
    /^diff --git / { if (nf && p != "") print p; nf = 0; p = ""; d = substr($0, 12); h = int((length(d) - 1) / 2); if (substr(d, 1, 2) == "a/") p = substr(d, h + 4); next }
    /^new file mode/ { nf = 1; next }
    /^\+\+\+ / { if (nf) { p = substr($0, 5); sub(/\t.*$/, "", p); sub(/^b\//, "", p) }; next }
    /^@@ / { split($2, o, ","); ol = (2 in o) ? o[2] + 0 : 1; hunk($3) }
    END { if (nf && p != "") print p }' | tr '\n' '\0'
}

# tree_fingerprint <base>: a short hash of the content of every path the change touches against <base>
# (committed, staged, unstaged or untracked; deleted paths count as deleted). Content only, so committing
# reviewed work leaves it unchanged and any later edit changes it. One git process hashes all files.
tree_fingerprint() {
  local t; t=$(top) || return 0
  ( cd "$t" || exit 0
    L=$( { git -c core.quotePath=false diff --name-only --no-renames "$1" 2>/dev/null
           git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null; } | grep -vE -- "$LOCAL_STATE_RE" | sort -u )
    E=$(printf '%s\n' "$L" | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)
    { if [ -n "$E" ]; then printf '%s\n' "$E" | git hash-object --stdin-paths 2>/dev/null | paste -d' ' - /dev/fd/3 3<<EOF
$E
EOF
      fi
      printf '%s\n' "$L" | while IFS= read -r f; do [ -n "$f" ] && [ ! -f "$f" ] && printf 'deleted %s\n' "$f"; done
    } | hash_stdin | cut -c1-12 )
}

# secret_hits <base>: secret-shaped added lines of the whole change ("path:line:<redacted>"), at most 20.
secret_hits() {
  local t; t=$(top) || return 0
  ( cd "$t" && change_diff "$1" | diff_added_lines | grep -iE -- "$SECRET_RE" | redact | cut -c1-160 | cap 20 )
}

# ---- scans over "path:line:text" lines -----------------------------------------------------------------
# SECRET_RE: secret-shaped tokens; the only copy.
SECRET_RE='(-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? ?PRIVATE KEY.*|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|sk_(live|test)_[A-Za-z0-9]{16,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|npm_[A-Za-z0-9]{36}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|Bearer [A-Za-z0-9._~+/-]{20,}|[A-Za-z][A-Za-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]@]+@|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}(\.[A-Za-z0-9_-]+)?|(api[_-]?key|secret|password|passwd|token|private[_-]?key|access[_-]?key)["'"'"']?[[:space:]]*[=:][[:space:]]*("[^"]{8,}"|'"'"'[^'"'"']{8,}'"'"'|[A-Za-z0-9/+_=.~-]{8,}))'

# redact: mask secret-shaped lines ("path:line:text"). A line with `key = value` / `key: value` keeps the
# text up to the first = or : and loses the rest; any other line keeps only its path and line number.
redact() {
  sed -E -e '/^[^:]*:[0-9]+:[^=:]*[=:]/!s/^([^:]*:[0-9]+:).*$/\1<redacted>/' \
         -e 's/^([^:]*:[0-9]+:[^=:]*[=:][[:space:]]*).{4,}$/\1<redacted>/' \
         -e "s#$SECRET_RE#<redacted>#g"   # '#' as delimiter: SECRET_RE contains / and | but never #
}

# cap <n>: the first n lines of stdin, then a count of the rest.
cap() { awk -v n="$1" 'NR <= n { print } END { if (NR > n) print "… and " NR - n " more" }'; }

# NOTE_RE: session narrative and working notes that do not belong in code comments (tidy, commit-push-pr).
NOTE_RE='as discussed|per the (ticket|workbook|customer|call|review)|for now|temporary|hack|quick fix|claude|assistant|session|step [0-9]|plan\.md|handoff|added (as part of|for|in)|updated (on|to)|changed (to|from)|20[0-9]{2}-[0-9]{2}-[0-9]{2}|see (above|below)|this (function|method|class|file) (does|is|handles|returns)'
# Comment-shaped text: a marker at the start or after whitespace (not the // of a URL, nor #fff).
COMMENT_RE='^[^:]*:[0-9]+:(.*[[:space:]])?(//|/\*|<!--|#([[:space:]]|$))|^[^:]*:[0-9]+:[[:space:]]*\*|"""'"|'''"

# note_lines <ticket regex> [customer terms]: comment lines on stdin ("path:line:text") that carry a ticket key
# (case-sensitive), a customer term or session narrative (case-insensitive). Candidates, not verdicts.
note_lines() {
  local tr="${1-}" terms="${2-}" re="$NOTE_RE" c
  [ -n "$terms" ] && re="$terms|$re"
  c=$(grep -E -- "$COMMENT_RE")
  [ -n "$c" ] || return 0
  { [ -n "$tr" ] && printf '%s\n' "$c" | grep -E -- "$tr"; printf '%s\n' "$c" | grep -iE -- "($re)"; } | awk '!seen[$0]++'
}
