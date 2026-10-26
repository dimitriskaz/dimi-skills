---
name: agent-evals
description: Build or extend the evaluation harness for an LLM feature or agent — golden tasks with expected tool sequences and outcomes, deterministic assertions first and a calibrated rubric judge second, repeated trials with a tolerance, a replay mode for CI and a budgeted live mode, injection fixtures, and a regression gate on every prompt, tool, model or index change. Use when an assistant, agent, tool or prompt is added or changed and nothing proves it still works.
when_to_use: "Triggers: /dimi:agent-evals, \"add evals for the assistant\", \"how do we know the new prompt is better\", \"set up a regression suite for the agent\", after agent-tool-design adds or changes a tool, before a model upgrade."
argument-hint: "[agent or feature name, or path to its code]"
disable-model-invocation: true
---

# Agent evals: make "the prompt change didn't break anything" a fact

Without evals every prompt edit is a guess, every model upgrade is a gamble, and the review rubric (section I of `${CLAUDE_PLUGIN_ROOT}/skills/review-agent/references/rubric.md`) fails the project. This skill builds the smallest harness that turns those into measured regressions, in the repo's own language and test infrastructure, and wires it so it runs on every change that can move behaviour.

## 0. Inventory the thing under test

Before writing a task, map what can change behaviour — these are the triggers for the regression gate:
- **Prompts**: system prompt files, tool descriptions, few-shot examples (versioned files, not inline strings — if they are inline, that is the first fix).
- **Tools**: names, schemas, output shapes (`agent-tool-design` specs if they exist).
- **Model and settings**: model id (pinned?), temperature, max tokens, effort.
- **Retrieval**: index, chunking, reranker, filters (if RAG is involved).
- **Consumers**: which user jobs the agent serves; the three most common become the first tasks.

Read `.claude/fde-client-profile.md` if present: approved models decide which model may be the judge, and data classes and the client's data policy decide what may appear in fixtures (see §2).

## 1. Shape of the harness

