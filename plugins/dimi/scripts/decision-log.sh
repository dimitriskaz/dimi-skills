#!/usr/bin/env bash
# Append-only decision log for the decision-log skill, one TSV row per decision, outside the working tree.
#   decision-log.sh start <goal and contract>            a run's first row
#   decision-log.sh add <phase> <decision> <why> <evidence> <result>
#   decision-log.sh done <met|not met: why> <evidence>    the run's closing row (phase done)
#   decision-log.sh read [n|all]                          this run's rows (since the last start row), the last n rows, or every row
#   decision-log.sh path                                  the file's path
#   decision-log.sh commit <dir in the repo>              copy it into the repository (the author commits)
# The file is <top>/.claude/.cache/decisions/<project key>.tsv: the skill runs this from the model's shell, which has no
# CLAUDE_PLUGIN_DATA, and the session banner (a hook) reads the same fixed path; LOCAL_STATE_RE keeps it out of every diff.
. "$(dirname "$0")/lib.sh"
T=$(top) || { echo "not a git repository" >&2; exit 1; }
cd "$T" || exit 1
F="$T/.claude/.cache/decisions/$(project_key).tsv"

# cell <text>: one TSV cell: tabs and newlines become spaces; a leading = + - @ (a spreadsheet formula) is quoted.
cell() { [ -n "$1" ] || { printf -- '-'; return; }; printf '%s' "$1" | tr '\t\n\r' '   ' | sed -E "s/^([=+@-])/'\1/"; }
row() {
  mkdir -p "$(dirname "$F")" || exit 1
  [ -s "$F" ] || printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' > "$F"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(cell "$1")" "$(cell "$2")" "$(cell "$3")" "$(cell "$4")" "$(cell "$5")" >> "$F"
}
case "${1-}" in
  start) row start "${2-}" "run start on $(branch_name) at $(git rev-parse --short HEAD 2>/dev/null)" "" open; echo "$F" ;;
  done) [ $# -ge 3 ] || { echo "usage: decision-log.sh done '<met | not met: why>' <evidence>" >&2; exit 2; }
        v=$(printf '%s' "$2" | tr 'A-Z' 'a-z' | tr -s '[:space:]' ' ')
        case "$v" in met|met[[:space:][:punct:]]*) V=green ;; 'not met'|'not met'[[:space:][:punct:]]*) V=open ;; *) echo "done: the verdict starts with 'met' or 'not met'" >&2; exit 2 ;; esac
        row done "done check: $2" "" "$3" "$V"; echo "logged row $(($(grep -c '' "$F") - 1))" ;;
  add) [ $# -ge 6 ] || { echo "usage: decision-log.sh add <phase> <decision> <why> <evidence> <result>" >&2; exit 2; }; row "$2" "$3" "$4" "$5" "$6"; echo "logged row $(($(grep -c '' "$F") - 1))" ;;
  read) [ -f "$F" ] || { echo "no decision log for this repository"; exit 0; }
        # default: this run, i.e. the rows from the last start row; a number: the last n rows; all: everything
        case "${2-}" in all) SEL='NR > 1' ;; '') SEL='last' ;; *[!0-9]*|0) echo "read: n must be a count or all" >&2; exit 2 ;; *) SEL="NR > 1 && NR > $(grep -c '' "$F") - $2" ;; esac
        # long cells are truncated on read only; the file keeps them whole
        pick() { { if [ "$SEL" = last ]; then awk -F'\t' 'NR == 1 { next } $2 == "start" { buf = "" } { buf = buf $0 "\n" } END { printf "%s", buf }' "$F"; else awk "$SEL" "$F"; fi; } | awk -F'\t' -v OFS='\t' '{ for (i = 1; i <= NF; i++) if (length($i) > 160) $i = substr($i, 1, 157) "..." } 1'; }
        if command -v column >/dev/null 2>&1; then { head -1 "$F"; pick; } | column -s "$(printf '\t')" -t; else head -1 "$F"; pick; fi ;;
  path) echo "$F" ;;
  commit) [ -f "$F" ] || { echo "no decision log to commit" >&2; exit 1; }
          D="${2:?usage: decision-log.sh commit <dir in the repo>}"
          case "$D" in /*|-*|*..*|.claude/.cache*|.claude/worktrees*) echo "commit: give a directory inside the repository, relative to its top (not the hook state under .claude/.cache)" >&2; exit 2 ;; esac
          mkdir -p "$T/$D" && D=$(cd "$T/$D" && pwd -P) || exit 1
          case "$D" in "$T"/*) ;; *) echo "commit: $D is outside the repository" >&2; exit 2 ;; esac
          cp "$F" "$D/decisions-$(safe_name "$(branch_name)").tsv" && echo "copied to $D/decisions-$(safe_name "$(branch_name)").tsv (stage and commit it yourself)" ;;
  *) echo "usage: decision-log.sh start|add|done|read|path|commit … (see the header of this file)" >&2; exit 2 ;;
esac
