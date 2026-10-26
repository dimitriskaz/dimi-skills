---
name: "ui-states-review"
description: "Review a UI change for every state a screen or action can be in — loading, empty vs unread, partial, stale, permission-denied, partial success, permanent vs retryable errors — plus forms, data truthfulness, design-token compliance and keyboard models, and list the Playwright coverage those states need."
argument-hint: "[component or page paths]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
---

# UI states review

Use before committing a UI change, or when `pr-self-review` meets a diff with substantial frontend work. Triggers: `/dimi:ui-states-review`, "review this screen", "check the states of this component", "is this page ready", "UX pass on my changes".

This covers what the design skills do not: *behaviour under every state*. If the `design` plugin is installed: for a deep WCAG audit use `design:accessibility-review`; for copy `design:ux-copy`; for visual critique `design:design-critique`. This skill names the states, checks each is handled and truthful, and says which ones need a test.

## 0. Inputs

- A diff or a list of components/pages. For a diff, build it first — the session's scratchpad path in the second argument if it gives one, else `''` (output in `<top>/../ui-states-review-<repo>/`, absolute):
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh build ui-states-review '' '${user_config.default_branch}' '${user_config.demo_marker}' '${user_config.demo_branch}' '${user_config.ticket_regex}' '${user_config.local_checks}'
  ```
  It prints the Review context (`Top`, `Out`, `Diff`, `Base`, `Head`, `Report`, options); write those values literally into later commands (`Report` is printed but only `pr-self-review` writes one) — each Bash call is a fresh shell, and a command that expands a variable cannot be pre-approved.

  Read each changed component **and** the hooks/loaders it uses; the states live in the loader, the symptoms in the component.
- If a browser tool or Playwright is available and the app runs locally, drive the real screen through the states below and take screenshots; otherwise reason from code and say so.

## 1. Inventory

For each changed screen or component list:
- **Data sources**: each request it depends on; whether required or optional; whether paged, capped or polled; the cache if any.
- **Actions**: each write the user can trigger; single-step or propose-then-commit; destructive or not.
- **Permissions**: who can see it, who can act; what the API returns to a user without rights.

## 2. State matrix per data source

Fill this table for every data source; a blank cell is a finding.

| State | What the user sees | Must never | Test exists? |
|---|---|---|---|
| Loading | skeleton or spinner scoped to the region, layout stable | flash of "0" or "none" | |
| Empty (confirmed zero) | an honest empty state with the next action | look like an error | |
| **Unread** (request failed, 403, timed out) | a named failure for that section, previous snapshot kept if any | render as empty; show a zero nobody read | |
| Partial (some sources failed) | the section that failed is named; numbers that depend on it are marked | a headline number computed from partial inputs shown as complete | |
| Truncated (cap reached) | banner **and** marked figures ("5,000+ of unknown") | counts shown as exact | |
| Stale (refresh failed) | last good snapshot with a timestamp | silently stale | |
| Permission denied | a clear "no access" state | a broken or blank page; a silent hook failure | |
| Slow / large (1k+ rows) | paging or virtualisation; progressive render | whole payload rendered at once; `JSON.stringify` per row per render | |
| Clock / timezone | server time or explicit zone; relative times with absolute on hover | browser clock deciding what is "newest" or "overdue" | |

## 3. Action matrix per action

| State | Expectation |
|---|---|
| Idle | disabled only when the server would refuse; disabled is not authorization |
| Submitting | double-submit prevented; the affected region shows pending |
| Success | result reflected without a full reload; focus returns to a sensible place |
| **Partial success** | what *was* written is shown; retry applies only to the rest; no message claiming nothing happened |
| Retryable failure (5xx, network, timeout) | retry offered; edits kept; timeout after the server wrote is treated as unknown, not failed |
| Permanent failure (stale version 409, validation 400, 403) | the flow closes or re-proposes; no retry button that can only fail again; the message says what to do |
| Conflict | the other person's change is named; last-write-wins never silent; the version the *client* read is what the server checks |
| Destructive | confirmation names the object and the consequence; undo where possible |

Walk each action's state machine through success → partial → fail → retry-fail and write down what the component says at each step.

## 4. Forms

- Constrained values use pickers, lookups or multi-selects — never free text or raw JSON for enumerations, ids or lists.
- Validation messages sit next to the field, mirror the server's rules (shape and range), and the server validates regardless.
- Edits survive an error; only changed keys are sent; cleared values are sent explicitly; units are shown.
- Secrets are `type=password`, never read back; the form never echoes a stored credential.

## 5. Data truthfulness

- Labels mean what they count: "mapped" is not "covered", "linked to a test" is not "tested", a draft or retired item does not count as active.
- Values shown with a result are the values *of that result* (thresholds, settings), not today's settings.
- Two screens showing the same metric compute it the same way; name the shared function.
- No column renders a constant; no placeholder stands in for data that exists.
- Zero-tolerance metrics are not scored as ratios.

## 6. Design-system compliance

- Colours, spacing and type from tokens; no raw hex in `src`; one semantic status family, not a second palette beside the existing one.
- Shared blocks (tables, drawers, cards, forms) over raw primitives, so column/display settings and behaviours come for free.
- Dark mode (if supported) checked for every new token.

## 7. Keyboard, focus and announcements (quick pass)

- Every ARIA role carries its keyboard model (`grid` needs arrow keys; otherwise use a table of buttons or drop the role).
- Drawers and dialogs trap and restore focus; Escape closes; the first meaningful element is focused.
- Async outcomes are announced (live region) and errors are associated with their controls.
- Deep audit → `design:accessibility-review` (if installed).

## 8. Performance of the view

- No re-fetch on every mount or focus without a shared cache; no polling without a cache or conditional requests; one load at a time.
- Only used fields are requested; derived data is memoised; large lists are virtualised or paged.

## 9. Evidence

List the Playwright specs that cover the risky rows of sections 2–3 — at minimum: unread (route failure) renders as a failure not as empty; 403 renders as no-access; partial success shows the written part; stale-version 409 closes the flow; a constrained field refuses malformed input. Real auth path, stable locators, no `.only`, evidence captured per repo rule. Offer to hand this list to the `spec-writer` agent, which writes the specs and their evidence in the repo's existing style and reports the states it could not cover.

## Quick greps (read around every hit)
```bash
grep -nE '^\+.*(\?\?\s*\[\]|\|\|\s*\[\]|catch.*\[\])' <Diff>            # fallback-to-empty: unread shown as empty?
grep -nE '^\+.*#[0-9a-fA-F]{6}\b' <Diff>                              # raw hex off the token ramps
grep -nE '^\+.*role="(grid|listbox|menu|tree|tablist)"' <Diff>         # roles that need a keyboard model
grep -nE '^\+.*(disabled=\{.*(admin|role|can))' <Diff>                 # disabled used as authorization?
grep -nE '^\+.*(Date\.now\(\)|new Date\(\))' <Diff>                     # browser clock in view logic
grep -nE '^\+.*(JSON\.stringify)' <Diff>                                # heavy work per render
grep -nE '^\+.*(setInterval|visibilitychange|focus)' <Diff>            # polling / refetch triggers
grep -nE '^\+.*(<input|<textarea)' <Diff>                              # free text for constrained values?
grep -nE '^\+.*(Nothing|No .* (found|exist)|none)' <Diff>              # empty-state copy: reachable on failure?
```

## Output

Per screen: the filled state matrix and action matrix with gaps marked. Then findings in the `pr-self-review` interchange format (category `correctness` for truthfulness and state bugs, `conventions` for tokens/blocks/forms), a `STRENGTHS:` list, and the list of specs to add. Title the defect, not the symptom ("Failed issues read rendered as 'no issues exist'", not "empty state bug").