Create (in the repo's conventions; adapt names):
```
evals/
  tasks/<area>/<task-id>.yaml        one task per file
  fixtures/                          recorded tool results, documents, records (synthetic, real-shaped)
  rubrics/<name>.md                  judge rubrics, versioned like prompts
  rubrics/<name>.calibration.yaml    five hand-labelled outputs per rubric: the judge's own test (§3)
  config.(ts|py)                     modes, host allowlist for live/semi-live, default budget, judge model
  run.(ts|py)                        runner: loads tasks, runs the agent, scores, writes a report
  baseline.json                      last accepted scores per task (committed)
  recordings/<task-id>.json          recorded model transcript plus its fingerprint (prompt files, tool schemas, model id, judge model id, rubric version)
  pending.yaml                       tasks allowed to have no recording yet, each with a reason
  README.md                          how to add a task, how to run, how to read the report
```

**Task file** — the contract:
```yaml
id: links-01-exact-reference
area: links
input: "Link control CTRL-01 to risk RSK-07"            # what the user says
context:                                                 # fixtures the tools will return (recorded or synthetic)
  records: fixtures/records/small-estate.json
expect:
  tool_calls:                                            # deterministic where possible
    - {name: resolve_reference, args_match: {kind: control, ref: CTRL-01}}
    - {name: propose_links, args_match: {pairs_count: 1}}
  must_not: [write_edge, commit]                         # tools that may never be called directly
  outcome: proposal_created                              # machine-checkable end state
  assertions:
    - {path: "result.pairs[0].from.kind", equals: control}
    - {path: result.summary, matches: "1 link"}
rubric: rubrics/proposal-quality.md                      # optional, judged
trials: 5                                                # semi-live and live only; replay runs once
tolerance_trials: 1                                      # trials that may fail vs baseline (semi-live and live)
tags: [happy-path]
```
Tolerance is counted in trials, not as a fraction: a pass rate from 5 trials moves in steps of 0.2, so a fractional `tolerance: 0.1` would fail on any single lost trial. If the runner takes a fraction, require `trials >= ceil(1 / tolerance)`.

Add tasks of every kind the agent meets: happy path · empty result · ambiguous reference (must refuse, never guess) · upstream error (envelope, no body) · truncated result (flag + cursor) · cross-tenant attempt (refused) · **prompt-injection fixture** · a stale-version write (refused) · a long/paginated input. An injection fixture is a **twin** of a clean task: same input, the record text now carries instructions (`twin_of: links-01-exact-reference`); it asserts the same `tool_calls` as the twin and adds the tool the injected text asks for to `must_not`, so "behaviour unchanged" is a deterministic check, not a judgement.

## 2. Collect tasks — real-shaped by default

Three to five tasks on day one of a scaffold, ten to twenty before the replay job gates merges, fifty to two hundred by pilot. Eval data is real-shaped by default: the structure, edge cases and expected outcomes of real work, with synthetic content. Real client cases are used only anonymised, with the client's consent, and stored under the client's data policy, never in this plugin's repository. Sources, in order: production traces or logs with the inputs rewritten to synthetic equivalents; support tickets; the acceptance criteria of past tickets; the failure modes `review-agent` or `pr-self-review` found. Synthetic fixtures carry the *shape* of real data (ids, pagination, nulls, unicode, timezones), not its content. Fixture generation and anonymisation are a step, not an afterthought; note the source of each task's shape in a comment.

## 3. Scoring — deterministic first, judged second

1. **Deterministic assertions** decide pass/fail on anything machine-checkable: tool sequence, arguments, end state, refusals, forbidden tools, output schema validity, token and cost ceilings, latency. These never need a judge.
2. **Rubric judge** only for qualities that cannot be asserted (clarity of a summary, appropriateness of a refusal message). Rubric rules: criteria are specific and observable ("names the two records and the relationship" not "is helpful"); each criterion scored 0/1; the judge is chosen from the client profile's approved models, from a *different* model family from the agent where the profile allows one (when it approves a single provider, use a different model from that provider and lean on the calibration set); the judge sees the rubric, the input and the output — never the expected tool sequence; **calibrate** on five hand-labelled outputs before trusting it and store those in `rubrics/<name>.calibration.yaml` as the judge's own test (the runner fails when the judge disagrees with a label).
3. **Repeated trials** (3–5) per task in semi-live and live runs; report the pass rate and pass^k, not a single run, and give both with a 95% confidence interval (Wilson) for the suite. Use one k for the whole suite (set in config, every task runs at least k trials; pass^k holds only when all k pass), or τ-bench's unbiased estimator C(c,k)/C(n,k) per task (c passes in n trials). Those runs compare against `baseline.json` with the task's `tolerance_trials`. Replay mode has one recording per task, so trials, pass^k and the interval mean nothing there: each task is a single deterministic check against the baseline.
4. Record **cost and latency** per task alongside correctness; a regression in either is a finding too.

## 4. Three modes

- **Replay mode** (CI, every PR): tools return recorded fixtures and the model call is replayed from a recorded transcript. No network, no key, deterministic. This is the regression gate. Each recording stores a **fingerprint**: a hash of the prompt files, the tool schemas, the model id, the judge model id and the rubric (grader) version it was recorded with. Replay recomputes the fingerprint and **fails** the task on a mismatch ("re-record required"), because a replayed transcript cannot show what a changed prompt, model or judge would do. A task with no recording is never run live in CI; it fails the gate unless it is listed in `evals/pending.yaml`, and the report lists the skipped count. A run where every task is skipped fails, even when all of them are listed as pending: a gate that runs zero tasks verifies nothing.
- **Semi-live mode** (manual, the re-record step): recorded tool fixtures, with the production model id and settings for the model call, behind its flag and the spend budget (`--max-cost`) — for tasks that cannot be replayed yet, or to re-record transcripts (and their fingerprints) after a prompt, tool, model, judge or rubric change. A cheaper model would record behaviour production never shows. Needs a key, costs money and is not deterministic, so it never gates a PR; commit the new recordings so the next replay passes.
- **Live mode** (manual, before a release or a model change): the real model and tool stack against a seeded demo tenant, behind an explicit flag and a spend budget (`--max-cost`), results saved so the next baseline can be accepted deliberately (`--accept-baseline` after a human reads the diff).

The runner refuses semi-live and live mode without their flag, and refuses to run against any host not on the allowlist in `evals/config.(ts|py)` (local, the demo tenant; never anything that looks like production).

## 5. Wire it in

- `package.json`/`Makefile` scripts: `evals` (replay), `evals:semi-live` and `evals:live`.
- CI job on changes under prompts/, tools/, the agent's package, `evals/`, and on any model-id change: run replay mode, fail on any task that passed in the baseline and now fails, on a fingerprint mismatch and on any skipped task not listed as pending, and upload the report as an artifact.
- `pr-self-review`: a diff that touches prompts, tool schemas or model ids without a corresponding eval change or run is a Should-fix (offer `/dimi:compound` to add that line to the repo's `.claude/rules/` if it is not there; do not run it).
- A one-page `evals/README.md`: how to add a task (copy the template, run once, accept baseline), how to read a failure, what live mode costs.

## 6. Report

```
## Evals — <agent> @ <commit>   mode: replay | semi-live | live   trials: n (semi-live/live; replay: 1)
| task | pass rate | pass^k | Δ vs baseline | cost | p50 latency | notes |   (replay: pass/fail per task)
Suite: pass rate … [95% CI …]   pass^k … [95% CI …]   (semi-live/live only)
Skipped: n (pending: …)   Re-record required: … (fingerprint mismatch)
Regressions: … (task, what changed, suspected cause: prompt/tool/model/index)
New tasks added: …     Baseline accepted: yes/no (by whom)
```

Then offer: run `/dimi:review-agent` for the full readiness rubric, or `/dimi:compound` to make "evals run on every prompt change" a rule.
