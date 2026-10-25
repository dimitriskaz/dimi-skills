#!/usr/bin/env bash
# PreToolUse (Bash): block a few commands that are cheap to prevent and expensive to undo.
# Exit 2 + reason on stderr => the command does not run and Claude sees why.
#
# Blocks:
#   - force pushes (-f, --force, --force-with-lease, +refspec), --all / --mirror / --branches pushes
#   - any push or delete that targets a protected branch, including the implicit forms
#     (`git push`, `git push origin`, `git push -u origin`, `git push origin HEAD`/`@`/`HEAD~0`, `--repo=`)
#   - `git rebase` and `git pull --rebase` while on the demo branch, or a rebase that names it
#   - --no-verify / -n on commit, --no-verify on push
#   - sweeping staging: `git add -A|--all|-u|--update|.|./|:/|*|..`, `git stage …`, `git commit -a|--all`
#   - commits whose -m message lacks the ticket key (set ticket_regex to `none` to disable)
#   - `git -C <dir>` / `--git-dir` / `--work-tree` with any of the above subcommands (target cannot be verified)
#
# A seatbelt, not a security boundary: a target hidden in a variable, `xargs`, `eval` or `sh -c` is not seen.
# Quoted strings that contain whitespace are ignored for command detection, so a commit message or an echo
# that mentions `git push origin main` is not treated as a push.
# Portable to bash 3.2 (macOS): no `read -a`, no empty-array expansion without a guard.
# Requires jq. Without it the guard cannot read the command and exits 0 (no guard).

set -u
set -f   # no globbing: `git add *` must be seen as the literal `*`
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

# ------------------------------------------------------------- configuration ----
# Plugin options (CLAUDE_PLUGIN_OPTION_*) first, env vars as fallback, then defaults.
TICKET_REGEX="${CLAUDE_PLUGIN_OPTION_TICKET_REGEX-${GUARD_TICKET_REGEX-[A-Z][A-Z0-9]+-[0-9]+}}"
case "$TICKET_REGEX" in none|NONE|None) TICKET_REGEX="";; esac
PROTECTED_BRANCHES="${CLAUDE_PLUGIN_OPTION_PROTECTED_BRANCHES:-${GUARD_PROTECTED_BRANCHES:-main|master|production}}"
# The repo's default branch is always protected, whatever it is called (added once).
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')}"
DEMO_BRANCH="${CLAUDE_PLUGIN_OPTION_DEMO_BRANCH:-${GUARD_DEMO_BRANCH:-}}"
# --------------------------------------------------------------------------------

block() { printf 'Blocked by dimi guard-bash: %s\n' "$1" >&2; exit 2; }
current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || true; }
is_protected() { # exact name match against the pipe-separated list (not a regex)
  local b="$1" p; local IFS='|'
  for p in $PROTECTED_BRANCHES; do [ "$p" = "$b" ] && return 0; done
  [ -n "$DEFAULT_BRANCH" ] && [ "$DEFAULT_BRANCH" = "$b" ] && return 0
  return 1
}
protected_list() { if [ -n "$DEFAULT_BRANCH" ] && ! is_protected_listed "$DEFAULT_BRANCH"; then printf '%s|%s' "$PROTECTED_BRANCHES" "$DEFAULT_BRANCH"; else printf '%s' "$PROTECTED_BRANCHES"; fi; }
is_protected_listed() { local b="$1" p; local IFS='|'; for p in $PROTECTED_BRANCHES; do [ "$p" = "$b" ] && return 0; done; return 1; }

# blank_quoted: quoted strings with whitespace become empty quotes (""), single-word quotes lose their quotes.
# The result is used only to find and tokenise git commands; messages are read from the original.
blank_quoted() {
  local s="$1" out="" buf="" q="" c i n
  n=${#s}
  for ((i = 0; i < n; i++)); do
    c="${s:$i:1}"
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then
        case "$buf" in *[[:space:]]*) out="$out\"\"";; *) out="$out$buf";; esac
        q=""; buf=""
      else buf="$buf$c"; fi
    else
      case "$c" in
        '"'|"'") q="$c"; buf="" ;;
        '\') i=$((i + 1)); out="$out${s:$i:1}" ;;
        *) out="$out$c" ;;
      esac
    fi
  done
  [ -n "$q" ] && out="$out$buf"
  printf '%s' "$out"
}
CMD_S=$(blank_quoted "$CMD")

