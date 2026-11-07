#!/usr/bin/env bash
# Append-only decision log for the decision-log skill, one TSV row per decision, outside the working tree.
#   decision-log.sh start <goal and contract>            a run's first row
#   decision-log.sh add <phase> <decision> <why> <evidence> <result>
#   decision-log.sh read [n]                              the last n rows (default all), aligned
#   decision-log.sh path                                  the file's path
#   decision-log.sh commit <dir in the repo>              copy it into the repository (the author commits)
# The file is ${CLAUDE_PLUGIN_DATA:-<top>/.claude/.cache}/decisions/<project key>.tsv.
. "$(dirname "$0")/lib.sh"
T=$(top) || { echo "not a git repository" >&2; exit 1; }
cd "$T" || exit 1
F="${CLAUDE_PLUGIN_DATA:-$T/.claude/.cache}/decisions/$(project_key).tsv"

# cell <text>: one TSV cell: tabs and newlines become spaces; a leading = + - @ (a spreadsheet formula) is quoted.
cell() { printf '%s' "$1" | tr '\t\n\r' '   ' | sed -E "s/^([=+@-])/'\1/"; }
row() {
  mkdir -p "$(dirname "$F")" || exit 1
  [ -s "$F" ] || printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' > "$F"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(cell "$1")" "$(cell "$2")" "$(cell "$3")" "$(cell "$4")" "$(cell "$5")" >> "$F"
}
case "${1-}" in
  start) row start "${2-}" "run start on $(branch_name) at $(git rev-parse --short HEAD 2>/dev/null)" "" open; echo "$F" ;;
  add) [ $# -ge 6 ] || { echo "usage: decision-log.sh add <phase> <decision> <why> <evidence> <result>" >&2; exit 2; }; row "$2" "$3" "$4" "$5" "$6"; echo "logged row $(($(grep -c '' "$F") - 1))" ;;
  read) [ -f "$F" ] || { echo "no decision log for this repository"; exit 0; }
        if command -v column >/dev/null 2>&1; then { head -1 "$F"; tail -n "${2:-+2}" "$F" | grep -v "^ts$(printf '\t')"; } | column -s "$(printf '\t')" -t
        else head -1 "$F"; tail -n "${2:-+2}" "$F" | grep -v "^ts$(printf '\t')"; fi ;;
  path) echo "$F" ;;
  commit) [ -f "$F" ] || { echo "no decision log to commit" >&2; exit 1; }
          D="$T/${2:?usage: decision-log.sh commit <dir in the repo>}"; mkdir -p "$D" && cp "$F" "$D/decisions-$(safe_name "$(branch_name)").tsv" && echo "copied to $D/decisions-$(safe_name "$(branch_name)").tsv (stage and commit it yourself)" ;;
  *) echo "usage: decision-log.sh start|add|read|path|commit … (see the header of this file)" >&2; exit 2 ;;
esac
