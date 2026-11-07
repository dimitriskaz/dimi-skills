#!/usr/bin/env bash
# Put the release-notes skill's capture tooling into the repository without overwriting anything:
#   docs-init.sh <tools dir> <published docs root>
# Copies capture-scene.ts, docs-capture.spec.ts and playwright.capture.config.ts from the skill's references/capture/
# when absent, says when an existing copy differs, and writes a scenes.json skeleton whose imageRoot points into the
# published docs. Refuses a tools dir inside the published root: everything there is published.
. "$(dirname "$0")/lib.sh"
T=$(top) || { echo "not a git repository" >&2; exit 1; }
cd "$T" || exit 1
TOOLS=$(opt "${1-}" tools/docs-capture); PUB=$(opt "${2-}" docs/product)
case "$TOOLS$PUB" in /*|-*|*..*) echo "give both folders relative to the repository top, without .." >&2; exit 2 ;; esac
case "${TOOLS%/}/" in "${PUB%/}"/*) echo "refusing: $TOOLS is inside the published docs root $PUB" >&2; exit 2 ;; esac
SRC="$(cd "$(dirname "$0")/.." && pwd -P)/skills/release-notes/references/capture"
mkdir -p "$TOOLS" "$PUB/img" || exit 1
for f in capture-scene.ts docs-capture.spec.ts playwright.capture.config.ts; do
  if [ ! -f "$TOOLS/$f" ]; then cp "$SRC/$f" "$TOOLS/$f" && echo "created $TOOLS/$f"
  elif cmp -s "$SRC/$f" "$TOOLS/$f"; then echo "unchanged $TOOLS/$f"
  else echo "kept $TOOLS/$f (differs from the plugin's version: diff -u '$SRC/$f' '$TOOLS/$f')"; fi
done
DEPTH=$(printf '%s' "${TOOLS%/}" | awk -F/ '{ print NF }'); UP=$(awk -v n="$DEPTH" 'BEGIN { for (i = 0; i < n; i++) printf "../" }')
# the config imports the repository's own Playwright config by a path relative to the tools dir
[ "$DEPTH" != 2 ] && grep -q "'../../playwright.config'" "$TOOLS/playwright.capture.config.ts" && sed -i.bak "s#'../../playwright.config'#'${UP}playwright.config'#; s#'../..')#'${UP%/}')#" "$TOOLS/playwright.capture.config.ts" && rm -f "$TOOLS/playwright.capture.config.ts.bak" && echo "pointed the config at ${UP}playwright.config"
if [ ! -f "$TOOLS/scenes.json" ]; then
  cat > "$TOOLS/scenes.json" <<JSON
{
  "imageRoot": "${UP}${PUB%/}/img",
  "tenant": "",
  "allowHosts": [],
  "clock": "",
  "viewport": { "width": 1440, "height": 900 },
  "style": { "hide": [], "mask": [] },
  "scenes": []
}
JSON
  echo "created $TOOLS/scenes.json"
else echo "kept $TOOLS/scenes.json"; fi
echo "run: npx playwright test --config $TOOLS/playwright.capture.config.ts"
