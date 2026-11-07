---
name: report
description: Generate a beautiful, self-contained HTML report about a ticket, a branch, a codebase, a review, an investigation or a release — verdict first, what changed, how it works, how it was tested, findings, risks — with code references, a diagram and screenshots, built from verified facts (git, the code, the reports other dimi skills wrote) and styled by a tested template that reads offline, in light and dark, and prints to PDF. Use when handing work over, summarising a ticket for a reviewer or a client, documenting what a codebase is and where its risks are, or turning a review or a debugging session into something a stakeholder can read.
when_to_use: "Triggers: /dimi:report, \"make a report about this ticket\", \"write up what I did on this branch\", \"generate an HTML report\", \"summarise this codebase for the client\", \"turn the review into a report\", \"a nice page I can send to the team\", \"document this investigation\"."
argument-hint: "[ticket key | path | range | #pr | question; --kind ticket|codebase|review|investigation|release --audience reviewer|newcomer|client|stakeholder --out <dir>]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
---

# Report: one HTML page someone can read, send and keep

A report is the page you hand to the person who was not in the session: the reviewer picking up your branch, the client asking what they got, the teammate inheriting a codebase, the manager asking what the incident was. It is built from facts that were checked (git, the code, commands that ran, reports other skills already wrote), never from memory of how such work usually goes, and it is one file that opens from disk with no network, reads in light and dark, works on a phone and prints to PDF.

Triggers: `/dimi:report`, "make a report about this ticket", "write up what I did", "summarise this codebase for the client", "turn the self-review into a report", "document this investigation", "a page I can send to the team".

