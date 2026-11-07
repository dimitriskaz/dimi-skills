#!/usr/bin/env bash
# The publish gate for public product documentation (release-notes skill). Everything under <public dir> is published,
# so nothing internal may be in it.
#   docs-check.sh <public dir | one page> '<ticket_regex>' ['<extra deny regex>']
# FAIL (exit 1): a source path, a PR or ticket reference, a commit hash, a local or preview host, a test id, a working
# marker, a local file path, an internal file in the folder, a missing image, an image without alt text, a page without
# a title or description. REVIEW (printed, exit unaffected): environment-variable-shaped words, "staging", alt text
# that reads like a file name, images no page uses, code blocks (each must be something a user types or sees).
# Prose is checked outside fenced code blocks; front matter is checked too, since titles are published.
. "$(dirname "$0")/lib.sh"
D="${1:?usage: docs-check.sh <public dir | one page> '<ticket_regex>' ['<extra deny regex>']}"
[ -e "$D" ] || { echo "no such directory or page: $D" >&2; exit 2; }
case "$D" in -*) D="./$D" ;; esac   # every path below starts with $D, so none can read as an option
TR=$(resolve_tr "${2-}"); EXTRA=$(opt "${3-}")
FAILS=0; REVIEWS=0
fail()   { FAILS=$((FAILS + 1));   printf 'FAIL    %s\n' "$1"; }
review() { REVIEWS=$((REVIEWS + 1)); printf 'REVIEW  %s\n' "$1"; }

