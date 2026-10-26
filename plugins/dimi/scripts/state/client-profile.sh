#!/usr/bin/env bash
# State for /dimi:client-profile: whether this is the dimi-skills repository, the existing profile and
# the repository files. Always exits 0.
. "$(dirname "$0")/../lib.sh"

t=$(top)
root=${t:-$(pwd)}
plugin=no
m="$t/.claude-plugin/marketplace.json"
if [ -n "$t" ] && [ -f "$m" ]; then
  if command -v jq >/dev/null 2>&1; then n=$(jq -r '.name // empty' "$m" 2>/dev/null)
  else n=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$m" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)"$/\1/'); fi  # first "name" is the top-level one
  if [ "$n" = dimi-skills ]; then plugin=yes; fi
fi
case "$(git -C "$root" remote get-url origin 2>/dev/null)" in *dimi-skills*) plugin=yes ;; esac
echo "Plugin repository (dimi-skills): $plugin"
echo
echo "Existing profile:"
if [ -f "$root/.claude/fde-client-profile.md" ]; then cat "$root/.claude/fde-client-profile.md"; else echo "None yet."; fi
echo
echo "Profile tracked or ignored by git:"
if [ -z "$t" ]; then echo "not a git repository"
elif git -C "$t" ls-files --error-unmatch .claude/fde-client-profile.md >/dev/null 2>&1; then echo "tracked"
elif git -C "$t" check-ignore -q .claude/fde-client-profile.md 2>/dev/null; then echo "ignored"
else echo "neither"; fi
echo
echo "Repository files:"
if [ -n "$t" ]; then git -C "$t" ls-files 2>/dev/null | head -300; else echo "not a git repository"; fi
exit 0
