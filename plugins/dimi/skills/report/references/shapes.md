# Report shapes

One section list per kind. Order is the reading order; the first section answers the question on its own. Drop a section when it would be padding; never pad to fill the list. Every section names its sources so the report is built from them, not from memory.

## ticket — "what was done, is it ready"

Subject: a branch, ticket key or PR. Reader: the reviewer, the lead, or the client who asked for it.

| Section | Must say | Sources |
| --- | --- | --- |
| Summary | verdict (Ready / Ready with notes / Not ready) and the one thing to do before merge; three sentences on what changed and why | latest self-review report (verdict), ticket, facts block |
| What was asked | the ticket in its own words; acceptance criteria as a checklist with met / not met / proposed | ticket or PR body, plan from `plan-from-ticket` |
| What changed | commits table; changed-files table with scaled `+`/`−` bars; areas touched | facts block |
| How it works | the path in order with `path:line`; one diagram when there are more than three hops; one code excerpt for the non-obvious decision | `explore` agent, why-comments, ADRs |
| How it was tested | every check with its command and result; what was not run and why; screenshots with captions saying what each proves | command output, evidence files, e2e specs |
| Review findings | each finding with id, severity, where, why, status; "checked, nothing found" | self-review report, `address-review` worklist, PR reviews |
| Risks and follow-ups | what could still go wrong at real scale, the migration or flag to flip, deferred items with tickets and owners, unverified claims | self-review Risks, plan's out-of-scope, your own reading |
| Appendix | full file list, local check commands, regenerate command | facts block |

## codebase — "what is this, how is it built, where is the risk"

Subject: a repository or a path. Reader: a newcomer, a client receiving a handover, a lead deciding what to fix first.

| Section | Must say | Sources |
| --- | --- | --- |
| Summary | what it does for whom in one paragraph; health verdict; the three things to know | README, `CLAUDE.md`, the facts block |
| Shape | stats (files, languages, tests, contributors, age); top-level layout with one line per folder; a system diagram with real component names | facts block, manifests, `explore` |
| How it runs | entry points, how to build, run and test, environments and settings that change behaviour | manifests, CI workflows, Dockerfiles, docs |
| The main paths | two or three flows as timelines with `path:line` (the request path, the job path, the data import path) | `explore`, one call per flow |
| Health | churn hotspots (size × commits) with what each file is and whether it is tested; largest files; duplicate implementations; the TODO-marker and skipped-test counts from the facts block | facts block, `explore` |
| Risks | ranked: what breaks first, what nobody understands, what has no test, what depends on a person; each with evidence and a next step | the above, plus `review-agent` or `harden-mcp` reports if present |
| Where to start | for a newcomer: the first file to read, the test to run, the module to change first | your reading |
| Appendix | glossary of domain terms as the code uses them; dependency list with versions from lockfiles (a client report's footnote table goes to the separate internal appendix file, never here) | lockfiles, code |

## review — "render a review as a page"

Subject: a self-review report, a `review-agent` or `harden-mcp` report, or a colleague's review. Reader: the author, the team, or the client who commissioned the review.

| Section | Must say | Sources |
| --- | --- | --- |
| Summary | the verdict and the counts (Blocker / Should fix / Minor, or Critical / High / Medium / Low), the one fix that matters most | the report's header |
| Scope | what was reviewed (paths, commit, date), what was not, which checklist | the report's scope line |
| Scorecard | one row per area with status and worst finding, when the source has one | `review-agent` scorecard |
| Findings | every finding as a filterable `details.finding` with the source's ids, evidence and fix; CONFIRMED and PLAUSIBLE kept as pills | the report, verbatim |
| Checked, nothing found | the source's own list; strengths | the report |
| Could not verify | what needed infrastructure or access the reviewer did not have | the report |
| Next steps | fixes in severity order with owners; the re-run command | the report, `address-review` worklist |

Never add findings here; a rendering is not a review. Severities and ids are the source's.

## investigation — "what happened, why, what fixed it"

Subject: a bug, an incident, a flaky test, a performance regression. Reader: the team, the post-incident review, the client asking for an explanation.

| Section | Must say | Sources |
| --- | --- | --- |
| Summary | the symptom in one sentence, the root cause in one sentence, the fix and its proof, the status (fixed / mitigated / open) | the debug log from `debug`, the fix commit |
| Impact | who saw what, for how long, how many; what data was affected and whether it was repaired | logs, tickets, the facts block |
| Timeline | detection, each hypothesis with its prediction and result (`li.crit` for the one that killed the theory, `li.good` for the confirmation), the fix, the verification | the debug log |
| Root cause | the mechanism with `path:line` and a code excerpt; the invariant that was broken and why nothing caught it | the code, the failing test |
| The fix | the change, the regression test that fails without it (name it), what else was considered | the fix commit, the test |
| Prevention | the rule, hook or check that makes it impossible next time; owner and ticket | `compound` output, your reading |
| Appendix | full command log, raw evidence, the environment | the debug log |

## release — "what shipped, what to migrate"

Subject: a range (`v1.4.0..HEAD`) or a version. Reader: customers, the support team, the team itself.

| Section | Must say | Sources |
| --- | --- | --- |
| Summary | the headline change in the user's words, the counts (features, fixes, breaking), the date | `release-notes` output if present, the facts block |
| Breaking changes and migration | exact steps in order with commands; who is affected | PR bodies, migrations in the range |
| By module | what you can do now, Changed, Fixed, each with its PR reference; a screenshot per feature when `release-notes` captured one | merged PRs, `docs/releases/<version>/` |
| Settings and permissions | new options with defaults and where to set them; new scopes a customer must grant | PR bodies, config diffs |
| Known limitations | deferred items with tickets | PR bodies |
| Internal (collapsed) | refactors, dependency updates, tooling | the commit list |

A release report for a client audience leaves out internal section headings, file paths and internal ticket keys that are not visible to the client.
