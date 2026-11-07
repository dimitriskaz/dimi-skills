---
name: build-report
description: Build a report or dashboard feature inside the codebase, in the codebase's own stack — a screen in the app, a scheduled report job (CSV, email, PDF), a dashboard-as-code definition for the BI tool the repo already uses, or an exploratory notebook — starting from the questions the reader must answer, with every metric defined once in a tested registry, data paths that hold at the repo's real scale, charts chosen by question, every widget state handled, filters in the URL and exports from the same definitions. Use when asked for a dashboard, an analytics or metrics page, a reporting feature, a KPI view, an overview screen or a scheduled report.
when_to_use: "Triggers: /dimi:build-report, \"build a dashboard\", \"add a reports page\", \"we need an analytics view\", \"KPI screen\", \"metrics overview\", \"weekly report email\", \"export this as CSV\", \"a Grafana dashboard for this service\"."
argument-hint: "[what the reader needs to decide, or the ticket key; optional --surface screen|job|bi|notebook]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
disable-model-invocation: true
---

# Build a report inside the codebase

A dashboard that nobody can make a decision from is decoration, and a dashboard whose numbers two screens compute differently is a bug. This skill builds reporting features the way a reviewer would accept them: questions first, one tested definition per metric, data paths that hold at the real tenant size, honest states on every widget, and the repo's own libraries and blocks rather than new ones.

Triggers: `/dimi:build-report`, "build a dashboard", "add a reports page", "analytics view", "KPI screen", "weekly report email", "export as CSV", "a Grafana dashboard for this service".

