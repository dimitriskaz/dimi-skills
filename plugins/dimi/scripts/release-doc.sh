#!/usr/bin/env bash
# The Word release document for the release-notes skill: one .docx per release, written outside the repository.
#   release-doc.sh <source .md> <output .docx> ['<template .docx>'] ['<ticket_regex>'] ['<deny regex>']
# Copies the source and its screenshots into a build folder beside the output (screenshots tagged so Word shows each at
# 80% of its on-screen size), gates that copy (docs-check.sh, plus links that only work on a website), converts with
# pandoc using the template (the repo's own, else the plugin's), borders every picture, checks that every image made it
# in, and, when LibreOffice is installed, renders page previews into the build folder to look at.
. "$(dirname "$0")/lib.sh"
SRC="${1:?usage: release-doc.sh <source .md> <output .docx> ['<template .docx>'] ['<ticket_regex>'] ['<deny regex>']}"
OUTF="${2:?output .docx}"; TPL=$(opt "${3-}"); TR=$(opt "${4-}"); DENY=$(opt "${5-}")
HERE="$(cd "$(dirname "$0")" && pwd -P)"; RD="$HERE/../skills/release-notes/references/release-doc"
[ -f "$SRC" ] || { echo "no source at $SRC" >&2; exit 2; }
case "$OUTF" in *.docx) ;; *) echo "the output must end in .docx" >&2; exit 2 ;; esac

command -v pandoc >/dev/null 2>&1 || { echo "pandoc is not installed. Install it (macOS: brew install pandoc · Windows: winget install --id JohnMacFarlane.Pandoc · Debian/Ubuntu: sudo apt install pandoc), then run this again. The Markdown source is ready at $SRC."; exit 1; }
V=$(pandoc --version | head -1 | sed -E 's/^pandoc(\.exe)? ([0-9]+)\.([0-9]+).*/\2 \3/')
set -- $V; { [ "${1:-0}" -gt 2 ] || { [ "${1:-0}" -eq 2 ] && [ "${2:-0}" -ge 11 ]; }; } || { echo "pandoc $1.$2 is too old: 2.11 or later is needed" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is needed for the image sizes and borders" >&2; exit 1; }

mkdir -p "$(dirname "$OUTF")" || exit 1
OUTD=$(cd "$(dirname "$OUTF")" && pwd -P); OUTF="$OUTD/$(basename "$OUTF")"
T=$(top); if [ -n "$T" ]; then case "$OUTD/" in "$T"/*) echo "refusing to write the release document inside the repository ($OUTD): it is a deliverable, not a tracked file" >&2; exit 2 ;; esac; fi
if [ -n "$TPL" ]; then case "$TPL" in /*) ;; *) TPL="${T:-.}/$TPL" ;; esac; [ -f "$TPL" ] || { echo "no template at $TPL (the release_doc_template option)" >&2; exit 2; }
else TPL="$RD/reference.docx"; fi

# 1. a build folder with copies of the screenshots, tagged with their print resolution
NAME=$(basename "$OUTF" .docx); B="$OUTD/.build-$NAME"; rm -rf "$B" && mkdir -p "$B/img" || exit 1
SRCD=$(cd "$(dirname "$SRC")" && pwd -P)
python3 - "$SRC" "$SRCD" "$B" <<'PY' || exit 1
import os, re, shutil, sys
src, srcd, b = sys.argv[1:4]
text = open(src, encoding='utf-8').read()
seen = {}
def copy(m):
    alt, path, rest = m.group(1), m.group(2), m.group(3) or ''
    if re.match(r'^https?://', path): return m.group(0)
    full = path if os.path.isabs(path) else os.path.normpath(os.path.join(srcd, path))
    if full not in seen:
        name = f'{len(seen) + 1:02d}-{os.path.basename(full)}'; shutil.copyfile(full, os.path.join(b, 'img', name)); seen[full] = name
    return f'![{alt}](img/{seen[full]}){rest}'
out = re.sub(r'!\[([^\]]*)\]\(([^)\s]+)\)(\{[^}]*\})?', copy, text)
open(os.path.join(b, 'source.md'), 'w', encoding='utf-8').write(out)
print(len(seen), 'images copied')
PY
python3 "$RD/postprocess.py" dpi "$B"/img/*.png 2>/dev/null | grep -v '^0 ' || true
WANT=$(grep -oE '!\[[^]]*\]\(' "$B/source.md" | grep -c .)

# 2. the gate, on the copy that is converted (screenshots already rewritten to img/NN-name.png)
bash "$HERE/docs-check.sh" "$B/source.md" "$TR" "$DENY" || { echo "fix the source before building the Word document" >&2; exit 1; }
BADLINKS=$(awk '/^[[:space:]]*(```|~~~)/ { f = !f; next } !f { print FNR ":" $0 }' "$B/source.md" | grep -oE '(^|[^!])\[[^]]*\]\([^)]+\)' | sed -E 's/.*\]\(//; s/\)$//' | grep -vE '^(https?://|mailto:|#)')
if [ -n "$BADLINKS" ]; then printf 'FAIL    link that only works on a website, not in Word: %s\n' $BADLINKS; echo "use the full https:// address of the page, or drop the link" >&2; exit 1; fi

# 3. convert, border, check
( cd "$B" && pandoc source.md -f markdown -o "$OUTF" --reference-doc="$TPL" --lua-filter="$RD/release-doc.lua" --resource-path=. ) || { echo "pandoc failed" >&2; exit 1; }
python3 "$RD/postprocess.py" border "$OUTF" >/dev/null || exit 1
GOT=$(python3 "$RD/postprocess.py" count "$OUTF")
[ "$GOT" = "$WANT" ] || { echo "FAIL    $WANT images in the source but $GOT in the document" >&2; exit 1; }

# 4. page previews to look at (not delivered)
if command -v soffice >/dev/null 2>&1 && command -v pdftoppm >/dev/null 2>&1; then
  with_timeout 120 soffice --headless --convert-to pdf --outdir "$B" "$OUTF" >/dev/null 2>&1 && pdftoppm -r 70 -png "$B/$NAME.pdf" "$B/page" 2>/dev/null \
    && echo "page previews: $(ls "$B"/page-*.png 2>/dev/null | grep -c .) in $B (read them before handing the document over)"
else echo "no LibreOffice here: open $OUTF in Word and page through it before handing it over"; fi
echo "release document: $OUTF ($GOT images)"
