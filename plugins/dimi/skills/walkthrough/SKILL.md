---
name: walkthrough
description: Explain a module, flow or system end to end for a newcomer, a reviewer or a client — entry points, the data path, the invariants and non-obvious decisions, the places people trip, with code references and a diagram — verified by reading the code, never from memory. Use when onboarding onto a codebase, briefing a teammate, handing over an engagement, or before changing code nobody understands.
argument-hint: "[module, flow, directory or question; optional --audience newcomer|reviewer|client --diagram]"
---

# Walkthrough: a linear explanation someone can follow

Code explains *what*; nobody wrote down *why* or *in what order*. A walkthrough is the document a good senior engineer would give you on day two: start here, this calls that, the data looks like this on the way through, these three things are not obvious, here is where people get hurt. It is built by reading the code, not by recalling how such systems usually work.

Triggers: `/dimi:walkthrough`, "explain how X works", "walk me through the import flow", "onboard me to this service", "what does this module do", "brief for the handover".

## 0. Scope and audience

- **Scope**: one entry point and the path from it — a route, a job, a UI flow, a module boundary. "The whole service" is several walkthroughs; pick the first and list the rest.
- **Audience** (default `newcomer`): *newcomer* wants vocabulary, order and gotchas; *reviewer* wants invariants, boundaries and where bugs hide; *client* wants behaviour, data handling and controls, and no file paths in the delivered doc — every `path:line` in the body becomes a footnote number (`[1]`, `[2]`, …) that resolves in a separate internal appendix file in `$OUT` (§4), which is not handed over; *reviewer* and *newcomer* keep `path:line` inline. Adjust depth, not accuracy.
- **Constraints**: `.claude/fde-client-profile.md` if present (what may be shown to a client); nothing from real tenant data in examples — use the repo's fixtures or invented values.

## 1. Map it (delegate the reading)

Use the `explore` agent so the file contents stay out of this conversation — one call per bullet group below (entry and call chain; data and writes; configuration, tests and siblings), not one call for everything. Ask for, with `path:line`:
- the entry point(s) and what triggers them (request, schedule, event, user action);
- the call chain to the first external boundary (data store, vendor API, queue, model call) and back;
- the shape of the data at each hop (types/schemas, the fields that change meaning on the way);
- every write, with its gate (who may do it) and its idempotency story;
- configuration and settings that change behaviour, and where they live;
- the tests that cover the path, and the fixtures they use;
- siblings: a second implementation of the same thing, or a copy of the plumbing.

Read the ADRs, `CLAUDE.md`, `.claude/rules/` and the *why*-comments on the path: these are the decisions the walkthrough must explain.

## 2. Write it — in the order the data moves

```
# <Flow> — how it works
Audience: … · Scope: … · As of: <commit short sha, date>

## In one paragraph
What it does for whom, in plain words. The one thing to remember.

## The path
1. <Trigger> — path:line (client: [n]). What arrives, in what shape.
2. <Step> — path:line (client: [n]). What happens to it; the decision made here and why.
…
n. <Result> — what leaves, where it is stored, who sees it.

## The data on the way through
A small table or two: field → meaning → where it is set → where it is read. Note every place a value is normalised, truncated, or re-keyed.

## Invariants and decisions (the why)
- <Invariant>: why it holds, what breaks if it doesn't, where it is enforced (path:line), which test pins it.
- <Decision>: what was chosen over what, and why (link the ADR or the why-comment).

## Where people trip
Three to five concrete gotchas: the second write path, the cap that silently truncates, the browser clock, the setting that lives in a surprising place. Each with path:line and the symptom you'd see.

## Boundaries
Who may call it; what it trusts and what it checks; what leaves the system (PII, outbound calls, exports).

## How to change it safely
The canonical place to add a case; the tests to run; what `pr-self-review` will check for this area.

## Glossary
Domain terms as the code uses them.

## Appendix (reviewer/newcomer): file index · (client): footnote table [n] → path:line, kept as a separate internal file in $OUT, not in the delivered doc
```

Rules: every claim has a `path:line` or a test name behind it — inline for reviewer/newcomer, as a footnote number resolving in the internal appendix for client; anything you could not confirm by reading is marked *(unverified)*, never stated as fact. Keep the body under two pages for a newcomer, one for a client; depth goes in the appendix. Prefer one good example over three abstract sentences.

## 3. Diagram (`--diagram`, or whenever the path has more than four hops)

A Mermaid `sequenceDiagram` for request/response flows, a `flowchart` for branching logic, in the doc. Boxes are the real components named as the code names them; arrows carry the data shape, not just a verb. If an HTML explainer would help a client, say so and offer it as a follow-up; do not build it unasked.

## 4. Verify, then place

- Re-read the doc against the code once: every path:line resolves, every "always/never" has its enforcement point, no customer data in examples.
- Where it lives: `docs/walkthroughs/<slug>.md` if the repo has a docs convention, else `$OUT` and offer to add it. `$OUT` is the session's scratchpad directory if it gives one — set `OUT=<scratchpad path>` on the line before the block — else `../walkthrough-<repo>/` next to the checkout, never inside the repo; resolve it from the repo top so it works from any subdirectory:
  ```bash
  TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
  REPO=$(basename "$TOP")
  OUT=${OUT:-$TOP/../walkthrough-$REPO}; mkdir -p "$OUT"
  ```
  The client audience's internal appendix (`$OUT/<slug>-appendix.md`) always goes to `$OUT`. A walkthrough older than the code lies, so it ends with its `as of` commit and a note to regenerate after structural changes (`/dimi:walkthrough <same scope>`).
- If writing it exposed a gotcha that should not exist (a second path, a silent cap), that is a ticket, not a footnote — list it under follow-ups.
