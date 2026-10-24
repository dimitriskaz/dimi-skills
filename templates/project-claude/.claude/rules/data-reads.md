---
paths:
  - "services/**/*.{ts,py}"
  - "packages/**/*.ts"
---
# Data access and scale

- Never read whole result history on a list/detail route, page load or poll tick; it grows forever. Write a latest-per-key summary at collect time and read that.
- Every cap, page limit or timeout must either error past the limit or mark the numbers derived from it as partial. A banner beside exact-looking numbers is wrong.
- A cap must match the thing it fronts: a listing capped at N and a held-records read capped at M>N re-creates everything between them on every run.
- Normalise ids (trim, case) with the same helper on store and lookup. `'ABC-01 '` stored untrimmed is duplicated on every re-import.
- Keys carry everything that distinguishes two records: source instance, not just source type; external id plus source system; version, not just clause. Never a ticket id or customer reference.
- Second run with identical input creates nothing. Name the lock, lease or unique constraint; an in-process Map is not one when there is more than one instance.
- Serial awaits inside one request (one PATCH per row, one edge per link) time out at scale. Batch, bulk, or bounded concurrency.
- `NOT (status IN (...))` drops NULL rows. Enumerate the missing/unknown case explicitly.
- `startsWith` on resource ids matches siblings (`app-pro` vs `app-prod`). Anchor on the full id or a `/` boundary.
- Verify steps fail on mismatch. A check that computes `matches` and returns success either way is not a check.
- Thresholds live on the thing they govern (the test), not on the connection; validate shape and range server-side; audit who changed what from what to what.