# A git invocation with optional global options before the subcommand.
GIT_RE='\bgit([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+'
strip_git_prefix() { printf '%s' "$1" | sed -E 's/^git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+//'; }
has_repo_override() { printf '%s' "$1" | grep -qE -- '^git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+(-C[[:space:]]|--git-dir|--work-tree)|^git[[:space:]]+(-C[[:space:]]|--git-dir|--work-tree)'; }

# ---- git push -----------------------------------------------------------------------
check_push() { # args after `push`
  local t skip=0 force=0 all=0 delete=0 repo=0 dd=0 cur r src dst i
  local pos; pos=()
  for t in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [ "$dd" = 1 ]; then pos+=("$t"); continue; fi
    case "$t" in
      --) dd=1 ;;
      -f|--force|--force-with-lease|--force-with-lease=*) force=1 ;;
      --all|--mirror|--branches) all=1 ;;
      -d|--delete) delete=1 ;;
      --repo=*) repo=1 ;;
      --repo) repo=1; skip=1 ;;
      -o|--push-option|--receive-pack|--exec) skip=1 ;;        # option with a separate value
      --*) ;;                                                    # other long option (or --opt=value)
      -*) case "$t" in *f*) force=1 ;; esac ;;                  # bundled short options, e.g. -uf
      *) pos+=("$t") ;;
    esac
  done
  [ "$force" = 1 ] && block "force push. Rebase locally and push normally, or ask the author to run it."
  [ "$all" = 1 ] && block "push --all/--mirror/--branches would push protected branches ($(protected_list)). Push one feature branch."

  cur=$(current_branch)
  local n=${#pos[@]} first=0
  [ "$repo" = 0 ] && first=1                                    # pos[0] is the remote unless --repo was given
  if [ "$n" -le "$first" ]; then
    # No refspec (`git push`, `git push origin`, `git push -u origin`, `git push --repo=o`): git pushes the current branch.
    is_protected "$cur" && block "push from a protected branch ($cur). Work on a feature branch."
    return 0
  fi
  for ((i = first; i < n; i++)); do
    r="${pos[$i]}"
    case "$r" in +*) block "force push (+refspec). Rebase locally and push normally." ;; esac
    case "$r" in *:*) src="${r%%:*}"; dst="${r#*:}" ;; *) src="$r"; dst="$r" ;; esac
    [ -z "$dst" ] && dst="$src"                                  # `:branch` deletes branch
    case "$dst" in refs/tags/*|refs/for/*) continue ;; esac
    dst="${dst#refs/heads/}"
    case "$dst" in @|HEAD|HEAD~0|HEAD^0|@~0|@^0) dst="$cur" ;; esac
    if is_protected "$dst"; then
      if [ "$delete" = 1 ] || [ -z "$src" ]; then block "delete of a protected branch ($dst)."; fi
      block "push to a protected branch ($dst; protected: $(protected_list)). Push the feature branch and open a PR."
    fi
  done
  return 0
}

# ---- git add / stage ----------------------------------------------------------------
check_add() { # args after `add`/`stage`
  local t dd=0 update=0 paths=0
  for t in "$@"; do
    if [ "$dd" = 1 ]; then paths=$((paths + 1)); check_sweeping_path "$t"; continue; fi
    case "$t" in
      --) dd=1 ;;
      --all) block "sweeping 'git add --all'. Stage explicit paths (git add path/one path/two) so untracked scratch files, evidence for other specs and .env files never get committed." ;;
      --update) update=1 ;;
      --*) ;;
      -*) case "$t" in *A*) block "sweeping 'git add -A'. Stage explicit paths (git add path/one path/two)." ;; esac
          case "$t" in *u*) update=1 ;; esac ;;
      *) paths=$((paths + 1)); check_sweeping_path "$t" ;;
    esac
  done
  [ "$update" = 1 ] && [ "$paths" = 0 ] && block "sweeping 'git add -u' with no path. Stage explicit paths."
  return 0
}
check_sweeping_path() {
  case "$1" in
    .|./|./.|..|../*|:/|:/.|:/*|'*')
      block "sweeping 'git add $1'. Stage explicit paths (git add path/one path/two) so untracked scratch files, evidence for other specs and .env files never get committed." ;;
  esac
}

# ---- git commit ---------------------------------------------------------------------
check_commit() { # args after `commit` (quotes blanked)
  local t has_m=0
  for t in "$@"; do
    case "$t" in
      --no-verify) block "--no-verify skips the repo's git hooks. Fix the failing hook instead." ;;
      --all) block "commit --all stages every tracked change. Stage explicit paths, then commit." ;;
      --message|--message=*) has_m=1 ;;
      --*) ;;
      -u*|-S*) ;;                                                 # -u<mode>, -S<keyid>: values glued to the flag
      -*) case "$t" in *n*) block "-n (--no-verify) skips the repo's git hooks. Fix the failing hook instead." ;; esac
          case "$t" in *a*) block "commit -a stages every tracked change. Stage explicit paths, then commit." ;; esac
          case "$t" in *m*) has_m=1 ;; esac ;;
    esac
  done
  if [ "$has_m" = 1 ] && [ -n "$TICKET_REGEX" ]; then
    # Read the -m/--message values from the ORIGINAL command (flattened so a heredoc message is one string).
    local flat msgs
    flat=$(printf '%s' "$CMD" | tr '\n' ' ')
    msgs=$(printf '%s' "$flat" | grep -oE -- "(^|[[:space:]])(-[a-zA-Z]*m|--message)(=|[[:space:]]*)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" || true)
    [ -z "$msgs" ] && msgs="$flat"
    printf '%s' "$msgs" | grep -qE -- "$TICKET_REGEX" \
      || block "commit message has no ticket key matching /$TICKET_REGEX/. Use: type(KEY): description (or set the ticket_regex option to 'none')."
  fi
  return 0
}

# ---- git rebase / pull --rebase on the shared demo branch -------------------------------
check_rebase() { # args after `rebase`
  [ -z "$DEMO_BRANCH" ] && return 0
  local t last="" cur; cur=$(current_branch)
  for t in "$@"; do case "$t" in -*) ;; *) last="$t" ;; esac; done
  if [ "$cur" = "$DEMO_BRANCH" ] || [ "$last" = "$DEMO_BRANCH" ]; then
    block "rebase of the demo branch ($DEMO_BRANCH). It is shared: merge the default branch in instead (/dimi:poc sync)."
  fi
  return 0
}
check_pull() { # args after `pull`; $PULL_CFG set when -c pull.rebase=true was given
  [ -z "$DEMO_BRANCH" ] && return 0
  local t rebase=${PULL_CFG:-0}
  for t in "$@"; do case "$t" in -r|--rebase|--rebase=*) rebase=1 ;; esac; done
  [ "$rebase" = 1 ] && [ "$(current_branch)" = "$DEMO_BRANCH" ] \
    && block "pull --rebase on the demo branch ($DEMO_BRANCH). It is shared: use git pull --ff-only, or merge (/dimi:poc sync)."
  return 0
}

# ---- walk every git segment (up to the next ; | & or newline) ---------------------------
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  has_repo_override "$seg" && block "git -C/--git-dir/--work-tree with ${seg#git } — the target repository cannot be verified. Run git from the project root."
  PULL_CFG=0; printf '%s' "$seg" | grep -qE -- '-c[[:space:]]+pull\.rebase=(true|1)' && PULL_CFG=1
  rest=$(strip_git_prefix "$seg")
  sub=${rest%%[[:space:]]*}
  args=${rest#"$sub"}
  # shellcheck disable=SC2086
  set -- $args
  case "$sub" in
    push)       check_push "$@" ;;
    add|stage)  check_add "$@" ;;
    commit)     check_commit "$@" ;;
    rebase)     check_rebase "$@" ;;
    pull)       check_pull "$@" ;;
  esac
  printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])--no-verify([[:space:]]|$)' && [ "$sub" = push ] \
    && block "--no-verify skips the repo's git hooks. Fix the failing hook instead."
done <<EOF
$(printf '%s\n' "$CMD_S" | grep -oE -- "${GIT_RE}(push|add|stage|commit|rebase|pull)\b[^;|&]*" || true)
EOF

exit 0
