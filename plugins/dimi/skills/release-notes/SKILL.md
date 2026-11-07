---
name: release-notes
description: Public product documentation for an enterprise product, generated from the running app and kept current every release — task-based pages for every module and feature with a screenshot for each step, getting started, roles and permissions, settings, limits, troubleshooting and a glossary, public release notes per version, and a Word release document with screenshots to send customers — written for customers in the product's own words, with no code, ticket, PR, commit or environment reference anywhere in the published folder, and an internal trace kept outside it. Use before a release to update the docs and write the release notes, or with --docs to generate the whole product documentation.
argument-hint: "[ticket key | from..to | version] [--docs] [--areas a,b] [--audience public|internal] [--url <app url>] [--allow-host <host>] [--out <published docs folder>] [--doc-out <folder for the Word document>]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Product documentation and release notes

The documentation customers, administrators and evaluators read on the public docs site: what the product does, how to do each task step by step with the screen in front of them, what each role may do, what every setting means, what to do when something goes wrong, and what changed in each release. It is generated from the running product, so every screenshot is the screen that shipped and every label is the label on it, and it is regenerated each release so it never drifts.

**Everything in the published folder is public.** No file path, code identifier, PR or ticket number, commit hash, internal codename, team or employee name, environment name, feature-flag key or test-data label appears there. The trail from each sentence back to the work that shipped it lives in an internal trace outside the published folder.

Triggers: `/dimi:release-notes`, "update the product docs", "write the release notes", "the release document in Word", "document this release with screenshots", "generate the user documentation", "what shipped since v1.4".

Never against production, never with real tenant data. Screenshots come from a local dev server or a preview deployment of a **seeded demo tenant**; the capture refuses hosts that are not on its allowlist: `localhost`, `127.0.0.1`, the host of the repo's Playwright `baseURL`, and any host passed explicitly with `--allow-host`. Nothing else is ever added by inference.

## 0. What the repository has

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/release-notes.sh`

## 1. Mode, audience and the two folders

- **Mode.** A ticket key (`ABC-123`, matching `${user_config.ticket_regex}`) makes that ticket's feature the subject: the release is the merged work since the last tag, and the feature the ticket built is what the Word document explains. A range (`v1.4.0..HEAD`; a version means from the last tag; nothing means last tag to `HEAD`) does the same with the release's most important feature as the subject (ask the author when two compete). Either way the run updates the pages the release touched, retakes their screenshots, writes the release notes page and builds the Word release document (§7). `--docs` documents the whole product, for a first run or a full refresh. `--areas imports,billing` limits either mode to those modules.
- **Audience.** `public`, the default, is everything below. `--audience internal` writes only a team changelog (PR and ticket references on every line, an Internal section for refactors and tooling) to `tools/docs-capture/releases/<version>-internal.md`, with no public pages and no capture.
- **Published folder** (`PUB` below): `--out`, else the docs location the repo's `CLAUDE.md` names, else the framework's published root from §0, else `docs/product/`. Every file inside it is published.
- **Release document folder**: `--doc-out`, else the session's scratchpad directory if it gives one, else `<top>/../release-notes-<repo>/` next to the checkout. Never inside the repository: the Word document is a deliverable sent to customers, not a tracked file.
- **Tools folder**: `tools/docs-capture/`, holding the capture spec and config, `scenes.json`, upload fixtures and `releases/<version>-trace.md`. It must sit outside every published folder. Check the framework's configuration (the Docusaurus docs path, MkDocs `docs_dir`, Mintlify navigation, Starlight's content folder) and say in the plan that the two do not overlap.
- **The product's own words.** The product name, module names, UI labels and error messages come from the screen and the locale files listed in §0, never from component, route, table or flag names. Ask the author once for what is not on screen: the product name if it varies, the roles to document, the support contact the troubleshooting page points to.
- **Constraints.** `.claude/fde-client-profile.md`, when present, decides what public text may say. The repo's `CLAUDE.md` may name a docs convention, a deny list of internal terms (codenames, team names) for the gate in §8, and the docs build command.

## 2. What shipped (range mode)

```bash
RANGE='<range from §1, empty when none>'                                              # e.g. v1.4.0..HEAD
[ -z "$RANGE" ] && { LAST=$(git describe --tags --abbrev=0 2>/dev/null); RANGE=${LAST:+$LAST..}HEAD; }   # default: last tag..HEAD
git log --merges --first-parent --format='%h %s' "$RANGE"                            # merge-commit repos
git log --first-parent --format='%h %s' "$RANGE" | grep -E '\(#[0-9]+\)$'            # squash-merge repos: PR number in the subject
git log --first-parent --format='%s' "$RANGE" \
  | sed -nE -e 's/^Merge pull request #([0-9]+).*/\1/p' -e 's/.*\(#([0-9]+)\)$/\1/p' | sort -un \
  | while read -r n; do gh pr view "$n" --json number,title,body,labels,mergedAt,files; done   # the PRs in exactly this range
