---
name: "plan-from-ticket"
description: "Turn a ticket into an implementation plan before coding: codebase touchpoints, data model and identity keys, idempotency, scale assumptions, failure modes, light threat model, the tests that would fail without the change, and a commit-by-commit work breakdown."
argument-hint: "[ticket key or pasted ticket]"
---

# Plan from ticket

Use at the **start** of a ticket, before writing code. Triggers: `/plan-from-ticket PROJ-1234`, "plan this ticket", "before I start on…", a pasted ticket or user story, "how should I approach…".

The plan applies the `pr-self-review` lenses *forward*: every question the reviewer will ask at the end is answered here first, when changing the answer costs nothing. Done well, `pr-self-review` at the end becomes a confirmation, not a discovery.

## 0. Inputs

- The ticket: key and text. If a Jira/Linear connector is available, fetch it (description, acceptance criteria, comments, linked tickets, attachments). Otherwise ask for a paste.
- Repo rules: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, ADRs (`docs/adr/**`, `docs/decisions/**`) that touch the area.
- `.claude/fde-client-profile.md` if present: approved models and regions, risk tiers and approval rules, data classes and retention. These are constraints on the design, not suggestions.
- The policy block and `SCALE` line from the `pr-self-review` skill (ticket format, forbidden paths, required tests, deletability of records, realistic tenant size). Read it; do not re-invent it.

Write the plan to `$OUT/plan-<ticket>.md`, where `$OUT` is **outside the repo** (scratchpad if given, else `../plans-<repo>/`). Check `FORBIDDEN_PATHS` before ever placing a design note inside the repo: in some repos design notes are policy-ignored and must never be force-added. If the repo has an ADR convention and the ticket makes an architectural choice, offer an ADR in that location as a separate step.

## 1. Restate the problem

In your own words, three to six sentences: who the user is, what they can do after this ships that they cannot do now, and what "done" looks like. Then:
- **Acceptance criteria** — extract from the ticket; where missing, draft them as testable statements and mark them `proposed`.
- **Out of scope** — name adjacent things explicitly left out (they become follow-up tickets in section 6).
- **Ambiguities** — at most five questions whose answer changes the design. If the author is present, ask now (AskUserQuestion). If not, state the assumption you took and continue; the plan header carries `Assumptions:`.

## 2. Map the codebase

Find where this change lands before deciding how:
- **Touchpoints by layer**: routes/endpoints, data access, schema/seeds/contracts, jobs/workers, connectors, model/view-model, UI, agent tools, docs/runbooks. List files with one line each on what changes.
- **The canonical implementation** of anything similar that already exists (the existing import path, the existing connector, the existing settings panel). Read it. The plan follows the canonical one, never the copy — if two exist, say which is canonical and flag the duplicate.
- **Shared helpers to reuse**: HTTP/auth/retry plumbing, pagination, rate-limit envelopes, validation helpers, UI blocks. If the change would need a third copy of something, the plan starts by extracting it.
- **Owners**: `CODEOWNERS` for the touched paths; who needs to review.
- **Hot paths** the change touches (list/detail routes, page loads, poll ticks, collect runs) — these get the scale treatment in section 3.

## 3. Design decisions

Answer each heading in writing. "N/A" is a valid answer only with a reason.

**Data model and identity**
- Which records and relationships are created or changed. For each record type: what makes two records *the same*? The key must carry everything that distinguishes them (source instance, not just source type; source system plus external id; version, not just clause). Keys never carry ticket ids, customer names or POC references.
- Normalisation rules (trim, case) applied identically on store and lookup.
- New fields: default for existing rows; filterable/indexed where code will filter; seeds vs migrations per repo convention; exact spellings of enumerated values from the existing value lists.

**Idempotency and concurrency ("run it twice")**
- Second run with identical input: zero new records, zero new edges. Which mechanism guarantees it, and which test pins it.
- Retry after partial failure: what is recorded, what the retry does.
- Two runs at once (two tabs, two instances, scheduled plus manual): the lock, lease or unique constraint. In-process state is not a mechanism when there is more than one instance.

