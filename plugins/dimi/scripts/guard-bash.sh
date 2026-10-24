#!/usr/bin/env bash
# PreToolUse (Bash): block a few commands that are cheap to prevent and expensive to undo.
# Exit 2 + reason on stderr => the command does not run and Claude sees why.
#
# Blocks:
#   - force pushes and any push to the default branch
#   - --no-verify on commit/push
#   - `git add -A` / `git add .` / `git add --all` (stage explicit paths so stray files never ride along)
#   - commits whose message lacks the ticket key

set -u
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# ------------------------------------------------------------- configuration ----
# Plugin options (CLAUDE_PLUGIN_OPTION_*) first, env vars as fallback, then defaults.
TICKET_REGEX="${CLAUDE_PLUGIN_OPTION_TICKET_REGEX:-${GUARD_TICKET_REGEX:-[A-Z][A-Z0-9]+-[0-9]+}}"
PROTECTED_BRANCHES="${CLAUDE_PLUGIN_OPTION_PROTECTED_BRANCHES:-${GUARD_PROTECTED_BRANCHES:-main|master|production}}"
# The repo's default branch is always protected, whatever it is called.
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')}"
[ -n "$DEFAULT_BRANCH" ] && PROTECTED_BRANCHES="$PROTECTED_BRANCHES|$DEFAULT_BRANCH"
# --------------------------------------------------------------------------------

block() { printf 'Blocked by dimi guard-bash: %s\n' "$1" >&2; exit 2; }

# Force push / push to protected branch — match only within the `git push ...` arguments (up to the next ; | &)
PUSH_ARGS=$(printf '%s' "$CMD" | grep -oE '\bgit\s+push\b[^;|&]*' | head -1 || true)
if [ -n "$PUSH_ARGS" ]; then
  printf '%s' "$PUSH_ARGS" | grep -qE -- '(^|\s)(--force|--force-with-lease|-f|-[a-zA-Z]*f[a-zA-Z]*)(\s|$|=)' \
    && block "force push. Rebase locally and push normally, or ask the author to run it."
  # explicit target: `git push <remote> <branch>` or `HEAD:<branch>` or `<src>:<branch>` where <branch> is protected
  printf '%s' "$PUSH_ARGS" | grep -qE "(\s[A-Za-z0-9_.-]+\s+(refs/heads/)?($PROTECTED_BRANCHES)(\s|$)|:(refs/heads/)?($PROTECTED_BRANCHES)(\s|$))" \
    && block "push to a protected branch ($PROTECTED_BRANCHES). Push the feature branch and open a PR."
  # implicit target: on a protected branch with no refspec
  if ! printf '%s' "$PUSH_ARGS" | grep -qE '\s[A-Za-z0-9_.-]+\s+[A-Za-z0-9_./:-]+(\s|$)'; then
    CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    printf '%s' "$CUR" | grep -qE "^($PROTECTED_BRANCHES)$" && block "push from a protected branch ($CUR). Work on a feature branch."
  fi
fi

# --no-verify
printf '%s' "$CMD" | grep -qE '\bgit\s+(commit|push)\b.*--no-verify' \
  && block "--no-verify skips the repo's git hooks. Fix the failing hook instead."

# Sweeping adds
printf '%s' "$CMD" | grep -qE '\bgit\s+add\s+(-A\b|--all\b|\.(\s|$)|-u\b)' \
  && block "sweeping 'git add'. Stage explicit paths (git add path/one path/two) so untracked scratch files, evidence for other specs and .env files never get committed."

# Commit message without ticket key
if printf '%s' "$CMD" | grep -qE '\bgit\s+commit\b' && printf '%s' "$CMD" | grep -qE '\s(-[a-zA-Z]*m[a-zA-Z]*|--message)(\s|=)'; then
  printf '%s' "$CMD" | grep -qE "$TICKET_REGEX" \
    || block "commit message has no ticket key matching /$TICKET_REGEX/. Use: type(KEY): description"
fi

exit 0
