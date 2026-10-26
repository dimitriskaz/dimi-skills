#!/usr/bin/env bash
# State for the poc and port skills.
# Usage: poc.sh <demo_branch> <demo_marker> <default_branch> [secrets]
#   no mode : the "Current state" lines the skill injects
#   secrets : secret-shaped added lines in the working tree vs HEAD and in untracked files (redacted)
# Always exits 0: a failing injection aborts the skill.
. "$(dirname "$0")/../lib.sh"

DEMO=$(opt "${1-}")
M=$(resolve_marker "${2-}")
DB=$(resolve_db "${3-}")

if [ "${4-}" = secrets ]; then
  if [ -z "$(top)" ]; then echo "not a git repository"; exit 0; fi
  HITS=$(secret_hits HEAD)
  if [ -n "$HITS" ]; then printf '%s\n' "$HITS"; else echo "no secret-shaped lines"; fi
  exit 0
fi

BR=$(branch_name); BR=${BR:-not a git repo}
LEDGER=no
if [ -n "$DEMO" ]; then
  if git cat-file -e "$DEMO:docs/poc-ledger.md" 2>/dev/null || git cat-file -e "origin/$DEMO:docs/poc-ledger.md" 2>/dev/null; then
    LEDGER=yes
  fi
fi

echo "- Top: $(top || echo 'not a git repository')"
echo "- Branch: $BR"
echo "- Demo branch: ${DEMO:-unset}"
echo "- Marker: $M"
echo "- Default branch: $DB"
echo "- Ledger on the demo branch: $LEDGER"
exit 0