**Scale**
- Row counts at `SCALE` one year in for every read and write on a hot path.
- Where aggregates live: history that grows gets a summary written at collect time or a server-side aggregate, never a whole-tenant read into the browser.
- Every cap and timeout, and the behaviour past it: error or banner-plus-marked-numbers, never silent truncation returned as ok. Caps match the service they front.
- Projections (fetch only the fields used), batching and bounded concurrency for fan-out, caching or conditional requests for anything polled.

**Failure modes**
- *Unread* kept distinct from *empty* in every count and label; a failed optional read never renders as "none exist".
- Which errors are swallowed and what state they leave; what retries them.
- Partial success: what the user sees, what is recorded, what the retry does. Permanent errors close the flow instead of offering a retry that can only fail.

**Settings and configuration**
- Thresholds live on the thing they govern (the test, not the connection); connection facts live on the connection. Shared keys do not force one value on several consumers.
- Server-side validation of shape and range; audit of who changed what from what to what; defaults safe; per-tenant control where the feature affects every tenant.

**Security and data (light threat model)**
- New routes/commands and the gate on each. Every write path — including import, bulk, agent and fill-empty paths — enforces the same refusals as the primary edit path.
- Tenant always from session or job claims.
- Which personal data is touched; the minimum needed; where it flows (logs, outputs, exports, model context). Nothing that can return personal data ships without a consumer.
- Outbound calls: fixed hosts, read-only allowlists, same-host pagination, least-privilege credentials.
- Customer data stays out of the repo (names, workbooks, fixture orgs, POC ticket ids).

**Reuse vs copy and scope boundary**
- The shared helper used, or the extraction done first.
- What is in this ticket; what becomes a follow-up (listed in section 6 with a proposed title). Tools, routes, settings and modules are added only when something in this ticket uses them.

## 4. Test plan

**First run the tests.** Before any change, run the suites for the packages you will touch and record the baseline. A failure you did not cause is not yours to chase mid-ticket; note it as a follow-up. Then work red/green where the change is a fix: write the failing test, watch it fail, commit it, implement.

List the tests **that would fail without this change**, grouped:
- Acceptance: one test per acceptance criterion.
- Lenses: cap/truncation behaviour; second identical run; retry after partial failure; concurrent run; failed optional read; cross-tenant refusal; gate on the alternate write path; validation rejects malformed settings.
- Per `REQUIRED_TESTS`: browser spec with evidence for UI features (real auth path, stable locators, the risky states from `ui-states-review`); unit test for pure modules; fixtures with at least one real-shaped sample rather than only author-invented shapes.
- What existing tests must keep passing, and which local checks (`LOCAL_CI`) run before each commit.

## 5. Work breakdown

Ordered steps, each one commit in `COMMIT_FORMAT`:
```
1. <type>(<KEY>): <headline>        files: a, b, c        verify: <command / test>        size: S|M|L
2. ...
```
Rules: extraction and refactors first, behaviour next, UI after the API it needs, docs/runbook last. Each step leaves the tree green. Mark the step where a product decision or reviewer confirmation is needed before continuing.

## 6. Risks, open questions, follow-ups

- Risks with likelihood, impact and the mitigation already in the plan.
- Product decisions a reviewer must confirm (defaults, visibility, on-by-default features).
- Follow-up tickets: title and one line each; offer to create them if a tracker connector is available.

## 7. Plan file format
```
# Plan: <KEY> — <title>
Assumptions: ...
## Problem and acceptance criteria
## Touchpoints (by layer) and canonical patterns followed
## Design decisions (identity · run-it-twice · scale · failure · settings · security/data · reuse · scope)
## Test plan (tests that fail without the change)
## Work breakdown (one commit per step)
## Risks, decisions to confirm, follow-ups
```
Keep it under two pages. A plan nobody reads protects nothing.

## 8. Keep it alive

When implementation diverges from the plan, update the plan and say why (one line). At the end, `pr-self-review` treats the plan as the list of claims to verify: every mechanism named here must be visible in the code and pinned by the tests listed in section 4. Offer to start step 1 of the work breakdown.