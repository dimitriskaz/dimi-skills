#!/usr/bin/env bash
# The mechanical steps of a review, one plain command each, so the review skills can pre-approve them
# (`Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)`; a command that expands a variable cannot be pre-approved).
#   review.sh build <skill> <out or ''> <default_branch> <demo_marker> <demo_branch> <ticket_regex> <local_checks> [PR]
#   review.sh gates    <Out>                     demo markers, secrets, force-added ignored files, stray untracked files
#   review.sh notes    <Out> '<customer terms>'  working notes in added comments (terms: one a|b regex, or '')
#   review.sh record   <Out>                     point LATEST at the report once it is written
#   review.sh worklist <Out>                     put address-review's worklist beside that report
#   review.sh latest   <default_branch>          the newest self-review report (no build needed)
# build saves its context in <Out>/context.env and prints it; every later step reads it from the <Out> it is
# given, so the base, mode and options cannot drift between steps. Unconfigured options arrive as
# `${user_config.<key>}` and count as unset.
HERE=$(cd "$(dirname "$0")" && pwd -P)
. "$HERE/lib.sh"
export GIT_TERMINAL_PROMPT=0
CMD="${1-}"; shift

# Single-quoted, so loading context.env never runs text from a branch name or a path.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

load() {   # load <Out>
  [ -f "${1-}/context.env" ] || { echo "no review context in '${1-}': run review.sh build first and pass the Out it prints" >&2; exit 1; }
  . "$1/context.env"
}

context() {
  echo "Review context (use these literal values in later commands):"
  echo "  Top: $TOP"; echo "  Out: $OUT"; echo "  Diff: $DIFF"; echo "  Base: $BASE"
  if [ -n "$N" ] && [ -n "$HEAD_REF" ]; then echo "  Head: $HEAD_REF (PR #$N: read its code with git diff <Base> <Head> -- <path> / git show <Head>:<path>)"
  elif [ -n "$N" ]; then echo "  Head: not fetched (the diff came from gh pr diff; read the PR's files on GitHub)"
  else echo "  Head: working tree"; fi
  echo "  Report: $OUT/self-review-$SAFE.md"
  echo "  Default branch: $DB · demo marker: $M · demo branch: ${DEMO:-none}"
  echo "  Ticket regex: ${TR:-none (disabled)} · local checks: ${LOCAL_CI:-not configured (read CLAUDE.md)}"
  if [ -n "$TR" ] && ! valid_ere "$TR"; then echo "  WARNING: the ticket regex is not a valid extended regex; fix the ticket_regex option"; fi
}

