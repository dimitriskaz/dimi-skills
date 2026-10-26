---
name: release-notes
description: Produce release notes and illustrated product documentation from the merged work since the last release — notes grouped by module and feature, breaking changes and migration steps, plus a Playwright-captured screenshot for every module, feature and step against a running demo tenant, assembled into a versioned docs folder. Use before a release, for a customer-facing changelog, or with --docs to (re)generate the full illustrated documentation of the product.
argument-hint: "[from-ref..to-ref | version] [--docs] [--url http://localhost:3000] [--allow-host <host>] [--areas a,b]"
disable-model-invocation: true
---

# Release notes and illustrated docs

Two outputs from one pass: the **release notes** a reader skims (what you can do now, what changed, what to migrate) and the **illustrated walkthrough** they open when they want to see it — one screenshot per module, feature and step, captured by Playwright against a running demo tenant so the pictures match the code that shipped. With `--docs` the pass covers the whole product instead of the delta, and the same folder becomes the product documentation.

Triggers: `/dimi:release-notes`, "write the release notes", "document this release with screenshots", "generate the product docs", "what shipped since v1.4".

Never against production, never with real tenant data. Screenshots come from a local dev server or a preview deployment of a **seeded demo tenant**; the runner refuses hosts that are not on its allowlist: `localhost`, `127.0.0.1`, the host of the repo's Playwright `baseURL`, and any host passed explicitly with `--allow-host`. Nothing else is ever added by inference.

Without Playwright or an auth fixture, the skill still delivers the notes and the scene plan; only the capture is skipped (see §4).

## 0. Inputs

