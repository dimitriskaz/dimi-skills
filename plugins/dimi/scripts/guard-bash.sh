#!/usr/bin/env bash
# PreToolUse (Bash): block a few commands that are cheap to prevent and expensive to undo.
# Exit 2 + reason on stderr => the command does not run and Claude sees why.
#
# Blocks:
#   - force pushes (-f, --force, --force-with-lease, +refspec), --all / --mirror / --branches pushes
#   - any push or delete that targets a protected branch, including the implicit forms
#     (`git push`, `git push origin`, `git push -u origin`, `git push origin HEAD`/`@`/`HEAD~0`, `--repo=`)
#   - `git rebase` and `git pull --rebase` while on the demo branch, or a rebase that names it
#   - each of these judged on the branch an earlier `git checkout <branch>` / `git switch <branch>` in the same command
#     moves to (`git checkout main && git push`)
#   - --no-verify / -n on commit, --no-verify on push
#   - sweeping staging: `git add -A|--all|-u|--update|.|./|:/|*|..`, `git stage …`, `git commit -a|--all`
#   - commits whose message lacks the ticket key (set ticket_regex to `none` to disable): the -m/--message value,
#     a -F/--file message (the file is read; `-F -` reads the heredoc or pipe in the same command); a -F file that
#     cannot be read is blocked. `--amend`, `-c`/`-C <commit>` and a bare `git commit` (editor) reuse an existing
#     message or are interactive, so they are not checked
#   - `git -C <relative or hidden dir>` / `--git-dir` / `--work-tree` with any of the above subcommands (target cannot
#     be verified); `git -C /absolute/dir` is checked as if run in that directory
#   - staging a file that must never be committed (env files, key and credential files, `*.tfstate`, Playwright auth
#     state, `.claude/.cache/`, agent worktrees: STAGE_BLOCK_RE below), and `git add -f/--force` (it exists to add
#     ignored files); `.env.example`-style templates are allowed
#   - losing uncommitted work, judged against the tree as it is now so a clean tree is never blocked (option
#     guard_working_tree, default on): `git reset --hard` with uncommitted changes; `git checkout -- <paths>`,
#     `git checkout .`, `git restore <paths>` (not `--staged` alone) when those paths carry unsaved edits; `git clean -f`
#     when its dry run would delete something; `git stash drop`/`clear`; `git branch -D` of a branch not merged into HEAD
#     or the default branch, or of a protected branch; `rm` of a tracked file with unsaved edits and `rm -r` of a
#     directory holding untracked or edited files. A literal `cd <dir>` earlier in the command moves the checks there;
#     a `cd` to a variable makes the rm checks skip (target unknown). `git worktree remove --force` is not checked:
#     the port skill removes its own integration worktree that way.
#
# A seatbelt, not a security boundary: a target hidden in a variable, `xargs`, `eval`, `sh -c` or a heredoc fed
# to a shell (`bash <<EOF`) is not seen.
# Quoted strings that contain whitespace are ignored for command detection, so a commit message or an echo
# that mentions `git push origin main` is not treated as a push.
# Portable to bash 3.2 (macOS): no `read -a`, no empty-array expansion without a guard.
# Reads its input with jq, python3 or node (scripts/lib.sh json_get); with none of them it exits 0 (no guard).

set -u
set -f   # no globbing: `git add *` must be seen as the literal `*`
. "$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/lib.sh" 2>/dev/null || exit 0   # json_get
json_tool || exit 0
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | json_get tool_input command)
[ -z "$CMD" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

# ------------------------------------------------------------- configuration ----
# Plugin options (CLAUDE_PLUGIN_OPTION_*) first, env vars as fallback, then defaults.
TICKET_REGEX="${CLAUDE_PLUGIN_OPTION_TICKET_REGEX-${GUARD_TICKET_REGEX-[A-Z][A-Z0-9]+-[0-9]+}}"
case "$TICKET_REGEX" in none|NONE|None) TICKET_REGEX="";; esac
TICKET_REGEX=$(printf '%s' "$TICKET_REGEX" | sed 's/\\d/[0-9]/g')   # grep -E has no \d: PROJ-\d+ would match nothing
PROTECTED_BRANCHES="${CLAUDE_PLUGIN_OPTION_PROTECTED_BRANCHES:-${GUARD_PROTECTED_BRANCHES:-main|master|production}}"
# The repo's default branch is always protected, whatever it is called (added once).
DEFAULT_BRANCH="${CLAUDE_PLUGIN_OPTION_DEFAULT_BRANCH:-${GUARD_DEFAULT_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')}}"
DEMO_BRANCH="${CLAUDE_PLUGIN_OPTION_DEMO_BRANCH:-${GUARD_DEMO_BRANCH:-}}"
GUARD_WORK=1
case "${CLAUDE_PLUGIN_OPTION_GUARD_WORKING_TREE:-${GUARD_WORKING_TREE:-1}}" in 0|false|no|off|False|FALSE|No|NO|Off|OFF) GUARD_WORK=0 ;; esac
# --------------------------------------------------------------------------------

