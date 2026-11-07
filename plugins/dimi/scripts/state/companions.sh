#!/usr/bin/env bash
# Which of the recommended third-party plugins are installed, and where their skill files are, so a dimi skill can
# fold their passes in (pr-self-review stage 5, commit-push-pr's PR body, debug's perf path). Reads the plugin cache
# (CLAUDE_CODE_PLUGIN_CACHE_DIR, else ~/.claude/plugins) and the skills directories; never runs anything of theirs.
# Called as  bash companions.sh  — prints one line per companion; always exits 0.
. "$(dirname "$0")/../lib.sh"

ROOT="${CLAUDE_CODE_PLUGIN_CACHE_DIR:-$HOME/.claude/plugins}"
T=$(top)

# newest <plugin entry name>: the newest cached version directory of that plugin under any marketplace, skipping
# versions an update or uninstall orphaned; nothing when it is not installed.
newest() {
  local d best=
  for d in "$ROOT"/cache/*/"$1"/*/; do
    [ -d "$d" ] || continue
    [ -e "$d/.orphaned_at" ] && continue
    if [ -z "$best" ] || [ "$d" -nt "$best" ]; then best="$d"; fi
  done
  [ -n "$best" ] && printf '%s' "${best%/}"
}
# first_file <path>…: the first path that exists, else nothing.
first_file() { local p; for p in "$@"; do [ -f "$p" ] && { printf '%s' "$p"; return 0; }; done; return 0; }

echo "Recommended plugins (install commands: /dimi:help):"

P=$(newest ponytail)
if [ -n "$P" ]; then
  echo "- ponytail: installed at $P"
  echo "    review rubric: $(first_file "$P/skills/ponytail-review/SKILL.md" "$P/commands/ponytail-review.md")"
  echo "    writing stance: $(first_file "$P/skills/ponytail/SKILL.md")"
else
  echo "- ponytail: not installed"
fi

S=$(newest pstack)
if [ -n "$S" ]; then
  echo "- pstack: installed at $S"
  echo "    unslop (prose): $(first_file "$S/skills/unslop/SKILL.md")"
  echo "    benchmark-checklist: $(first_file "$S/skills/benchmark-checklist/SKILL.md")"
  echo "    show-me-your-work (decision log): $(first_file "$S/skills/show-me-your-work/SKILL.md")"
else
  echo "- pstack: not installed"
fi

K=$(newest cursor-team-kit)
TN=$(first_file "${K:+$K/skills/thermo-nuclear-code-quality-review/SKILL.md}" \
                "$HOME/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md" \
                "${T:+$T/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md}")
if [ -n "$K" ]; then echo "- cursor-team-kit: installed at $K"
elif [ -n "$TN" ]; then echo "- cursor-team-kit: thermo-nuclear review only, as a skills-directory copy"
else echo "- cursor-team-kit: not installed"; fi
[ -n "$TN" ] && echo "    thermo-nuclear rubric: $TN"
[ -n "$K" ] && echo "    deslop: $(first_file "$K/skills/deslop/SKILL.md")"
exit 0