- **Range**: `$ARGUMENTS` as `v1.4.0..HEAD`, a single new version (then from the last tag), or nothing (last tag → HEAD). `--docs` ignores the range for the walkthrough and documents every module.
- **App URL** for screenshots (`--url`, default from the repo's Playwright config `baseURL`); a `--url` whose host is not `localhost`, `127.0.0.1` or the `baseURL` host (a preview deployment) also needs `--allow-host <that host>`, or the capture refuses it. Auth via the repo's existing Playwright `storageState`/login fixture — never credentials typed into this skill.
- `<KEY>`: the ticket key in the branch name (matching `${user_config.ticket_regex}`); none → ask the author.
- **Areas** (`--areas`) to limit the pass; default: every area touched in the range (`--docs`: all).
- Conventions: the repo's `CHANGELOG.md` format, docs folder, Playwright config, screenshot evidence conventions, release tagging in `CLAUDE.md`. `.claude/fde-client-profile.md` if present decides what may appear in client-facing text.

## 1. Collect what shipped

```bash
RANGE='<range from §0, empty when none>'                                              # e.g. v1.4.0..HEAD
[ -z "$RANGE" ] && { LAST=$(git describe --tags --abbrev=0 2>/dev/null); RANGE=${LAST:+$LAST..}HEAD; }   # default: last tag..HEAD
git log --merges --first-parent --format='%h %s' "$RANGE"                            # merge-commit repos
git log --first-parent --format='%h %s' "$RANGE" | grep -E '\(#[0-9]+\)$'            # squash-merge repos: PR number in the subject
git log --first-parent --format='%s' "$RANGE" \
  | sed -nE -e 's/^Merge pull request #([0-9]+).*/\1/p' -e 's/.*\(#([0-9]+)\)$/\1/p' | sort -un \
  | while read -r n; do gh pr view "$n" --json number,title,body,labels,mergedAt,files; done   # the PRs in exactly this range
```
Use whichever `git log` form returns rows for this repo; the PR list (built from the PR numbers in those subjects, so it covers exactly the range, not a date window) is the authority for titles and bodies. One row per PR (or per commit when PRs are not used): ticket key, type (feat/fix/chore/refactor), **area/module** (from paths and labels), user-facing or internal, breaking (schema, API, config, permission changes), the PR body's "What/Why/How tested". Drop pure chores and dependency bumps from the notes unless they change behaviour; keep them in a collapsed "Internal" section.

## 2. Draft the notes

Group by **module → feature**, not by PR. For each feature, in the user's words: what you can do now (one or two sentences), then "Changed" and "Fixed" bullets, each ending with the PR/ticket reference in parentheses. Separate sections:
- **Breaking changes and migration** — exact steps, in order, with the command or setting; who is affected.
- **Settings and permissions** — new options, changed defaults, new roles or scopes a customer must grant (connectors!), each with its default and where to set it.
- **Deprecated / removed** — with the replacement and the date it goes.
- **Known limitations** — what is deferred, with tickets.
- **Internal** (collapsed) — refactors, dependency updates, tooling.

Tone: plain, present tense, no marketing; a reader should be able to verify every sentence against the product. Nothing a client should not read (internal customer names, incident details) unless the audience is internal — say which at the top.

## 3. Plan the scenes

For every module and feature in scope, list the **scenes** to capture, one per step a user would take:
```yaml
# docs/releases/<version>/scenes.yaml  (committed; the capture is reproducible)
- id: imports-01-upload
  module: Imports
  feature: Spreadsheet import keeps relationships
  step: Upload a workbook
  route: /imports/new
  actions: [ {click: "text=Upload"}, {setInputFiles: ["[data-testid=file]", "fixtures/demo-workbook.xlsx"]} ]
  wait: "text=Preview"
  mask: ["[data-testid=user-email]"]                 # PII-shaped regions, covered by a solid box by Playwright
  viewport: desktop                                   # desktop 1440x900 @2x; mobile 390x844 optional
  caption: "Drop the workbook; the preview shows which columns become links."
```
Sources for scenes: the PR bodies, the e2e specs that reference the feature (they already know the routes and selectors), `ui-states-review` matrices if present. Include the risky states that matter to a user (an empty state, a partial-read banner) when the release changed them. Stable ids: `<module>-<nn>-<slug>`, so a re-capture overwrites the same file and the docs diff cleanly.

## 4. Capture with Playwright

First check the preconditions: `@playwright/test` is a dependency of the repo, a Playwright config exists, and an auth fixture (`storageState` or a login helper) exists. If any is missing, do not improvise one: write `scenes.yaml`, skip the capture, list every scene under "could not capture: <no Playwright | no config | no auth fixture>", and deliver the notes (§5–7) without images.

Write (or update) one small capture spec in the repo's Playwright language at `docs/tools/docs-capture.spec.(ts|js)` with its **own config** `docs/tools/playwright.capture.config.(ts|js)` (`testDir: '.'` — `testDir` resolves relative to the config file, so `'docs/tools'` there would point at `docs/tools/docs/tools` — importing the repo's config for `baseURL`, `storageState` and projects), run with `--config`. The Playwright runner only discovers files under the active config's `testDir`, so this keeps the capture out of the repo's default `playwright test` run — a spec placed inside the e2e `testDir` would be executed by every CI run of the suite. (Alternative, only when the repo insists on one config: put the spec under its `testDir` with `test.skip(!process.env.DOCS_CAPTURE, 'docs capture only')` at the top.) The spec reads `scenes.yaml`, uses the repo's config and auth fixture, and for each scene: navigates, performs the actions, waits, applies `mask`, and saves `docs/releases/<version>/img/<id>.png` (full page off by default; `fullPage: true` per scene when needed). Rules:
- Host allowlist in the spec, exactly the list from the top of this skill (`localhost`, `127.0.0.1`, the `baseURL` host, `--allow-host`); refuse anything else before the first navigation.
- Demo tenant only; the spec asserts the tenant name/badge on screen before the first capture.
- Deterministic rendering: fixed viewport, `deviceScaleFactor: 2`, animations disabled (`reducedMotion: 'reduce'`), a fixed clock if the UI shows relative times (`page.clock`; the repo's Playwright version must support it — check its changelog, else freeze time in the app's test hook), fonts loaded (`document.fonts.ready`).
- One scene at a time; retries once on timeout; a failed scene is listed, never silently skipped.
- Run it: `pnpm exec playwright test --config docs/tools/playwright.capture.config.ts` (or the repo's runner), never the whole suite. "No tests found" means the spec is outside that config's `testDir` (resolved relative to the config file, not the repo root) or does not match `testMatch`; fix that, do not widen the repo's config.

Then **look at every image** (open each PNG) before using it: right screen, right state, no real-looking personal data, no debug overlays. A screenshot nobody looked at is not evidence.

## 5. Assemble the docs

```
docs/releases/<version>/
  README.md        release notes (section 2) followed by the illustrated walkthrough
  scenes.yaml      the capture plan
  img/*.png        one per scene
```
Walkthrough structure: `## <Module>` → `### <Feature>` → numbered steps, each `![caption](img/<id>.png)` with the caption as the sentence a user needs, and a short "What changed in this release" line under the feature when in release mode. With `--docs`, the same structure covers every module and the folder is `docs/product/` (or the repo's docs path) with a "Last regenerated: <version>, <commit>" header.

Also: the `CHANGELOG.md` entry in the repo's format and, if the repo's `CLAUDE.md` release steps say so, the version bump — proposed, not committed.

## 6. Verify

- Every `img/` reference resolves; every scene in `scenes.yaml` has an image or is listed under "could not capture" with the reason.
- Every PR in the range appears once (notes or Internal); every breaking change has a migration step.
- Grep the folder for customer terms and personal-data shapes (emails, IPs) — none in text or filenames; images were inspected.
- No auth state near the docs: `git -C "$(git rev-parse --show-toplevel)" ls-files -o -c docs/ | grep -iE 'storageState|\.auth/' || true` must print nothing (top-level-relative, so it works from any subdirectory); such files are never staged, nor is `.claude/.cache/`.
- Links to tickets/PRs resolve. Markdown renders (`README.md` opened once).

## 7. Output

The folder path, the notes pasted inline for the reader, a table of scenes (captured / failed), and the proposed `CHANGELOG`/version change. Offer: export to the format the team publishes (Confluence/Notion paste, PDF via the repo's docs tooling), or `/dimi:commit-push-pr` with `docs(<KEY>): release notes and docs for <version>` — staging `docs/releases/<version>/`, the capture spec and `CHANGELOG.md` only; never anything matching `storageState|\.auth/` or `.claude/.cache/`.

Re-run on the next release; the stable scene ids mean only the changed screens produce image diffs.