build() {
  TOP=$(top) || { echo "not a git repository" >&2; exit 1; }
  cd "$TOP" || exit 1
  SKILL=$(opt "${1-}" self-review); OUT=$(opt "${2-}" "$TOP/../$SKILL-$(basename "$TOP")")
  DB=$(resolve_db "${3-}"); M=$(resolve_marker "${4-}"); DEMO=$(opt "${5-}"); TR=$(resolve_tr "${6-}")
  LOCAL_CI=$(opt "${7-}"); N=$(opt "${8-}"); N=${N#\#}
  mkdir -p "$OUT" 2>/dev/null && OUT=$(cd "$OUT" && pwd -P) || { echo "cannot create the output directory $OUT" >&2; exit 1; }
  DIFF="$OUT/review.diff"; LATEST="$TOP/../self-review-$(basename "$TOP")/LATEST"; HEAD_REF=''
  rm -f "$OUT/status.txt" "$OUT/untracked.txt" "$OUT/behind.txt" "$OUT/main-moved.txt" "$OUT/review.stat" "$OUT/pr.json" "$OUT/checks.txt"
  if [ -n "$N" ]; then
    SAFE="pr-$N"
    with_timeout 30 gh pr view "$N" --json number,title,body,isDraft,isCrossRepository,author,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,commits,reviews,statusCheckRollup,files,url > "$OUT/pr.json" \
      || { echo "gh pr view $N failed (is gh installed and authenticated?)" >&2; exit 1; }
    with_timeout 30 gh pr checks "$N" > "$OUT/checks.txt" 2>&1 || true
    BASE_REF=$(with_timeout 30 gh pr view "$N" --json baseRefName -q .baseRefName)
    HEAD_REF="refs/remotes/origin/pr/$N"                               # pull/<N>/head exists for fork PRs too
    if with_timeout 60 git fetch -q origin "$BASE_REF" "+refs/pull/$N/head:$HEAD_REF" 2>/dev/null; then
      git_diff "origin/$BASE_REF...$HEAD_REF" > "$DIFF"                 # three-dot: this PR's own changes
      git log --oneline "origin/$BASE_REF..$HEAD_REF" > "$OUT/commits.txt"
      BASE=$(git merge-base "origin/$BASE_REF" "$HEAD_REF")
    else                                                                # remote without pull refs: the diff from GitHub
      with_timeout 60 gh pr diff "$N" > "$DIFF"; HEAD_REF=''
      with_timeout 30 gh pr view "$N" --json commits -q '.commits[] | "\(.oid[0:7]) \(.messageHeadline)"' > "$OUT/commits.txt"
      with_timeout 60 git fetch -q origin "$BASE_REF" 2>/dev/null || true; BASE="origin/$BASE_REF"
    fi
    HEADER=$(with_timeout 30 gh pr view "$N" --json headRefName,headRefOid -q '"Branch: \(.headRefName) · HEAD: \(.headRefOid) · Tree: — (PR mode)"')
  else
    SAFE=$(safe_name "$(branch_name)")
    with_timeout 30 git fetch -q origin "$DB" 2>/dev/null || true
    BASE=$(git merge-base "origin/$DB" HEAD 2>/dev/null) || { echo "origin/$DB not found: run git fetch origin $DB, or fix the default_branch option" >&2; exit 1; }
    change_diff "$BASE" > "$DIFF"                                       # committed + staged + unstaged + untracked
    git status --short > "$OUT/status.txt"
    git log --oneline "$BASE..HEAD" > "$OUT/commits.txt"
    git ls-files --others --exclude-standard > "$OUT/untracked.txt"     # every one, never-dump files included (names only)
    git_diff --stat "$BASE" > "$OUT/review.stat"
    git rev-list --count "HEAD..origin/$DB" > "$OUT/behind.txt" 2>/dev/null || echo "?" > "$OUT/behind.txt"
    git -c core.quotePath=false diff --name-only "$BASE..origin/$DB" > "$OUT/main-moved.txt" 2>/dev/null || true
    HEADER="Branch: $(branch_name) · HEAD: $(git rev-parse HEAD 2>/dev/null) · Tree: $(tree_fingerprint "$BASE")"
  fi
  for v in TOP OUT DIFF BASE HEAD_REF N SAFE DB M DEMO TR LOCAL_CI LATEST; do
    eval "printf '%s=%s\n' $v \"\$(q \"\$$v\")\""
  done > "$OUT/context.env"
  context
  if [ -z "$N" ]; then
    st() { grep -cE "$1" "$OUT/status.txt" || true; }
    echo "Scope: $(grep -c . "$OUT/commits.txt") commits · $(st '^[MADRC]') staged · $(st '^.[MD]') unstaged · $(grep -c . "$OUT/untracked.txt") untracked · behind $DB: $(cat "$OUT/behind.txt")"
  fi
  echo "$HEADER"
}

section() { echo "== $1"; if [ -n "$2" ]; then printf '%s\n' "$2"; else echo "none"; fi; }

gates() {
  load "${1-}"; cd "$TOP" || exit 1
  [ -f "$DIFF" ] || { echo "no diff at $DIFF: run review.sh build first" >&2; exit 1; }
  # poc writes MARKER(<feature>): <why>, matched as a fixed string; the plugin's own rule files name the marker.
  section "Demo-only markers (any hit is a Fail)" \
    "$(diff_added_lines < "$DIFF" | grep -vE '^((.*/)?\.claude/[^:]*|(.*/)?(CLAUDE|AGENTS)\.md):' | grep -F -- "$M(" | cut -c1-160)"
  section "Secret-shaped added lines (values masked; read each cited line; stop for a decision)" \
    "$(diff_added_lines < "$DIFF" | grep -iE -- "$SECRET_RE" | redact | cut -c1-160 | cap 20)"
  # Added files git ignores were force-added. --no-index also reports tracked paths; a !negation rule
  # (e.g. !.env.example) means the file is deliberately not ignored, so those lines are dropped.
  section "Added files that match an ignore rule (force-added → Fail)" \
    "$(diff_new_files < "$DIFF" | xargs -0 git check-ignore -v --no-index -- 2>/dev/null | awk -F'\t' '{ s = $1; sub(/^[^:]*:[^:]*:/, "", s); if (substr(s, 1, 1) != "!") print }')"
  if [ -z "$N" ]; then   # the local working tree; in PR mode it is not part of the review
    U=$(git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null)
    section "Untracked secret or state files (never staged; their content is never put in the diff)" \
      "$(printf '%s\n' "$U" | grep -iE -- "$NEVER_DUMP_RE")"
    section "Untracked working artefacts (plans, notes, reports: never staged)" \
      "$(printf '%s\n' "$U" | grep -iE '(plan|handoff|notes|todo|scratch|review|report|transcript)\.(md|txt)$')"
  fi
}

notes() {
  load "${1-}"
  [ -f "$DIFF" ] || { echo "no diff at $DIFF: run review.sh build first" >&2; exit 1; }
  terms=$(opt "${2-}")
  if [ -n "$terms" ] && ! valid_ere "$terms"; then echo "customer terms are not a valid extended regex: $terms" >&2; exit 1; fi
  section "Working notes in added comments (ticket key, customer term, session narrative)" \
    "$(diff_added_lines < "$DIFF" | note_lines "$TR" "$terms" | cut -c1-160)"
}

record() {
  load "${1-}"; R="$OUT/self-review-$SAFE.md"
  [ -f "$R" ] || { echo "no report at $R: write it first" >&2; exit 1; }
  mkdir -p "$(dirname "$LATEST")" && printf '%s\n' "$R" > "$LATEST" && echo "LATEST → $R"
}

worklist() {
  load "${1-}"; W="$OUT/review-worklist-$SAFE.md"; R=$(cat "$LATEST" 2>/dev/null)
  [ -f "$W" ] || { echo "no worklist at $W: write it first" >&2; exit 1; }
  if [ ! -f "$R" ]; then echo "no self-review report: worklist stays at $W"
  elif [ "$(cd "$(dirname "$R")" && pwd -P)" = "$OUT" ]; then echo "already beside $R"
  else cp "$W" "$(dirname "$R")/" && echo "copied beside $R"; fi
}

latest() {
  T=$(top) || { echo "not a git repository"; exit 0; }
  cd "$T" || exit 0
  R=$(cat "$T/../self-review-$(basename "$T")/LATEST" 2>/dev/null)
  if [ -f "$R" ]; then echo "$R"; grep -m1 '^Branch:' "$R"; else echo "no self-review report for this checkout"; fi
  echo "Default branch: $(resolve_db "${1-}") · this branch: $(branch_name) · its report file: self-review-$(safe_name "$(branch_name)").md"
}

case "$CMD" in
  build) build "$@" ;;
  gates) gates "$@" ;;
  notes) notes "$@" ;;
  record) record "$@" ;;
  worklist) worklist "$@" ;;
  latest) latest "$@" ;;
  *) echo "usage: review.sh build|gates|notes|record|worklist|latest … (see the header of this file)" >&2; exit 2 ;;
esac
