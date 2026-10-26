#!/usr/bin/env bash
# State for /dimi:refresh-harness: remote, working tree and today's date. Always exits 0.
. "$(dirname "$0")/../lib.sh"

echo "Repository remote: $(git remote get-url origin 2>/dev/null || echo 'no git remote')"
echo
echo "Working tree:"
if [ -n "$(top)" ]; then
  s=$(git status --short 2>/dev/null | head -20)
  if [ -n "$s" ]; then printf '%s\n' "$s"; else echo "clean"; fi
else
  echo "not a git repository"
fi
echo
echo "Today (UTC): $(date -u +%Y-%m-%d 2>/dev/null || echo unknown)"
exit 0
