---
name: grill-me
description: Stress-test a plan, design, spec or ticket before building by interviewing you relentlessly, one question at a time, until every decision and dependency is resolved. Use when you say "grill me", "grill me on this", "poke holes in this plan", "stress-test this", "interview me about this design", or want a plan pressure-tested instead of rubber-stamped. Run it on a fresh idea, on a plan from plan-from-ticket, or before agent-bootstrap.
argument-hint: "[plan, spec, ticket, file path, or nothing = ask what to grill]"
---

# Grill me

Interview the person relentlessly about every aspect of a plan until you both share a fully resolved understanding of what is being built. Walk down each branch of the design tree and settle the decisions it depends on before moving to the next. This is the opposite of a yes-machine: the job is to surface the gaps, assumptions and unmade decisions now, while changing the answer is free.

`plan-from-ticket` forces these decisions on paper; this skill forces them in conversation. Use whichever fits the moment, or this one first and that one to write the result down.

## Step 1: Pin down what is being grilled

Find the target before asking anything:

- A plan, spec, design, ticket or ADR already on the table: in this conversation, in `$ARGUMENTS`, in a plan file written by `/dimi:plan-from-ticket`, or in a README the person points at.
- A bare `/dimi:grill-me` with nothing obvious to chew on: ask one question, "what plan or decision do you want pressure-tested?", and wait.

Then read what the repository already tells you, so you never ask for things you could find:

- `CLAUDE.md` and `.claude/rules/` for the house constraints.
- `.claude/fde-client-profile.md` if present. Its approved models, cloud, regions, data classes and approval rules are hard constraints, not questions; treat any plan that violates them as a finding.
- The code the plan touches. Delegate the reading to the `explore` subagent ("where is X handled, who calls Y") so the file contents stay out of this conversation.

## Step 2: Grill

- Ask questions **one at a time** and wait for the answer. Several at once is bewildering and lets the person skip the hard one.
- For each question **give your own recommended answer** and why. The person wants a partner with a view, not a questionnaire.
- Go **depth-first**: follow each decision down its branch and resolve the dependencies it creates before backing out to the next branch.
- **Look instead of asking** whenever the answer is in the repository, the ticket or the client profile.
- **Push back** when an answer is vague, contradicts an earlier one, or dodges a trade-off. Say what the contradiction is. Keep going until the branch is resolved.
- Do not accept "we'll handle that later" for anything that changes the data model, the identity keys, the security boundary or the framework choice; those are the decisions that are expensive to change after the first commit.

Branches worth walking for most plans (skip the ones the plan has already answered in writing):

| Branch | The question underneath |
| --- | --- |
| Problem | What is wrong today, for whom, and how will anyone know it is fixed? What is explicitly out of scope? |
| Shape | Where does the change land, which existing code is canonical, and what gets reused instead of copied? |
| Identity | What makes two records the same? Which keys, normalised how, scoped to what (tenant, source instance, version)? |
| Run it twice | What happens on retry, on a duplicate request, on two instances at once? Where is the lock or unique constraint? |
| Scale | What grows without bound, what is capped, and what happens past the cap? |
| Failure | What is unread versus empty, retryable versus permanent, partial versus done? What does the user see in each case? |
| Trust | Who is allowed to do this, enforced where, and is there a second path around the gate? What leaves the system (PII, secrets, outbound calls)? |
| Settings | Where does each threshold, flag or mapping live, who changes it, and is the change audited? |
| Proof | Which tests would fail without this change? What does "done" look like as evidence someone else can run? |
| Consumer | Does every tool, route, setting and module in the plan have a consumer in this change? |
| Sequence | What is the first commit, what gates what, and what can be deferred to a follow-up without leaving a half-built path in main? |

For an agent or LLM feature add: budgets and step caps, human approval on writes, prompt-injection exposure, tracing and evals. `harness-reference` has the detail; do not re-derive it.

## Step 3: Land it

Stop when no branch is unresolved: every meaningful decision made, dependencies settled, and you could both write the same one-paragraph description of what is being built. Then:

1. Summarise the resolved plan in a few tight lines, decisions first, then open follow-ups that were deliberately deferred.
2. Offer the next step that fits: `/dimi:plan-from-ticket` to write it up as a plan with tests and commit steps; `/dimi:agent-bootstrap` if it is a new agent; or nothing, if the person is ready to build.
3. If a real decision was made along the way, say where it should be recorded in this repository (an ADR, the ticket, the PR description, or `CLAUDE.md` via `/dimi:compound`). Do not write it anywhere unasked.

---
*Forked from [mattpocock/skills](https://github.com/mattpocock/skills) (`grilling` + `grill-me`), merged into one self-contained skill and adapted to the dimi plugin.*