## 0. Facts (pre-computed)

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/report.sh '${user_config.default_branch}' '${user_config.ticket_regex}'`

These are the numbers the report quotes (commits, files, lines, tests, languages, churn, size). Never restate a number the script did not print or a command did not output. If the subject is an explicit range, run the script again with it as the third argument.

## 1. Subject, kind, audience

- **Subject** from `$ARGUMENTS`: a ticket key, a branch or range (`v1.4.0..HEAD`), a PR number, a path (`services/import`), or a question ("what is the state of the auth module"). Nothing given: the current branch when it is not the default branch, else the whole repository.
- **Kind** (`--kind`, else inferred): `ticket` (a branch, key or PR: what was done and whether it is ready), `codebase` (a repo or path: what it is, how it is built, where the risk is), `review` (render an existing review report: self-review, `review-agent`, `harden-mcp`, a colleague's review), `investigation` (a bug or incident: timeline, root cause, fix, proof), `release` (a range: what shipped, what to migrate). Section lists per kind in [references/shapes.md](references/shapes.md); read the one that applies.
- **Audience** (`--audience`, default `reviewer`): *reviewer* keeps `path:line` inline and leads with risk; *newcomer* gets vocabulary and order; *client* and *stakeholder* get behaviour, outcomes and decisions with no file paths in the body (they move to a collapsed appendix), and nothing `.claude/fde-client-profile.md` forbids. Internal customer names, incident details and secret-looking lines never appear in a client or stakeholder report.
- **Output**: `$OUT/report-<slug>-<YYYY-MM-DD>.html`, where `$OUT` is the session's scratchpad directory if it gives one, `--out` if given, else `<top>/../report-<repo>/` next to the checkout. Never inside the repository: Claude can load this skill on its own and must not leave a tracked file behind; the author copies it into a docs folder if the repo has that convention.

## 2. Gather, do not recall

Read before writing, and keep the raw material out of this conversation:

- **What other skills already produced**, listed under *Files in …* above: the latest self-review report (findings, verdict, "checked, nothing found"), the plan from `plan-from-ticket` (acceptance criteria, decisions), a walkthrough, a debug log. Reuse their findings and ids verbatim; do not re-review.
- **The ticket or PR**: a Jira/Linear connector or `gh pr view <n> --json title,body,reviews,statusCheckRollup` when available, else ask for a paste. Acceptance criteria come from there, in the ticket's words.
- **The code**: use the `explore` agent, one call per question (the entry point and the path through; every write and its gate; the tests that pin the behaviour; the config that changes it), asking for `path:line` for everything. For a codebase report also ask for the module boundaries, the second implementation of anything, and what the churn hotspots in the facts above actually contain.
- **Evidence**: the commands that ran and their last lines (tests, typecheck, lint), screenshot files under the repo's evidence convention or in `$OUT`. A check that did not run is reported as not run, with the command that would run it.

Rules: every claim in the body has a `path:line`, a commit, a command or a ticket behind it. What could not be confirmed is marked *unverified* in the text, never dropped and never asserted. Numbers come from the facts block or a command output. No lorem ipsum, no invented metrics, no example data from the template left in.

## 3. Outline before HTML

Write the outline as a list first (section → the two or three things it must say → the evidence it cites). Lead with the verdict and the one thing the reader must do; put detail in collapsed sections; cut a section that would be padding (a ticket with no UI has no screenshot gallery; a codebase with no incidents has no timeline). The reader should get the answer from the summary alone and go deeper only by choice.

## 4. Build the page from the template

Start from `${CLAUDE_SKILL_DIR}/references/template.html`: read it once, copy it to the output path, keep the `<style>` block and the `<script>` block as they are, and replace the content between them. The template is a complete example ticket report (fictional "ABC-123") so every component is shown in use; delete what the outline does not need.

Components and when to use them:

| Component | Use for |
| --- | --- |
| `.masthead` | kind · repo · branch crumbs, the title (a name, two to five words, never "Report on …"), a two-sentence lede, meta (ticket, as-of commit and date, audience, range) |
| `.verdict good|warn|crit` | the one-line status and the one thing to do; always first in Summary |
| `.stats` | three to five numbers, only when the numbers are the point (size of a change, health of a codebase); never decoration; a tile carries its comparison or trend in the `.d` line (against the base, the last release, the target) or it is a count, not a KPI |
| `.tbl` tables | commits, changed files with `.bar` widths scaled to the largest row, checks run, settings |
| `ol.timeline` | the path data takes, or the sequence of an investigation; `li.crit` / `li.good` mark the failure and the fix |
| `figure.diagram` (inline SVG) or `pre.mermaid` | the system shape, boxes named as the code names them, arrows carrying the data shape; Mermaid renders when the reader is online and stays readable as source when not |
| `.code` with `.fn` | an excerpt of at most 15 lines with its path and line range; `.hl`, `.add`, `.del` on lines |
| `details.finding` with `data-sev` and the `.filters` buttons | findings with severity, id, where, why it matters, status; counts in the filter labels must match |
| `.callout good|warn|crit|info` | "checked, nothing found", a risk, a decision, an unverified claim |
| `.bars` with `--v`/`--max` | a small comparison that must be read to scale (relations per workbook, tests per module) |
| `figure` + `.gallery` | screenshots as `data:` URIs (keep the whole file under 5 MB; downscale PNGs) or relative `img/` paths beside the HTML, with a caption that says what the picture proves |
| `details` in Appendix | the full file list, commands, glossary, the `path:line` footnotes of a client report, the regenerate command |

Rules for the page:
- Semantic colour means something: `good` passed or fixed, `warn` should fix or not run, `crit` blocker or failed, `info` minor or a note. Never colour for emphasis.
- `<title>` is the name of the report; the `.crumbs` carry the kind. The TOC lists every `section id` in order and nothing else.
- Keep the token block untouched unless the repo has a `.claude/report-theme.css`; then inline that file's contents right after the `:root` block so its tokens win (a client's colours and faces live there, never in this plugin).
- Fonts load from Google Fonts with system fallbacks; nothing else is fetched. No other scripts, no CDN CSS, no iframes, no tracking.
- No emoji, no exclamation marks, no marketing. Present tense, plain words, one idea per sentence, by `${CLAUDE_PLUGIN_ROOT}/skills/prose/SKILL.md`. Expand an acronym the first time.
- A client or stakeholder report has no `path:line` in the body: number them `[1]`, `[2]` and resolve them in the Appendix.

## 5. Verify, then look once

```bash
grep -nE 'ABC-123|example-app|a1b2c3d|placeholder|lorem|TODO|\{\{' '<output path>'      # must print nothing: template examples left in
grep -oE '<li><a href="#[a-z0-9-]+"' '<output path>' | sort -u                              # every TOC target …
grep -oE '<section id="[a-z0-9-]+"' '<output path>' | sort -u                              # … matches a section id, and vice versa
```
Then re-read the page against the sources once: every `path:line` resolves at the as-of commit, every finding id exists in the report it came from, every number matches the facts block, filter counts match the findings, no customer term or secret-looking line (grep the page for `(api|secret|token|password)[_-]?(key)?\s*[:=]`). If Playwright and a browser are available, screenshot the file at 1280 and 400 px wide and look at both; otherwise open it in a browser. One pass of fixes, then stop; polish is for the reader to request.

## 6. Deliver

Print the absolute path, then the Summary section's verdict and the one thing to do, inline. Offer, without doing any of them unasked: copy into the repo's docs folder (the author stages it; never `git add -A`), a PDF via the browser's print dialog (the print stylesheet is built in), or publishing as an artifact — only for a report with no customer data, no secret-looking lines and no internal findings, and never for a client report without the author's yes. The footer carries the as-of commit and the regenerate command (`/dimi:report <same arguments>`); a report older than the code it describes is wrong, so say when to regenerate.

If writing the report exposed something that should not exist (a second write path, an untested migration, a cap nobody knew about), that is a finding for `pr-self-review` or a ticket, not a sentence in the report's prose; list it under Risks and follow-ups with an owner.
