---
name: "pr-structure-review"
description: "Maintainability review of a working-tree or PR diff: did the change make the code harder to change — a conditional bolted onto an unrelated flow, logic in the wrong layer, a wrapper that only passes calls through, a cast that hides the real type, a file pushed past the size limit, a copied helper, a reframing that would delete a whole class of complexity. Use alone (\"is this getting messy\", \"structure pass\", \"did I make this harder to maintain\") or as stage 2b of pr-self-review."
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
---

# Structure and maintainability review

Stage 2b of `pr-self-review`; also usable alone. The other stages ask whether the change is right, safe and scales. This one asks whether it left the code easier or harder to change next time. Input: the `Diff` and Review context from `pr-self-review`, or build them alone:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh build pr-structure-review '' '${user_config.default_branch}' '${user_config.demo_marker}' '${user_config.demo_branch}' '${user_config.ticket_regex}' '${user_config.local_checks}'
```
Then the file sizes the change produced, against the limit in the `max_file_lines` option (`${user_config.max_file_lines}`, 1000 when unset):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh sizes '<Out>' '${user_config.max_file_lines}'
```
It prints, for every file in the diff, lines before and after, and marks the ones that crossed the limit in this change or grew past it. Output: findings in the `pr-self-review` interchange format with `category: maintainability` and ids `ST-<seq>`, plus `STRENGTHS:` and `CHECKED_CLEAN:`.

A few high-conviction findings beat many cosmetic ones. No style taste, no "consider", nothing you cannot state as what the code does now and what it costs the next person. Read the whole function and its neighbours for any hunk you judge; structure is invisible in a hunk.

## The question behind every lens

Before the lenses: is there a reframing that makes most of this change unnecessary? A state model that removes the conditionals, an existing abstraction the feature could extend instead of a new one beside it, a default flow with fewer exceptions. When one exists and the change kept the incidental complexity instead, that is the first finding, and it outranks everything below.

## Lenses

### Lens 1 — Branching
- A new conditional inside a flow that is not about this feature (a check for the new case added to a shared loop, a `mode` parameter threaded through three functions).
- A one-off boolean, nullable mode or flag that changes control flow in more than one place.
- Feature checks scattered across shared code instead of one place that owns the feature.
- A branch labelled temporary. Temporary branches become permanent; say what would retire it.
- Repeated conditionals on the same discriminator: the sign of a missing type, model or dispatcher.

### Lens 2 — Layers and ownership
- Logic placed where it was convenient rather than where the concept lives (formatting in the data layer, a query in the UI, policy in a util).
- Feature-specific logic leaking into a general-purpose module.
- A bespoke helper where a canonical one exists (name the path), or a copy of plumbing the repo already has.
- A cohesive module made more coupled, more stateful or harder to scan than before.

### Lens 3 — Abstractions and contracts
- A wrapper that only forwards calls; an identity helper; a layer whose removal changes nothing.
- Generic or reflective handling that hides a simple structure.
- Casts, `any`, `unknown`, widened unions, optional parameters or ad-hoc object shapes added to get past the type checker; each hides the real invariant.
- An abstraction with one implementation and no second one in sight.

### Lens 4 — Size and decomposition
- A file that crossed `max_file_lines` in this change, or was already past it and grew, when the new code had a natural home of its own.
- A function that now does several unrelated jobs. Split by job; never by line count, and never into helpers whose only purpose is a shorter function.
- A component that grew a second responsibility (data loading in a presentational component, rendering in a loader).

### Lens 5 — Orchestration and atomicity
- Independent async work run in sequence when running it together would be simpler and faster.
- Related updates applied in steps that can be observed or fail half way (two writes with no transaction, state set before the call that may throw).

### Lens 6 — Reader load
- Hidden state or indirection a reader must hold in their head to follow the change: a value set in one place and read in another through a global, an event, a context.
- A change that moves code around without reducing what the reader must track.

## Severity

- **Should fix**: incidental complexity kept when a reframing exists; a file crossing `max_file_lines` without a reason in the PR; a conditional added to a flow that is not the feature's; feature checks scattered across shared code; a duplicate of a canonical helper; logic in the wrong layer when a clear home exists. `pr-self-review` promotes to Blocker only by its own section 1 criteria.
- **Minor**: everything else above, when it has a concrete cost.
- Not a finding: a house pattern followed as the neighbours follow it, even if you would design it differently; growth in a file that is the natural home of the code.

## Remedies to propose

Prefer the one that deletes: remove the layer instead of polishing it; reshape the state so the conditional disappears; extend the existing abstraction instead of adding one; turn special cases into the default flow; extract a pure helper; split the file by concept; replace a condition chain with a typed model or a dispatcher; move the logic to the module that owns the concept; make type boundaries explicit; run independent work together; group related updates so they apply or fail as one.

## Output

Findings in the interchange format, then `STRENGTHS:` (the structural decisions that were right) and `CHECKED_CLEAN:` ending with one line: no structural regression / regression in <lens>.