```
With a ticket key, the feature's own PRs are the ones whose title or branch carries the key (`gh pr list --state merged --search '<KEY> in:title'`, or `git log --grep '<KEY>'` on the default branch), and the ticket itself (a Jira or Linear connector, else a paste) gives the problem it solves and its acceptance criteria. Use whichever `git log` form returns rows; the PR list (built from the PR numbers in those subjects, so it covers exactly the range) is the authority for titles and bodies. One row per PR in the trace: module and feature, type (new, improved, fixed, breaking, deprecated, removed, internal) and the change a user sees, in one sentence of product language. Internal rows (refactors, dependency bumps, tooling, tests) stay in the trace. A user-facing change with nothing new to show on a page (a speed-up, a rarer error) still gets a release-notes line written as its effect ("Large workbooks import faster"), never with a number nobody measured.

## 3. The documentation set

```
PUB/
  index.md                          what the product does, who it is for, where to start
  getting-started/                  sign in, first-run setup, key concepts, a first task end to end
  <module>/
    index.md                        concept page: what the module is for, its terms, who can use it
    <task>.md                       one task per page, a screenshot per meaningful step
  reference/
    roles-and-permissions.md        what each role can do, as a table
    settings.md                     every setting: what it does, its default, who can change it
    limits.md                       sizes, counts and rates a user can reach, and what happens at the limit
    glossary.md                     product terms as the product uses them
  troubleshooting.md                messages the product shows, what causes each, what to do
  release-notes/<version>.md        one page per release
  img/<module>/<scene id>.png
```
Before writing the first page, read [references/pages.md](references/pages.md) (page templates, front matter, callout and navigation syntax per framework) and [references/style.md](references/style.md) (the writing standard every page follows). In range mode, update touched pages in place, add pages for new tasks, delete pages for removed features (with a redirect where the framework supports one), and update the glossary, permissions, settings and limits pages when the release changed them. Keep the framework's navigation (sidebar, `nav`, `_meta`) in step with the pages.

## 4. Write the pages

The full standard is in `references/style.md`; these are the rules that decide whether a page is usable:
- A task page covers one task, with a title that starts with a verb in the user's terms ("Import a spreadsheet") and three to ten steps; a longer task splits into pages.
- **Before you begin** lists the role, plan or licence, and the data or setup the task needs.
- Steps are numbered, one action each, location first ("In **Imports**, select **New import**."), with UI labels in bold exactly as on screen. The result follows the step that produces it, as a plain sentence.
- A screenshot appears where the screen changes in a way the reader needs to see: the first step shows where in the product the task starts, the last shows the result. Every image has alt text that says what it shows.
- Concept pages come before their module's tasks; reference pages are tables.
- Facts a user can hit are verified in the code and written as the user meets them: limits (file size, rows, rate), defaults, who can do what, what cannot be undone. A fact you could not verify is not written; it goes to the open questions in the hand-off.
- Troubleshooting is built from the messages the product actually shows (the locale files): the message as displayed, what causes it, what to do, and when to contact support.

## 5. Plan the scenes

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/docs-init.sh 'tools/docs-capture' '<PUB>'
```
It copies the capture files from this skill (tested with `@playwright/test` 1.63 on Chromium) and a `scenes.json` skeleton, never overwrites a file the repo already has, and says when an existing copy differs. Then fill `scenes.json`, one scene per screenshot a page uses; the fields and the screenshot standard are in [references/capture.md](references/capture.md). The rules that matter most:
- **Each scene is self-contained.** Every scene runs in a fresh page, so it starts at its route and replays every action that leads to its state.
- Ids are `<module>-<nn>-<slug>` and stable, so a re-capture overwrites the same file and only changed screens produce image diffs.
- Selectors come from the repo's e2e specs or are role selectors (`role=button[name="Upload"]`), never generated class names.
- `tenant` is text only the demo tenant shows; the spec refuses to capture without it. `allowHosts` holds the repo's `baseURL` host and any `--allow-host`, nothing inferred. `roles` maps a scene's `as` to the signed-in state the repo's auth setup writes.
- `style.hide` removes development and environment chrome (dev overlays, environment banners, cookie banners, debug panels, support chat). `style.mask` covers every region that can show personal data (the user menu, avatars, email fields, audit actors), in every scene.
- Upload fixtures live in `tools/docs-capture/fixtures/` with obviously fictional data, never real-looking organisations.