# STAGE_BLOCK_RE: paths `git add` must never stage. NEVER_DUMP_RE (lib.sh) with two differences: a file named
# `credentials` only without a source extension (src/credentials.ts is code; ~/.aws/credentials and credentials.json
# are not), and the STAGE_ALLOW_RE templates (`.env.example` and friends) allowed, since they are committed on purpose.
STAGE_BLOCK_RE='(^|/)\.env(\.|$)|(^|/)\.(npmrc|netrc|pypirc|pgpass)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$|(^|/)credentials(\.json|\.ya?ml|\.toml|\.ini|\.txt)?$|\.(pem|key|p12|pfx|jks|keystore|kdbx|tfstate|sqlite|sqlite3|db|dump|bak)$|\.tfstate\.backup$|storageState|(^|/)\.auth/|^\.claude/(\.cache|worktrees)/'
STAGE_ALLOW_RE='(^|/)\.env\.(example|sample|template|dist)$'

block() { printf 'Blocked by dimi guard-bash: %s\n' "$1" >&2; exit 2; }
# SWITCHED: the branch an earlier `git checkout`/`git switch` in the same command moves to (`git checkout main && git push`).
SWITCHED=""
# CWD: where the current segment runs — the project dir, moved by a literal `cd <dir>` earlier in the command;
# `?` after a `cd` whose target cannot be read (a variable, a substitution), which skips the rm checks.
CWD=$(pwd -P 2>/dev/null || pwd)
# g: git in the directory the segment acts on (`git -C /abs` first, else CWD).
g() { if [ -n "${GDIR:-}" ]; then git -C "$GDIR" "$@"; elif [ "$CWD" != "?" ]; then git -C "$CWD" "$@"; else git "$@"; fi; }
current_branch() { if [ -z "${GDIR:-}" ] && [ -n "$SWITCHED" ]; then printf '%s\n' "$SWITCHED"; return; fi; g rev-parse --abbrev-ref HEAD 2>/dev/null || true; }
# dirty <paths…>: true when any of the paths has unstaged or staged changes (exit 1 from diff --quiet; 128 = outside
# the repository or no repository, which counts as clean).
dirty() { g diff --quiet -- "$@" 2>/dev/null; [ $? -eq 1 ] && return 0; g diff --cached --quiet -- "$@" 2>/dev/null; [ $? -eq 1 ]; }
# untracked <paths…>: the untracked, not-ignored files under the paths (nothing outside a repository).
untracked() { g ls-files --others --exclude-standard -- "$@" 2>/dev/null; }
# dirty_list <paths…>: the changed paths, for the message.
dirty_list() { { g diff --name-only -- "$@" 2>/dev/null; g diff --cached --name-only -- "$@" 2>/dev/null; } | sort -u | head -5 | paste -sd' ' -; }
is_protected() { # name or shell glob (release/*) match against the pipe-separated list (not a regex)
  local b="$1" p; local IFS='|'
  # shellcheck disable=SC2254
  for p in $PROTECTED_BRANCHES; do case "$b" in $p) return 0 ;; esac; done
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
# strip_heredocs: drop heredoc bodies (from the line after `<<WORD` / `<<-'WORD'` up to the WORD line), so a
# commit message fed through `git commit -F - <<EOF` that mentions `git push origin main` is not read as a push.
# Fail closed: when no closing WORD line follows (`1<<n`, `echo "a <<b"`), the held lines are checked after all.
# `<<<` here-strings are not heredocs.
strip_heredocs() {
  printf '%s\n' "$1" | awk '
    d != "" { held = held $0 "\n"; t = $0; sub(/^\t+/, "", t); if (t == d) { d = ""; held = "" }; next }
    { print
      if (match($0, /(^|[^<])<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
        d = substr($0, RSTART, RLENGTH); sub(/^[^<]*<<-?[[:space:]]*["\047]?/, "", d); sub(/["\047]$/, "", d); held = "" } }
    END { if (d != "") printf "%s", held }'
}
CMD_S=$(blank_quoted "$(strip_heredocs "$CMD")")

# A git invocation with optional global options before the subcommand.
# POSIX ERE only (macOS grep has no \b): "git" at the start or after a non-word character, so /usr/bin/git and
# (git count but mygit and gitk do not. The one leading character is stripped from each match below.
GIT_RE='(^|[^[:alnum:]_-])git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+'
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
  local t dd=0 update=0 paths=0 skip=0
  for t in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [ "$dd" = 1 ]; then paths=$((paths + 1)); check_sweeping_path "$t"; check_never_stage "$t"; continue; fi
    case "$t" in
      --) dd=1 ;;
      --all) block "sweeping 'git add --all'. Stage explicit paths (git add path/one path/two) so untracked scratch files, evidence for other specs and .env files never get committed." ;;
      --update) update=1 ;;
      --force) block "'git add --force' stages a file the repository ignores. If it really belongs in the change, un-ignore it; ignored files are ignored for a reason (secrets, state, evidence)." ;;
      --chmod|--pathspec-from-file|--pathspec-file-nul) skip=1 ;;   # option with a separate value
      --*) ;;
      -*) case "$t" in *A*) block "sweeping 'git add -A'. Stage explicit paths (git add path/one path/two)." ;; esac
          case "$t" in *f*) block "'git add -f' stages a file the repository ignores. If it really belongs in the change, un-ignore it; ignored files are ignored for a reason (secrets, state, evidence)." ;; esac
          case "$t" in *u*) update=1 ;; esac ;;
      *) paths=$((paths + 1)); check_sweeping_path "$t"; check_never_stage "$t" ;;
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
check_never_stage() { # one explicit path: never a secret, key, state or auth file
  local p="$1"
  p=${p#./}; case "$p" in :\(*\)*) p=${p#*\)} ;; esac   # drop a leading ./ and a :(top)-style magic prefix
  printf '%s' "$p" | grep -qE -- "$STAGE_ALLOW_RE" && return 0
  printf '%s' "$p" | grep -qE -- "$STAGE_BLOCK_RE" \
    && block "'git add $1' would stage a file that must never be committed (env, key, credential, state or auth file). Leave it unstaged; if it holds a secret that was ever committed, rotate it."
  return 0
}

# ---- losing uncommitted work: reset --hard, checkout/restore of edited paths, clean, stash drop, branch -D, rm ------
check_reset() { # args after `reset`
  [ "$GUARD_WORK" = 1 ] || return 0
  local t hard=0; for t in "$@"; do [ "$t" = --hard ] && hard=1; done
  [ "$hard" = 1 ] && dirty \
    && block "'git reset --hard' would discard uncommitted changes ($(dirty_list)). Commit them, or 'git stash push -- <paths>' with explicit paths, first; or ask the author."
  return 0
}
check_discard() { # <checkout|restore> args: paths that would be overwritten from HEAD or a source
  [ "$GUARD_WORK" = 1 ] || return 0
  local kind="$1" t dd=0 skip=0 staged=0 worktree=0 n=0; shift
  local pos; pos=()
  for t in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [ "$dd" = 1 ]; then pos+=("$t"); continue; fi
    case "$t" in
      --) dd=1 ;;
      -b|-B|--orphan|-c|-C) return 0 ;;                            # a branch operation, not a file restore
      -S|--staged) staged=1 ;;
      -W|--worktree) worktree=1 ;;
      -s|--source|--pathspec-from-file) skip=1 ;;                  # option with a separate value
      -*) ;;
      *) if [ "$kind" = checkout ] && [ "$n" = 0 ] && [ "${#pos[@]}" = 0 ] && g rev-parse --verify --quiet "$t^{commit}" >/dev/null 2>&1; then
           n=1                                                     # the first positional is a ref: `git checkout <ref> [-- paths]`
         else pos+=("$t"); fi ;;
    esac
  done
  [ "$kind" = restore ] && [ "$staged" = 1 ] && [ "$worktree" = 0 ] && return 0   # unstaging keeps the edits
  [ "${#pos[@]}" -gt 0 ] || return 0
  dirty "${pos[@]}" \
    && block "'git $kind' of ${pos[*]} would discard unsaved edits in $(dirty_list "${pos[@]}"). Keep them, or stash those paths explicitly first; probes come out by deleting their lines, not by restoring the file."
  return 0
}
check_clean() { # args after `clean`: block when the same clean, dry-run, would delete anything
  [ "$GUARD_WORK" = 1 ] || return 0
  local t dd=0 skip=0 dry=0 force=0 flags="" out
  local pos; pos=()
  for t in "$@"; do
    if [ "$skip" = 1 ]; then flags="$flags -e $t"; skip=0; continue; fi
    if [ "$dd" = 1 ]; then pos+=("$t"); continue; fi
    case "$t" in
      --) dd=1 ;;
      -n|--dry-run) dry=1 ;;
      -i|--interactive) return 0 ;;
      -e|--exclude) skip=1 ;;
      --exclude=*) flags="$flags $t" ;;
      -f|--force) force=1 ;;
      -d|-x|-X) flags="$flags $t" ;;
      --*) ;;
      -*) case "$t" in *n*) dry=1 ;; esac; case "$t" in *f*) force=1 ;; esac
          case "$t" in *d*) flags="$flags -d" ;; esac; case "$t" in *X*) flags="$flags -X" ;; *x*) flags="$flags -x" ;; esac ;;
      *) pos+=("$t") ;;
    esac
  done
  [ "$dry" = 1 ] || [ "$force" = 0 ] && return 0                  # a dry run, or git refuses without -f anyway
  # shellcheck disable=SC2086
  if [ "${#pos[@]}" -gt 0 ]; then out=$(g clean -n $flags -- "${pos[@]}" 2>/dev/null); else out=$(g clean -n $flags 2>/dev/null); fi
  [ -n "$out" ] && block "'git clean' would delete untracked files: $(printf '%s\n' "$out" | sed 's/^Would remove //' | head -5 | paste -sd' ' -). Delete the ones you created by name (rm <path>), never the tree."
  return 0
}
check_stash() { # args after `stash`
  [ "$GUARD_WORK" = 1 ] || return 0
  case "${1-}" in
    drop|clear) block "'git stash $1' destroys stashed work. 'git stash pop' applies and drops in one step; leave other entries for the author." ;;
  esac
  return 0
}
check_branch() { # args after `branch`
  local t del=0 force=0; local names; names=()
  for t in "$@"; do
    case "$t" in
      -d|--delete) del=1 ;; -D) del=1; force=1 ;; -f|--force) force=1 ;;
      --*) ;; -*) case "$t" in *d*|*D*) del=1 ;; esac; case "$t" in *D*|*f*) force=1 ;; esac ;;
      *) names+=("$t") ;;
    esac
  done
  [ "$del" = 1 ] && [ "${#names[@]}" -gt 0 ] || return 0
  for t in "${names[@]}"; do
    is_protected "$t" && block "delete of the protected branch $t."
    [ "$GUARD_WORK" = 1 ] && [ "$force" = 1 ] || continue
    g rev-parse --verify --quiet "refs/heads/$t" >/dev/null 2>&1 || continue
    if ! g merge-base --is-ancestor "$t" HEAD 2>/dev/null && ! { [ -n "$DEFAULT_BRANCH" ] && g merge-base --is-ancestor "$t" "origin/$DEFAULT_BRANCH" 2>/dev/null; }; then
      block "'git branch -D $t' would drop commits that are not merged into HEAD or ${DEFAULT_BRANCH:-the default branch}. Merge or push them first, or ask the author; 'git branch -d' refuses on its own."
    fi
  done
  return 0
}
check_rm() { # args after `rm`: tracked edits and, recursively, untracked files are work that is not in git
  [ "$GUARD_WORK" = 1 ] || return 0
  [ "$CWD" = "?" ] && return 0                                      # cd to an unknown place earlier in the command
  local t rec=0 dd=0 u
  local pos; pos=()
  for t in "$@"; do
    if [ "$dd" = 1 ]; then pos+=("$t"); continue; fi
    case "$t" in
      --) dd=1 ;;
      -r|-R|--recursive) rec=1 ;;
      --*) ;;
      -*) case "$t" in *r*|*R*) rec=1 ;; esac ;;
      *) pos+=("$t") ;;
    esac
  done
  [ "${#pos[@]}" -gt 0 ] || return 0
  for t in "${pos[@]}"; do                                          # a path outside the checkout reads as clean (git says "outside repository")
    dirty "$t" && block "'rm $t' would delete unsaved edits in $(dirty_list "$t"). Commit or stash them explicitly first; a probe comes out by deleting its lines."
    if [ "$rec" = 1 ]; then
      u=$(untracked "$t" | head -5 | paste -sd' ' -)
      [ -n "$u" ] && block "'rm -r $t' would delete untracked files that are not in git: $u. Delete the ones you created by name; if they are run artefacts (test-results/, coverage/), add the folder to .gitignore first, then this is allowed."
    fi
  done
  return 0
}