## 0. What the repository already has

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/build-report.sh`

Read this before deciding anything. A chart library in the lockfile is the chart library. A metric that exists is reused, never re-derived. A tenant or permission helper is the only way a query runs. The `SCALE` line (or the `pr-self-review` policy block) is the size every data path is designed for; if there is none, ask for it or state the assumption in the plan.

## 1. Questions, readers, decisions

Before any widget, write the **question list**: for each question, who asks it, what they decide from the answer, how often, and what "good" looks like. Three to seven questions; a dashboard answering twelve answers none. Ask the author (AskUserQuestion, one at a time, with a recommended answer each) until the list is stable. A ticket without questions gets them proposed and marked `proposed`.

From the questions, choose the **surface** (`--surface` overrides):

| Surface | Choose when | Built as |
| --- | --- | --- |
| `screen` | users or operators read it inside the product, interactively, with filters | a page or route in the app, using its component blocks and chart library |
| `job` | the reader gets it on a schedule or on demand as a file (CSV, XLSX, PDF, email) | a job in the repo's scheduler with the delivery it already has |
| `bi` | engineers or analysts read it in a tool the repo already configures (Grafana, Metabase, Superset, Looker) | a committed definition file, provisioned the way the repo provisions them |
| `notebook` | one person is exploring, the answer is not yet known, nothing ships | a notebook or Streamlit page under the repo's existing convention for them, never a product route |

Each surface reads the same metric registry (§2). A `screen` and a `job` for the same questions share every definition; the screen never computes what the job exports.

## 2. The metric registry

One module, one definition per metric, in the stack's language, named like the question (`activeTenantsLast30d`, not `metric7`). Each definition carries, as code or as a docstring the tests check: what is counted (numerator), out of what (denominator, or none), the time window and its boundaries (inclusive end? calendar or rolling?), the time zone the window is cut in, the filters applied by default, what is excluded (deleted, test, internal, draft), and when the number is **partial** (a cap hit, a source unread, a day still open). The template and the chart-by-question table are in [references/metrics.md](references/metrics.md); read it before writing the first definition.

Rules:
- Search for an existing definition of each metric (the state above lists candidates) before writing one. Two definitions of one number is a `pr-self-review` Blocker; if the existing one is wrong, fix it in place and let every caller benefit.
- A definition is pure over its inputs where the language allows it, so the unit test is a fixture with a known answer, not a database.
- The registry exposes the metric's **metadata** (label, unit, format, window, freshness, partial flag) alongside the value; the screen renders from it, so a renamed metric renames everywhere.
- Comparisons (previous period, target) are definitions too, with the same window rules.

## 3. The data path at real scale

Design against the `SCALE` line, and the repo's `data-reads` rule where it has one:
- **Never aggregate history on a page load or a poll tick.** Precompute: a rollup table or materialised view written at collect time or by a scheduled job, keyed by (tenant, period, dimension); the screen reads the rollup. A bounded live query is acceptable only when the index proves it (run `EXPLAIN` or the equivalent and keep the plan in the PR body).
- **Freshness is shown, not implied.** Every number carries when it was computed; a rollup that failed last night shows last night's number marked stale, not today's number.
- **Caps mark the number partial.** A query capped at N rows, a timeout, an unread source: the metric returns `partial: true` and the widget says so beside the figure. A banner next to an exact-looking number is wrong.
- **Tenant scoping on every read**, through the helper the state lists; a dashboard query is the classic place a tenant filter is forgotten. Per-widget permission: a reader without the right sees a named denied state for that widget, never a zero.
- **Filters are bounded.** Date ranges have a maximum span tied to the rollup grain; free-text filters are validated server-side; dimensions come from pickers.
- **Run it twice.** A rollup job is idempotent per (tenant, period): a retry upserts, a late-arriving event re-rolls that period, a backfill command exists and is documented.
- **Exports** stream from the registry with the same filters and the same partial flag in the file header; they never run a second query the screen does not.

## 4. The screen (surface `screen`)

- Layout follows the question order: the summary question first, as a stat row only when the numbers are the point, then one widget per question. Drill-down goes from a figure to the list that explains it, with the same filters.
- **Chart by question** (table in `references/metrics.md`): trend over time is a line, comparison across categories a bar, composition a stacked bar, distribution a histogram, a single state a stat with its comparison, a status list a table. A pie needs a reason. Every chart has a table alternative (toggle or on hover) and uses colour as a second channel only; the categorical palette comes from the repo's tokens.
- **States per widget**, with the `ui-states-review` rules: loading (skeleton the shape of the result), empty (zero rows, with the date range named), unread (the request failed: a named failure, never a zero), partial (figure marked, reason shown), stale (freshness shown), denied (permission), and a global "data as of" with the rollup time. Partial success on an action (an export of some tenants) shows what was written.
- **Filters live in the URL** (query string), so a view can be sent; defaults are explicit; the date range shows its time zone.
- **Numbers**: tabular figures, units in the label, rounding stated where it hides a difference, comparison direction coloured by the semantic family only (up is not always good).
- Reuse the repo's blocks (table, card, empty state, error banner, date-range picker) and its chart wrapper if one exists; a new wrapper is written once in the shared place, not per page.

## 5. The other surfaces

- **`job`**: the scheduler and delivery the repo already has; one job per report, idempotent per (tenant, period), with a dry-run flag that writes the file without sending; recipients and schedule in settings, not in code; the file name carries the period and the tenant; a failed send is retried by the queue and reported, never silently skipped. PDF only when the repo already renders PDFs; otherwise CSV or XLSX from the registry.
- **`bi`**: the definition file in the repo's provisioning folder, with the queries read from the same rollups the app reads (or from the registry via a view), variables for tenant and period, a title that names the question, and the dashboard's own alert thresholds in the file. Never a dashboard built by hand in the tool and screenshotted into the PR.
- **`notebook`**: under the repo's existing notebook convention, reading through the same data layer and tenant helper, outputs cleared before commit, no credentials in cells. If the finding is worth keeping, it becomes a metric in the registry and a ticket for a `screen` or `job`; the notebook is not the product.

## 6. Tests

- Each metric: a unit test on a fixture with a known answer, including the window boundary (an event at the exact end of the period), the exclusion rule, and the partial case.
- The rollup: a run-it-twice test (same input, no duplicates) and a late-event test (the period is re-rolled).
- The screen: one test per state in §4 through the repo's e2e runner, mocked at the loader; a screenshot per state under the repo's evidence convention; the `ui-states-review` matrix for the page.
- The export: a golden file for a fixture tenant, checked in.
- The job: a dry-run test that asserts the file and the recipients, with nothing sent.

## 7. Build through the loop

`plan-from-ticket` first (the question list and the metric registry go in the plan, the `SCALE` assumption in its header); then build in the commit order *registry and tests → rollup or query and tests → surface → export → docs*; `ui-states-review` on the screen; `tidy`; `pr-self-review` with the `EXPLAIN` output and the states' screenshots as evidence; `commit-push-pr`. The PR body states each metric's definition in one line so the reviewer can check the number without reading the code. Never commit or push without the author's yes.

A report about the report (what was built, for whom, how it was tested) is `/dimi:report`, not this skill.
