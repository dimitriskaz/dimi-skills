#!/usr/bin/env bash
# Read-only facts for the release-notes skill: the release range, the docs framework and where it publishes, the
# capture tooling and Playwright setup, the files that hold the product's own words (locale strings), and the client
# profile. Called from the skill's `!` injection; prints labelled lines; always exits 0.
. "$(dirname "$0")/../lib.sh"
block() { echo "- $1:"; if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/    /'; else echo "    none found"; fi; }

T=$(top)
if [ -z "$T" ]; then echo "- Repository: not a git repository"; exit 0; fi
cd "$T" || exit 0
FILES=$(tracked_files)
has() { printf '%s\n' "$FILES" | grep -qE -- "$1"; }

LAST=$(git describe --tags --abbrev=0 2>/dev/null)
echo "- Repository: $(basename "$T") · branch: $(branch_name) · HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo none)"
if [ -n "$LAST" ]; then echo "- Last tag: $LAST · commits since: $(git rev-list --count "$LAST..HEAD" -- 2>/dev/null)"
else echo "- Last tag: none (a release run needs a range or a first tag)"; fi

# The docs framework decides the page format, the callout syntax and which folder is published.
FW=; ROOT=
if has '(^|/)docusaurus\.config\.(js|ts|mjs|cjs)$'; then FW='Docusaurus'; ROOT='docs/'
elif has '(^|/)mkdocs\.ya?ml$'; then FW='MkDocs'; M=$(printf '%s\n' "$FILES" | grep -E '(^|/)mkdocs\.ya?ml$' | head -1); ROOT=$(sed -nE 's/^docs_dir:[[:space:]]*["'"'"']?([^"'"'"' ]+).*/\1/p' "$M" 2>/dev/null | head -1); ROOT=${ROOT:-docs}/
elif has '(^|/)(mint|docs)\.json$' && printf '%s\n' "$FILES" | grep -E '(^|/)(mint|docs)\.json$' | head -3 | while IFS= read -r f; do grep -qi 'mintlify' "$f" && echo y; done | grep -q y; then FW='Mintlify'; ROOT="$(dirname "$(printf '%s\n' "$FILES" | grep -E '(^|/)(mint|docs)\.json$' | head -1)")/"
elif has '(^|/)astro\.config\.(mjs|ts|js)$' && grep -qs 'starlight' $(printf '%s\n' "$FILES" | grep -E '(^|/)astro\.config\.(mjs|ts|js)$' | head -1); then FW='Starlight'; ROOT='src/content/docs/'
elif has '(^|/)\.vitepress/config\.(js|ts|mjs|mts)$'; then FW='VitePress'; ROOT="$(printf '%s\n' "$FILES" | grep -E '(^|/)\.vitepress/config' | head -1 | sed 's#\.vitepress/.*##')"; ROOT=${ROOT:-./}
elif has '(^|/)theme\.config\.(tsx|jsx|ts|js)$'; then FW='Nextra'; ROOT='pages/'
fi
echo "- Docs framework: ${FW:-none found (write plain Markdown with front matter; GitHub-style callouts)} · published root: ${ROOT:-none}"
block "Existing public docs pages (first 15)" "$(printf '%s\n' "$FILES" | grep -E '^(docs/product|'"${ROOT:-docs/product/}"')[^ ]*\.(md|mdx)$' | head -15)"

# Capture tooling and Playwright
PW=$(printf '%s\n' "$FILES" | grep -E '(^|/)package\.json$' | while IFS= read -r m; do v=$(json_get devDependencies @playwright/test < "$m"); [ -z "$v" ] && v=$(json_get dependencies @playwright/test < "$m"); [ -n "$v" ] && echo "$m: @playwright/test $v"; done | head -3)
echo "- Playwright: ${PW:-@playwright/test not in any package.json (no capture; the pages and scene plan are still written)}"
block "Playwright configs" "$(printf '%s\n' "$FILES" | grep -E '(^|/)playwright[^/]*\.config\.(ts|js|mjs|cjs)$' | head -5)"
block "Auth fixtures (storageState or a login setup; names only)" "$(printf '%s\n' "$FILES" | grep -E '(^|/)(e2e|tests?|playwright)/' | grep -E '\.(ts|js)$' | tr '\n' '\0' | xargs -0 -r grep -lE 'storageState|\.auth/|setup\(' -- 2>/dev/null | head -5)"
echo "- e2e specs (they hold the routes and selectors to reuse): $(printf '%s\n' "$FILES" | grep -cE '\.(spec|test|e2e)\.(ts|js)$' )"
if [ -f tools/docs-capture/scenes.json ]; then echo "- Capture tooling: tools/docs-capture/ · scenes: $(grep -c '"id"' tools/docs-capture/scenes.json)"
else echo "- Capture tooling: none yet (docs-init.sh creates tools/docs-capture/)"; fi

# The product's own words: UI labels and error messages come from here or from the screen, never from code names.
block "Locale and message files (UI labels, error text)" "$(printf '%s\n' "$FILES" | grep -E '(^|/)(locales?|i18n|lang|translations?|messages)/[^/]*\.(json|ya?ml|po|properties)$|(^|/)en(-US|_US)?\.(json|ya?ml|po)$' | head -8)"
p="$T/.claude/fde-client-profile.md"
if [ -f "$p" ]; then echo "- Client profile: $p (it decides what public text may say)"; else echo "- Client profile: none"; fi
exit 0