# ---- git commit ---------------------------------------------------------------------
check_commit() { # args after `commit` (quotes blanked)
  local t has_m=0 has_f=0 next_f=0 file=""
  for t in "$@"; do
    if [ "$next_f" = 1 ]; then file="$t"; next_f=0; continue; fi
    case "$t" in
      --no-verify) block "--no-verify skips the repo's git hooks. Fix the failing hook instead." ;;
      --all) block "commit --all stages every tracked change. Stage explicit paths, then commit." ;;
      --message|--message=*) has_m=1 ;;
      --file=*) has_f=1; file="${t#--file=}" ;;
      --file) has_f=1; next_f=1 ;;
      --*) ;;
      -u*|-S*) ;;                                                 # -u<mode>, -S<keyid>: values glued to the flag
      -*) case "$t" in *n*) block "-n (--no-verify) skips the repo's git hooks. Fix the failing hook instead." ;; esac
          case "$t" in *a*) block "commit -a stages every tracked change. Stage explicit paths, then commit." ;; esac
          case "$t" in *m*) has_m=1 ;; esac
          case "$t" in
            -*F?*) has_f=1; file="${t#*F}" ;;                      # -Fmsg.txt: the path glued to the flag
            -*F) has_f=1; next_f=1 ;;                               # -F msg.txt / -F -: the path comes next
          esac ;;
    esac
  done
  [ -n "$TICKET_REGEX" ] || return 0
  if [ "$has_m" = 1 ]; then
    # Read the -m/--message values from the ORIGINAL command (flattened so a heredoc message is one string).
    local flat msgs
    flat=$(printf '%s' "$CMD" | tr '\n' ' ')
    msgs=$(printf '%s' "$flat" | grep -oE -- "(^|[[:space:]])(-[a-zA-Z]*m|--message)(=|[[:space:]]*)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" || true)
    [ -z "$msgs" ] && msgs="$flat"
    printf '%s' "$msgs" | grep -qE -- "$TICKET_REGEX" \
      || block "commit message has no ticket key matching /$TICKET_REGEX/. Use: type(KEY): description (or set the ticket_regex option to 'none')."
  elif [ "$has_f" = 1 ]; then
    # -F -: the message is the heredoc or pipe in this command, so the whole original command is searched.
    # -F <path>: the file is read as it is now (the message git will use); unreadable → the key cannot be verified.
    if [ "$file" = - ] || [ -z "$file" ]; then
      printf '%s' "$CMD" | grep -qE -- "$TICKET_REGEX" \
        || block "commit message (-F -) has no ticket key matching /$TICKET_REGEX/. Use: type(KEY): description (or set the ticket_regex option to 'none')."
    elif [ -r "$file" ]; then
      grep -qE -- "$TICKET_REGEX" "$file" \
        || block "commit message file $file has no ticket key matching /$TICKET_REGEX/. Use: type(KEY): description (or set the ticket_regex option to 'none')."
    else
      block "commit -F $file: the message file cannot be read here, so its ticket key cannot be checked. Write the file first, or use -m \"type(KEY): description\"."
    fi
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