## 6. Capture

First check the preconditions: `@playwright/test` is a dependency, a Playwright config exists, and the sign-in the scenes need exists (a `storageState` file or a setup project). If any is missing, do not improvise one: write the pages and `scenes.json`, skip the capture, and list every scene under "could not capture: <reason>". Then:
```bash
npx playwright test --config tools/docs-capture/playwright.capture.config.ts      # DOCS_URL=<url> for a preview deployment
```
The capture has its own config, so the repo's own e2e run never picks it up. A failed scene is retried once and listed, never skipped silently. Then **look at every image** with the checklist in `references/capture.md`: the right screen and state, the right role, nothing internal on screen, nothing personal unmasked. A wrong image is retaken or listed; it is never used.

## 7. Release notes and the trace

- **Public**: `PUB/release-notes/<version>.md` from the template in `references/pages.md`: the date, a two-sentence summary, then New, Improved, Fixed, Breaking changes (each with what to do, in order), Deprecated and removed (with the date and the replacement), and Known limitations, each item linking to the page it changed. No PR, ticket or commit references.
- **Word release document**: the feature this release delivers, explained so a customer can understand and use it from the document alone: a cover with a two-sentence summary, a contents list, the summary, the action required with dates, then the feature (what it is, who can use it, before you begin, how to use it step by step with screenshots, its settings, good to know), availability and support. Everything else the release contains (other improvements, fixes, other setting changes, deprecations, known limitations) goes in an appendix on its own page, left out when empty. Write its Markdown source from the template in [references/release-doc.md](references/release-doc.md) to `<release document folder>/<Product> <version> - <Feature>.md`, using the screenshots this run captured, then build it:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/release-doc.sh '<source .md>' '<release document folder>/<Product> <version> - <Feature>.docx' '${user_config.release_doc_template}' '${user_config.ticket_regex}' '<deny regex or empty>'
  ```
  It gates the source like a docs page, refuses links that only work on the website, converts with pandoc using the company template when the `release_doc_template` option names one, and renders page previews when LibreOffice is installed. Read every preview (or page through the document in Word) before the hand-off. Without pandoc it prints the install command; say so in the hand-off and leave the source ready to convert.
- **Internal**: `tools/docs-capture/releases/<version>-trace.md`: a table from each public sentence to its PR, ticket and commit; the internal rows from §2; the scenes retaken; the open questions.
- Propose the `CHANGELOG.md` entry in the repo's format and, if the repo's `CLAUDE.md` release steps say so, the version bump; propose, never commit.

## 8. Gate and verify

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/docs-check.sh '<PUB>' '${user_config.ticket_regex}' '<deny regex of internal terms from CLAUDE.md, or empty>'
```
It must report zero to fix before the hand-off. It fails a page on source paths, PR or issue numbers, ticket keys, commit hashes, local or preview hosts, test ids, working markers, local file paths, the deny list, internal files in the folder, missing images, images without alt text, and pages without a title or description. Each REVIEW line (environment-variable-shaped words, "staging", alt text that reads like a file name, unused images, code blocks) is resolved or explained. Then:
- Run the docs build once if the repo has one (the command `CLAUDE.md` names, or a `docs:build` script).
- Every page is reachable from the navigation; every scene has an image or is listed under "could not capture".
- No signed-in state near the docs: `git ls-files -o -c '<PUB>' tools/docs-capture | grep -iE 'storageState|\.auth/'` prints nothing.
- Read the index page and one task page as a customer who has never seen the product. Anything they could not follow is fixed now.

## 9. Hand-off

Report the pages created, updated and removed; the release notes path; the Word release document's path (or why it was not built); a table of scenes (captured, retaken, failed); the open questions (facts not verified, labels not on screen); and the gate result. Offer `/dimi:commit-push-pr` with `docs(<KEY>): product docs and release notes for <version>` (the key from the branch name, matching `${user_config.ticket_regex}`), staging `PUB` and `tools/docs-capture/` only; never a signed-in state file and never `.claude/.cache/`.

Re-run on the next release: stable scene ids mean only the changed screens produce image diffs, and the gate keeps the published folder clean.
