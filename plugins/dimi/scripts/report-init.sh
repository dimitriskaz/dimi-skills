#!/usr/bin/env bash
# Mechanical steps of the report skill, one plain command each (pre-approved by its allowed-tools):
#   report-init.sh init <out dir or ''> <slug>        create the output dir, copy the template to report-<slug>-<date>.html, print the path
#   report-init.sh img  <report path> <image file>     copy an image to img/ beside the report, print the relative src to use
#   report-init.sh shot <report path>                  screenshot the report at 1280 and 400 px (needs node + playwright), print the PNG paths
# '' as the out dir means <top>/../report-<repo>/ next to the checkout (a session scratchpad path goes in explicitly).
. "$(dirname "$0")/lib.sh"
T=$(top) || { echo "not a git repository" >&2; exit 1; }
TEMPLATE="$(cd "$(dirname "$0")/.." && pwd -P)/skills/report/references/template.html"

case "${1-}" in
  init)
    OUT=$(opt "${2-}" "$T/../report-$(basename "$T")"); SLUG=$(opt "${3-}" report | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
    mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd -P) || { echo "cannot create $OUT" >&2; exit 1; }
    case "$OUT" in "$T"|"$T"/*) echo "refusing to write inside the repository ($OUT)" >&2; exit 1 ;; esac
    F="$OUT/report-${SLUG:-report}-$(date +%Y-%m-%d).html"
    [ -f "$TEMPLATE" ] || { echo "template not found at $TEMPLATE" >&2; exit 1; }
    cp "$TEMPLATE" "$F" && echo "$F" ;;
  img)
    R="${2:?report path}"; I="${3:?image file}"; [ -f "$R" ] || { echo "no report at $R" >&2; exit 1; }; [ -f "$I" ] || { echo "no image at $I" >&2; exit 1; }
    D="$(dirname "$R")/img"; mkdir -p "$D" && cp -- "$I" "$D/" && echo "img/$(basename -- "$I")" ;;
  shot)
    R="${2:?report path}"; [ -f "$R" ] || { echo "no report at $R" >&2; exit 1; }
    command -v node >/dev/null 2>&1 && node -e "require('playwright')" >/dev/null 2>&1 || { echo "node with playwright is not available: open $R in a browser and look at it at desktop and phone width"; exit 0; }
    node -e '
const { chromium } = require("playwright"); const path = require("path");
(async () => { const f = process.argv[1]; const b = await chromium.launch();
  for (const [n, w] of [["desktop", 1280], ["phone", 400]]) {
    const p = await b.newPage({ viewport: { width: w, height: 900 } }); await p.goto("file://" + f, { waitUntil: "load" }); await p.waitForTimeout(500);
    const out = f.replace(/\.html$/, "") + "-" + n + ".png"; await p.screenshot({ path: out, fullPage: true }); console.log(out); await p.close(); }
  await b.close(); })();' "$(cd "$(dirname "$R")" && pwd -P)/$(basename "$R")" ;;
  *) echo "usage: report-init.sh init|img|shot … (see the header of this file)" >&2; exit 2 ;;
esac