if [ -f "$D" ]; then PAGES=$D; IMAGES=''; else
PAGES=$(find "$D" -type f \( -name '*.md' -o -name '*.mdx' \) 2>/dev/null | sort)
IMAGES=$(find "$D" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.svg' \) 2>/dev/null | sort); fi

# internal files that must never sit in a published folder
if [ -d "$D" ]; then
  INTERNAL=$(find "$D" \( -name 'scenes.json' -o -name '*.spec.*' -o -name 'playwright*.config.*' -o -name '*-trace.md' -o -name '*-internal.md' \
    -o -name '*.tsv' -o -name '*storageState*' -o -name '.auth' -o -name '.env*' \) 2>/dev/null | sort)
  while IFS= read -r f; do [ -n "$f" ] && fail "$f: internal file inside the published folder (move it to the capture tooling folder)"; done <<EOF3
$INTERNAL
EOF3
fi

REFS=''
while IFS= read -r p; do
  [ -n "$p" ] || continue
  # front matter: a title and a description
  if [ "$(head -n 1 "$p")" != '---' ]; then fail "$p: no front matter (title and description)"
  else
    FM=$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "$p")
    printf '%s\n' "$FM" | grep -qE '^title:[[:space:]]*[^[:space:]]' || fail "$p: front matter has no title"
    printf '%s\n' "$FM" | grep -qE '^description:[[:space:]]*[^[:space:]]' || fail "$p: front matter has no description"
    printf '%s\n' "$FM" | grep -E '^[A-Za-z][A-Za-z0-9_-]*:[[:space:]]+[^"'"'"'|>[{&*! ].*: ' | while IFS= read -r l; do printf 'FAIL    %s: front matter value needs quotes (it contains ": "): %s\n' "$p" "$l"; done
    FMQ=$(printf '%s\n' "$FM" | grep -cE '^[A-Za-z][A-Za-z0-9_-]*:[[:space:]]+[^"'"'"'|>[{&*! ].*: '); FAILS=$((FAILS + FMQ))
  fi
  # prose lines (outside ``` or ~~~ fences), numbered
  PROSE=$(awk '/^[[:space:]]*(```|~~~)/ { f = !f; next } !f { print FNR ":" $0 }' "$p")
  FENCES=$(grep -cE '^[[:space:]]*(```|~~~)' "$p" 2>/dev/null); FENCES=${FENCES:-0}
  [ "$FENCES" -gt 0 ] && review "$p: $((FENCES / 2)) code block(s): each must be something a user types or sees, not code from the repository"
  hits() {   # hits <reason> <ERE> [-i]
    printf '%s\n' "$PROSE" | grep -E ${3:-} -- "$2" | cut -c1-160 | while IFS= read -r l; do printf 'FAIL    %s:%s  (%s)\n' "$p" "$l" "$1"; done
  }
  OUT=$(
    hits 'source file path' '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*\.(tsx?|jsx?|mjs|cjs|py|go|rb|java|kt|cs|php|sql|prisma|vue|svelte|ya?ml|toml|sh)([^A-Za-z0-9]|$)'
    hits 'PR or issue number' '(^|[^&A-Za-z0-9/#])#[0-9]+([^0-9A-Za-z]|$)'
    [ -n "$TR" ] && hits 'ticket key' "$TR"
    hits 'local or preview host' '(localhost|127\.0\.0\.1|0\.0\.0\.0|\.local([^A-Za-z0-9]|$)|\.internal([^A-Za-z0-9]|$)|vercel\.app|netlify\.app|ngrok|\.test([^A-Za-z0-9]|$))' -i
    hits 'test id or selector' '(data-testid|data-test=|getByTestId|querySelector)'
    hits 'working marker' '(TODO|FIXME|XXX|DEMO-ONLY|lorem ipsum|placeholder text)'
    hits 'local file path' '(/Users/|/home/|[A-Za-z]:\\|file://)'
    [ -n "$EXTRA" ] && hits 'internal term' "$EXTRA" -i
    # a commit hash: 7 to 40 hex characters with at least one letter and one digit, as a word of its own
    printf '%s\n' "$PROSE" | awk -v p="$p" '{ n = $0; sub(/:.*/, "", n); s = $0; sub(/^[0-9]+:/, "", s)
      while (match(s, /[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+/)) {
        w = substr(s, RSTART, RLENGTH); pre = substr(s, RSTART - 1, 1); post = substr(s, RSTART + RLENGTH, 1)
        if (RLENGTH <= 40 && w ~ /[a-f]/ && w ~ /[0-9]/ && pre !~ /[A-Za-z0-9#]/ && post !~ /[A-Za-z0-9]/) printf "FAIL    %s:%s:%s  (commit hash)\n", p, n, w
        s = substr(s, RSTART + RLENGTH) } }'
  )
  if [ -n "$OUT" ]; then printf '%s\n' "$OUT"; FAILS=$((FAILS + $(printf '%s\n' "$OUT" | grep -c .))); fi
  printf '%s\n' "$PROSE" | grep -E -- '(^|[^A-Za-z0-9_])[A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9]([^A-Za-z0-9_]|$)' | cut -c1-160 | while IFS= read -r l; do printf 'REVIEW  %s:%s  (looks like an environment variable or a constant)\n' "$p" "$l"; done
  printf '%s\n' "$PROSE" | grep -iE -- '(^|[^A-Za-z])staging([^A-Za-z]|$)' | cut -c1-160 | while IFS= read -r l; do printf 'REVIEW  %s:%s  (staging: an environment name, or a product word?)\n' "$p" "$l"; done
  # images: ![alt](src) and <img src alt>, relative to the page
  DIR=$(dirname -- "$p")
  printf '%s\n' "$PROSE" | grep -oE '!\[[^]]*\]\([^) ]+' | while IFS= read -r m; do
    alt=${m#!\[}; alt=${alt%%\]*}; src=${m#*\](}
    case "$src" in http://*|https://*) continue ;; esac
    case "$src" in /*) f=$src ;; *) f=$DIR/$src ;; esac
    [ -f "$f" ] || printf 'FAIL    %s: image %s does not exist\n' "$p" "$src"
    if [ -z "$alt" ]; then printf 'FAIL    %s: image %s has no alt text\n' "$p" "$src"
    elif printf '%s' "$alt" | grep -qiE '^(image|screenshot|img|picture|figure)?[ _-]*[0-9]*$|^[A-Za-z0-9_-]+\.(png|jpe?g|gif|webp|svg)$'; then printf 'REVIEW  %s: image %s: alt "%s" does not describe the picture\n' "$p" "$src" "$alt"; fi
  done
  REFS="$REFS
$(printf '%s\n' "$PROSE" | grep -oE '!\[[^]]*\]\([^) ]+|<img[^>]*src="[^"]+"' | sed -E 's/.*\(//; s/.*src="//; s/"$//' | while IFS= read -r s; do case "$s" in http*) ;; *) (cd "$DIR" && cd "$(dirname -- "$s")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$s")"); esac; done)"
done <<EOF2
$PAGES
EOF2

# image failures were printed inside a subshell: count them from a second pass
IMGFAIL=$(printf '%s\n' "$PAGES" | grep . | while IFS= read -r p; do DIR=$(dirname -- "$p")
  awk '/^[[:space:]]*(```|~~~)/ { f = !f; next } !f' "$p" | grep -oE '!\[[^]]*\]\([^) ]+' | while IFS= read -r m; do
    alt=${m#!\[}; alt=${alt%%\]*}; src=${m#*\](}; case "$src" in http://*|https://*) continue ;; esac
    case "$src" in /*) f=$src ;; *) f=$DIR/$src ;; esac
    { [ -f "$f" ] && [ -n "$alt" ]; } || echo x; done; done | grep -c x)
FAILS=$((FAILS + IMGFAIL))

# images no page uses
printf '%s\n' "$IMAGES" | grep . | while IFS= read -r i; do
  abs="$(cd "$(dirname -- "$i")" && pwd -P)/$(basename -- "$i")"
  printf '%s\n' "$REFS" | grep -qxF -- "$abs" || printf 'REVIEW  %s: no page uses this image\n' "$i"
done

echo "docs-check: $FAILS to fix in $(printf '%s\n' "$PAGES" | grep -c .) pages and $(printf '%s\n' "$IMAGES" | grep -c .) images (REVIEW lines need a look, not necessarily a change)"
[ "$FAILS" -eq 0 ]
