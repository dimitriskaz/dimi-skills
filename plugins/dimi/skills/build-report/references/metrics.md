# Metric definitions, chart choice, widget states

Reference for `build-report`. Stack-agnostic; the examples are TypeScript-shaped but every rule holds for Python, Go, SQL or a BI tool's query.

## 1. The definition template

Every metric in the registry answers these, in code or in a docstring the tests assert against:

```
name:         activeTenantsLast30d              # named like the question, never metric7
question:     How many tenants used the product in the last 30 days?
decision:     whether the activation campaign changed anything
numerator:    distinct tenant_id with ≥1 event of kind in {login, api_call}
denominator:  none (a count) | tenants with status=active at window end (a rate)
window:       rolling 30 days, [now-30d 00:00, now) in the tenant's time zone; open day included and marked partial
excludes:     tenants with is_internal=true; deleted tenants; events with source=test
source:       rollup daily_tenant_activity (written by job rollup:activity), never the events table on read
freshness:    rollup time of the latest period; stale after 26 h
partial when: the latest period's rollup is missing, or the source cap (10,000 tenants) was hit
format:       integer, tabular; comparison = same window ending 30 days earlier
unit:         tenants
```

Shape in code (adapt to the stack):

```ts
export const activeTenantsLast30d = defineMetric({
  key: 'activeTenantsLast30d',
  label: 'Active tenants', unit: 'tenants', format: 'integer',
  window: { kind: 'rolling', days: 30, tz: 'tenant' },
  compute: (rows: DailyTenantActivity[], win: Window): MetricValue => {
    const inWin = rows.filter(r => win.contains(r.day));           // boundary rule lives in Window, tested once
    const partial = !win.isClosed() || rows.some(r => r.capped);
    return { value: new Set(inWin.map(r => r.tenantId)).size, partial, asOf: maxBy(inWin, 'computedAt') };
  },
});
```

`compute` is pure over its inputs, so the unit test is a fixture and a known answer. The loader (query, cache, tenant scope) is a separate function the e2e tests mock.

## 2. Chart by question

| The question is about | Use | Not |
| --- | --- | --- |
| how a value moves over time | line (one series per category, at most five); area only for a total that stacks | bar per day past ~30 points |
| how categories compare right now | horizontal bar, sorted by value, with the value labelled | pie, radar |
| what a total is made of | stacked bar (per period) or a single stacked bar; show the parts' values | pie for more than three parts; donut |
| how values are spread | histogram or box plot with the bin size stated | a line over sorted values |
| one number and its direction | stat tile with the comparison and its window named; sparkline optional | a gauge |
| which items need attention | table with status pill, sortable, with the figure that caused the status | cards per item |
| correlation between two measures | scatter with the sample size stated | dual-axis line |
| where (geography) | map only if the decision is geographic; else a sorted bar by region | a map as decoration |

Every chart: axis labels with units, ticks at values the data reaches, the zero baseline on bars, no truncated bar axis, the period boundary drawn when the window is open, the categorical palette from the repo's tokens with one semantic family (good / warn / crit) reserved for status, a table alternative, and `aria-label` naming what it shows and the headline value.

## 3. Widget states

| State | When | What the widget shows |
| --- | --- | --- |
| loading | the first request is in flight | a skeleton in the shape of the result; never a zero |
| empty | the query ran and returned no rows | "No <things> between <from> and <to>", with the filters named |
| unread | the request failed or timed out | "Could not load <metric>" and a retry; never a zero, never an empty state |
| partial | a cap or an unread source | the figure with a partial mark and the reason beside it (not in a page banner) |
| stale | freshness past the threshold | the figure with "as of <time>" emphasised; the global as-of also shows it |
| denied | the reader lacks the permission for this widget | "You do not have access to <metric>"; the rest of the page still loads |
| open period | the window includes today | the latest point marked "so far today" and excluded from the comparison |
| mismatch | the comparison window has no data | the comparison hidden with the reason, not "+100%" |

Actions (export, schedule, share): optimistic only when reversible; a partial success (some tenants exported) lists what was written; a permanent failure (403, 409) closes the flow.

## 4. Data path patterns

- **Rollup table**: `(tenant_id, period_start, grain, dimension…) → measures, computed_at, capped`. Unique on the key; the job upserts; a late event re-rolls its period; a `backfill --from --to` command exists.
- **Materialised view**: for warehouses that support refresh; the refresh time is exposed as freshness.
- **Bounded live query**: only with an index that matches the filter order and a row cap; the plan (`EXPLAIN`) goes in the PR body; the cap sets `partial`.
- **Cache**: keyed by (tenant, metric, window, filters); TTL at most the rollup interval; cache time shown as freshness.
- **Time**: cut windows in one declared zone (the tenant's, or UTC, never the browser's); store periods as dates in that zone; never use the browser clock to decide what is latest.
- **Identity**: normalise ids with the same helper the writer used; `NOT IN` drops NULL rows, enumerate the unknown case.
- **Exports**: stream rows from the registry's loader with the same filters; the file header carries the window, the time zone, the as-of time and `partial` when any metric was.

## 5. Tests that fail without the change

- Metric unit: fixture with a known answer; an event at the exact window end (excluded or included per the rule); the exclusion rule; the partial case.
- Rollup: run it twice (no duplicates); a late event (the period changes); a backfill over an already-rolled range (idempotent).
- Loader: the tenant scope (a second tenant's rows never appear); the denied case (403 → denied state, not empty).
- Screen: one e2e per state in §3, loader mocked; screenshots as evidence.
- Export: a golden file per fixture tenant.
- Job: dry run asserts recipients and the file; nothing sent.

## 6. Things reviewers reject

A pie with eight slices. A gauge. A bar axis that starts above zero. A "+100%" against an empty comparison. "0" where the request failed. Exact figures next to a "data may be incomplete" banner. A dashboard query without the tenant filter. The same metric computed in the page and in the export. A dashboard built by hand in the BI tool and screenshotted. A date range cut in the browser's time zone. A chart library added when one is in the lockfile.