# ---- git checkout / switch: remember the branch the rest of the command runs on ---------
check_switch() { # args after `checkout`/`switch`
  local t next=0 b=""
  for t in "$@"; do
    if [ "$next" = 1 ]; then b="$t"; break; fi
    case "$t" in
      --) break ;;                                                # paths follow: a file checkout, not a branch switch
      -b|-B|-c|-C|--orphan) next=1 ;;                             # the new branch's name comes next
      -*) ;;
      *) git show-ref --verify --quiet "refs/heads/$t" 2>/dev/null && b="$t"; break ;;   # an existing branch, not a path
    esac
  done
  [ -n "$b" ] && SWITCHED="$b"
  return 0
}

# ---- walk every segment (split at ; | & ( ) ` and newlines) in command order --------------
# A `cd` moves CWD for the segments after it; `rm` is checked against the tree; each git command goes to its check.
check_git() { # one git invocation, global options included
  local seg="$1" d s2 rest sub args
  # `git -C /absolute/dir …` (a worktree, as the implementer agent uses) is checked as if run in that directory.
  # A relative or hidden path, several -C, --git-dir and --work-tree still block: the target cannot be verified.
  GDIR=""
  if printf '%s' "$seg" | grep -qE -- '^git[[:space:]]+-C[[:space:]]+/[^[:space:]$`]*[[:space:]]'; then
    d=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/')
    s2=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+-C[[:space:]]+[^[:space:]]+/git/')
    if [ -d "$d" ] && git -C "$d" rev-parse --git-dir >/dev/null 2>&1 && ! has_repo_override "$s2"; then GDIR=$d; seg=$s2; fi
  fi
  has_repo_override "$seg" && block "git -C/--git-dir/--work-tree with ${seg#git } — the target repository cannot be verified. Use an absolute -C path, or run git from the project root."
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
    checkout)   [ -z "$GDIR" ] && check_switch "$@"; check_discard checkout "$@" ;;
    switch)     [ -z "$GDIR" ] && check_switch "$@" ;;
    restore)    check_discard restore "$@" ;;
    reset)      check_reset "$@" ;;
    clean)      check_clean "$@" ;;
    stash)      check_stash "$@" ;;
    branch)     check_branch "$@" ;;
  esac
  printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])--no-verify([[:space:]]|$)' && [ "$sub" = push ] \
    && block "--no-verify skips the repo's git hooks. Fix the failing hook instead."
  return 0
}
move_cwd() { # args after `cd`/`pushd`: a literal directory moves CWD; anything else makes it unknown
  local t="${1-}"
  case "$t" in ''|-|-*|*'$'*|*'`'*|'~'*) CWD="?"; return 0 ;; esac
  case "$t" in /*) ;; *) [ "$CWD" = "?" ] && return 0; t="$CWD/$t" ;; esac
  if [ -d "$t" ]; then CWD=$(cd "$t" 2>/dev/null && pwd -P) || CWD="?"; else CWD="?"; fi
  return 0
}
GIT_SUBS='push|add|stage|commit|rebase|pull|checkout|switch|restore|reset|clean|stash|branch'
while IFS= read -r seg; do
  seg=${seg#"${seg%%[![:space:]]*}"}                                # leading whitespace off
  [ -z "$seg" ] && continue
  case "$seg" in
    cd|cd[[:space:]]*|pushd|pushd[[:space:]]*) set -- ${seg#*d}; move_cwd "${1-}"; continue ;;
  esac
  # rm anywhere in the segment (rm, sudo rm, /bin/rm, env … rm), but not `git rm` (git refuses to drop edits itself).
  if printf '%s' "$seg" | grep -qE -- '(^|[^[:alnum:]_.-])rm[[:space:]]' && ! printf '%s' "$seg" | grep -qE -- '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+rm[[:space:]]'; then
    rest=$(printf '%s' "$seg" | sed -E 's/^(.*[^[:alnum:]_.-])?rm[[:space:]]+//')
    # shellcheck disable=SC2086
    set -- $rest; check_rm "$@"
  fi
  while IFS= read -r gs; do [ -n "$gs" ] && check_git "$gs"; done <<EOF2
$(printf '%s' "$seg" | grep -oE -- "${GIT_RE}(${GIT_SUBS})([[:space:]].*)?$" | sed -E 's/^[^g]//' || true)
EOF2
done <<EOF
$(printf '%s\n' "$CMD_S" | tr ';|&()`' '\n')
EOF

exit 0
