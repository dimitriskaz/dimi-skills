# Report template

Use this structure. Keep it factual: every finding has evidence, and nothing is listed as a finding that you could not confirm in the code.

```markdown
# Agent readiness review: <system name>

**Verdict:** Ready | Ready with conditions | Not ready
<One or two sentences: the main reason for the verdict and the single most important fix.>

**Scope:** <paths reviewed> · **Commit:** <short SHA> · **Date:** <YYYY-MM-DD>
**Client profile:** <found and applied | not found, defaults used>

## System inventory

| Item | Finding |
| --- | --- |
| Frameworks and versions | <from lockfiles> |
| Models | <model IDs, pinned or floating> |
| Agents and workflow shape | <fixed graph, dynamic, multi-agent> |
| Tools | <count; which write; which reach outside> |
| Untrusted inputs | <web, email, files, RAG, MCP, A2A> |
| State and persistence | <checkpointer, stores> |
| Observability | <tracing backend, cost tracking> |
| Evals | <dataset, CI> |

## Scorecard

| Area | Status | Worst finding |
| --- | --- | --- |
| A. Control and budgets | Pass / Gaps / Fail / N/A | <ID> |
| B. Side effects | | |
| C. Identity and authorisation | | |
| D. Prompt injection and egress | | |
| E. State and durability | | |
| F. Failure handling | | |
| G. Context management | | |
| H. Observability | | |
| I. Evaluation and change control | | |
| J. Tools | | |
| K. RAG | | |
| L. Data governance | | |

## Findings

| # | Severity | Check | Finding | Evidence | Fix |
| --- | --- | --- | --- | --- | --- |
| 1 | Critical | J4 | <what is wrong and why it matters, one or two sentences> | `path/file.py:42` | <concrete change; link a pattern from patterns.md where one applies> |

Sort by severity, then by effort (cheapest first within a severity).

## Quick wins

<Up to five fixes that take under an hour each.>

## Could not verify

<Checks that depend on infrastructure, settings or docs you could not see, and what would confirm them.>

## Next steps

<Ordered list: what to fix before the next milestone (demo, pilot, security review, go-live).>
```
