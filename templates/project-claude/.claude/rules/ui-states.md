---
paths:
  - "apps/**/*.{tsx,ts}"
---
# UI states and truthfulness

- Unread is not empty. A failed or forbidden request renders as a named failure for that section, never as "none exist" or a zero.
- Headline numbers computed from partial or truncated inputs are marked, not shown as exact.
- After partial success, show what was written; retry applies only to the rest. Never "Nothing was linked" when links exist.
- A permanent failure (stale-version 409, 403, validation 400) closes or re-proposes the flow; no retry button that can only fail again.
- Values shown with a result are the values of that run (thresholds, settings), not today's.
- Labels mean what they count: "mapped" is not "covered"; "linked to a test" is not "tested"; retired or draft items are not active.
- Constrained values use pickers or lookups, never free text or raw JSON. Send only changed keys; keep edits on error.
- Colours and spacing come from design tokens; no raw hex in `src`; one semantic status family.
- Use the shared blocks (table, drawer, card) over raw primitives; every ARIA role carries its keyboard model.
- No re-fetch on every mount or focus without a shared cache; no browser `Date.now()` deciding what is newest or overdue.
