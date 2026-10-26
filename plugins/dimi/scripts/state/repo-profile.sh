#!/usr/bin/env bash
# State for the review skills that read a whole repository (harden-mcp, review-agent): repository files,
# current commit and the client profile. Usage: repo-profile.sh <where the default severities live>.
# Always exits 0.
. "$(dirname "$0")/../lib.sh"

t=$(top)
echo "Repository files:"
if [ -n "$t" ]; then git -C "$t" ls-files 2>/dev/null | head -400; else echo "not a git repository"; fi
echo
if [ -z "$t" ]; then c='not a git repository'; else c=$(git -C "$t" rev-parse -q --verify --short HEAD 2>/dev/null) || c='no commits yet'; fi
echo "Current commit: $c"
echo
echo "Client profile:"
p="${t:-$(pwd)}/.claude/fde-client-profile.md"
if [ -f "$p" ]; then cat "$p"; else echo "No client profile found. Use the default severities in the ${1:-checklist}."; fi
exit 0
