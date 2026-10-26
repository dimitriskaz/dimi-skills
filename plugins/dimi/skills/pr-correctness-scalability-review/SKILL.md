---
name: "pr-correctness-scalability-review"
description: "Deep code-review checklist for correctness, scalability and conventions on a working-tree or PR diff: asymmetric paths, run-it-twice idempotency and races, silent caps, unbounded reads, swallowed errors, copied plumbing, stale claims, what the tests prove. Use alone or as stage 2 of pr-self-review."
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
---

# Correctness, scalability and conventions review

Stage 2 of `pr-self-review`; also usable alone ("scale pass on my changes", "correctness check before I commit"). Input: a diff file (`Diff` in the Review context: the working tree against the base branch, including untracked files, or a PR's own base...head) and the code as it is now (PR mode: at `Head`, `git show <Head>:<path>`). Output: findings in the `pr-self-review` interchange format, plus `STRENGTHS:` and `CHECKED_CLEAN:` bullets.

As stage 2 of `pr-self-review`, use that skill's diff and the Review context it printed. Alone, build the diff first — put the session's scratchpad path in the second argument if it gives one (else `''`; the output then goes to `<top>/../pr-correctness-scalability-review-<repo>/`, absolute, never inside the repo):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh build pr-correctness-scalability-review '' '${user_config.default_branch}' '${user_config.demo_marker}' '${user_config.demo_branch}' '${user_config.ticket_regex}' '${user_config.local_checks}'
```
It prints the Review context (`Top`, `Out`, `Diff`, `Base`, `Head`, `Report`, options); write those values literally into later commands — each Bash call is a fresh shell, and a command that expands a variable cannot be pre-approved.

Use the `SCALE` line from the Repo policy block (`${CLAUDE_PLUGIN_ROOT}/skills/pr-self-review/references/diff-and-policy.md` §4; the repo's realistic one-year volumes). Every "does this scale" question is answered against those numbers, not the demo dataset.

## Method

Read in risk order: routes → data access and query builders → outbound calls → jobs/workers → schema, seeds, contracts → model code → UI → tests/fixtures → docs. Skip binaries. For any hunk you doubt, read the whole function and its callers; a hunk tells you nothing about the other end of a pair.

Apply each lens to every relevant line, then confirm by reading. Report nothing you cannot state as mechanism → consequence.

### Lens 1 — Pairs and symmetry
Most real bugs live between two places that must agree. For every operation, find its partner and compare:
- **Normalise on lookup vs normalise on store** (trim, case, strip). `'ITEM-01 '` stored untrimmed never matches again; every re-import duplicates it.
- **Preview vs commit**: does preview count as matched what commit will not resolve?
- **Two walkers / parsers / formatters** for one shape: same completion rule, same missing-value rule, same error mapping?
- **Two implementations of one metric or rule** ("active", "complete", a status helper, a quota rule): do they agree; which is canonical?
- **Gate on path A vs path B**: the edit route refuses X; do import, bulk patch, agent write, fill-empty refuse it too?
- **Written vs shown**: results record the spec/version hash and thresholds; does the UI show the values *of that run* or today's?

### Lens 2 — Run it twice
For every import, sync, collect, job, commit or migration-like path:
1. **Second run, identical input**: zero new records, zero new edges, counts unchanged? Which test pins that?
2. **Retry after partial failure**: what was written before the failure, is it recorded, does the retry finish the rest or redo everything? A gateway timeout after the server wrote is the common case.
3. **Two runs at once** (two tabs, two users, two pods, scheduled + manual): what stops both from creating? Name the lock, lease or unique constraint. In-process `Map`s and per-session guards do not count across instances. Cannot find it → PLAUSIBLE with `confirm: show the lease covers manual runs and retries`.

### Lens 3 — Every constant is a cliff
```bash
grep -nE '^\+.*(MAX_|_LIMIT|PAGE_SIZE|_PAGES|TIMEOUT|single_page|\.slice\(0|limit[:=]\s*[0-9]|\bcap\b)' <Diff>
```
For each: (a) what happens **past** the cap — error, banner, or silent truncation returned as `ok`? (b) is the cap on both sides of a comparison (the listing capped at 5k, the existing-records lookup capped at 5.2k → everything past looks absent and is re-created)? (c) does it match the service (30 s client timeout vs a 3-minute server limit; multi-year windows)? (d) does truncation produce **wrong numbers** behind a "partial" banner? Wrong headline numbers behind a banner are wrong numbers.

### Lens 4 — Real scale
For every read and write, estimate rows at `SCALE` one year in, then ask:
- **Grows with history?** Append-only tables re-read on hot paths (list/detail routes, every page open, every poll tick) get slower forever. Newest-per / `DISTINCT ON` / whole-inventory reads that no index serves belong on a write path or in a summary record.
- **Whole-tenant read into the browser?** Every record of N kinds and every edge type pulled client-side truncates at scale. Fix: server-side aggregate (latest per key, summary counts), not more client paging.
- **Bounded, projected, deduplicated?** Full payloads with no projection; kinds fetched and unused; edge types fetched and discarded; re-fetch on every drawer open despite "read once".
- **Polling**: fixed interval, no cache, no conditional request; guard checks the last *completed* read so `focus` and `visibilitychange` both start loads; multiply by open tabs.
- **Serial awaits in one request**: `for (...) await patch(...)`; one edge write per link; ~200 lookups in sequence. Worst case against the gateway timeout. Batch, bulk, or bounded concurrency.
- **Retry granularity**: a 429 on page 40 that restarts from page 1 makes throttling worse.
- **Work before configuration**: the whole estate fetched before discovering "Not configured".
- **Per-run work that should be per-change**: a refresh now running for every source on every sync, including ones the change did not touch.
- **Model complexity**: pure models should be ~O(N+E); nested loops over records × edges are not.

### Lens 5 — Failure modes
- **Swallowed errors**: `catch { log }` / `except: pass` around a write that leaves durable state inconsistent (an edge written only on the create branch; if it fails, later runs see `created=False` and never write it). Retried? Recorded?
- **Fallback to empty**: a failed optional read that becomes `[]` and renders as "no records exist" shows a zero nobody read. Keep *unread* apart from *empty* in every count and label.
- **Permanent errors with live retry buttons**: after a stale-version 409 the stored version can never match; the card must close, not retry.
- **UI state after partial success**: "Rejected. Nothing was linked" while edges exist. Walk each state machine through success / partial / fail / retry-fail.
- **Optimistic locks**: is the version the *client* read sent, or does the server lock against what it read a millisecond ago (catching a race, not edits since page load)?
- **Verify steps** that compute `matches` but return success either way.

### Lens 6 — Claims vs code
List every assertion in comments, docstrings, commit messages, headers, UI copy and runbooks; check each. "read once", "cached", "locked", "only the lease prevents", "see `foo.ts`" (exists?), "grant permission X for test 4" (does test 4 call it?).

### Lens 7 — Hard-coded, copied, shipped-ahead
- **Hard-coded sets gating generic logic** (`DOMAINS = {a, b}`): prefer a flag on the record, defaulted from the manifest, with a tenant switch.
- **Hand-maintained parallel lists** (keys in the server, labels in the contract package, inputs in YAML, tests pinning copies together): every new item is 3–4 edits. Derive from one source.
- **Copied plumbing**: HTTP/auth/session/retry helpers near-duplicated for a second vendor; a second copy of a rules helper; a re-implemented helper beside the shared one. Extract before the third copy.
- **Shipped ahead of consumers**: tools, routes, settings, constants, modules nothing uses yet. For every new export: `grep -rn '<name>' --include='*.ts' --include='*.tsx' --include='*.py' --include='*.yaml' .`. No consumer → finding; say what will use it and when.
- **Dangling references**: comments, config entries or runbook sections naming things that do not exist in this tree.
- **Behaviour change outside the ticket**.

### Lens 8 — Data semantics and model changes
- **Identity**: what makes two records "the same"? Does the key carry everything that distinguishes them (source-instance id not just source type; source system not just external id; standard version not just clause)? A collapsing key is a Blocker once durable records use it.
- **Order dependence**: chunk order, edge order ("first parent wins"), sheet import order. Needs a final pass or a deterministic rule.
- **Null and unknown**: `NOT (status IN (...))` drops NULL rows; `tone !== 'pass'` sweeps in "no status" and unknown statuses; a `truncated` flag always `false`. Enumerate missing/unknown explicitly.
- **Prefix/substring matching on ids**: `startsWith` matches `app-pro` vs `app-prod`. Anchor on the full id or `/` boundaries.
- **Time**: `Date.now()` in model code (browser clock behind server hides the newest run); `Date.parse('YYYY-MM-DD')` is midnight UTC; windows vs timeouts; unset "within N days".
- **Ratios and scoring**: every event a passing subject so one failure scores PARTIAL on a zero-tolerance metric; one unrelated event clears every failing item. Numerator and denominator must mean what the label says.
- **External format assumptions**: comparing a full cloud-resource path with what the log store actually holds (full id or bare GUID?). If every fixture was written by the author, the assumption is untested → PLAUSIBLE with a confirm step.
- **Schema/seed changes**: new fields defaulted for existing rows, or does old data fall into the "missing" branch? Filterable/indexed flags declared where code filters? Seeds vs migrations per convention? Enumerations spelled exactly as the existing value lists? Renamed or removed fields — who still reads the old name?
- **Enrichment**: re-import under another organisation adds a second edge silently; fill-empty semantics tested.

### Lens 9 — What do the tests prove?
- Happy path only, or also the cap, the truncation, the second run, the concurrent run, the failed optional read?
- Selfchecks that pin copy A to copy B prove consistency, not correctness; is anything pinned to the source of truth?
- Fixtures invented by the author with the author's assumptions (every id in the same invented shape)? Any real-shaped sample?
- New pure module without a unit test; new UI feature without a browser spec; `page.route` stubs standing in for the real server on the path under test.
- A test that would still pass with the fix reverted is not a test of the fix. For the main defect this change fixes, say which test would fail without it.

### Lens 10 — Frontend specifics
Constrained values as free-text JSON instead of pickers; new colour/status tokens as raw hex off the design-system ramps (a second semantic palette); raw primitives where a shared block exists; ARIA roles without their keyboard model; hooks re-fetching on every mount with no shared cache or failing silently on 403; stub columns rendering a constant; full raw payloads kept per row and stringified on each render.

### Lens 11 — Agent and LLM code (when the diff touches prompts, tools, agent loops)
- **Budgets enforced in code**: max steps/turns set deliberately (not a library default), token and cost ceilings, wall-clock deadline; the run stops with a partial result, not an exception.
- **Timeouts on every model, tool and HTTP call**; HTTP clients never created without one.
- **Stall detection**: repeated identical tool calls or no state change for N steps triggers stop or re-plan.
- **Retries**: transient errors retried with backoff and jitter, honouring `Retry-After`; a fallback model configured and tested.
- **Durable state**: no in-memory checkpointer/saver/session store on the production path; a supervisor re-drives crashed runs.
- **Prompt prefix stable** (instructions and tool definitions first, variable content last) so prompt caching works; context trimmed in large infrequent steps, not every turn.
- **Pinned, dated model versions**; the eval set re-runs on every prompt, model, tool or index change.
- Full rubric with search hints: `/dimi:review-agent`.

## Quick greps (read around every hit)
```bash
grep -nE '^\+\s*(for|while)\b' <Diff>                                        # then look inside each loop for await/fetch/request
grep -nE '^\+.*(Date\.now\(\)|new Date\(\)|Date\.parse|datetime\.now|utcnow)' <Diff>
grep -nE '^\+.*\.(startsWith|startswith)\(' <Diff>
grep -nE '^\+.*(setInterval|visibilitychange|addEventListener\(.focus)' <Diff>
grep -nE '^\+(.*(new Map\(|_inflight|_cache\b|lru_cache)|\s*global )' <Diff>      # in-process state
grep -nE '^\+.*\.(trim|strip|lower|toLowerCase|toUpperCase)\(' <Diff>       # check the partner path
grep -nE '^\+.*(catch\s*\(|catch\s*\{|except\b)' <Diff>                      # what is swallowed?
grep -niE '^\+.*(read once|cached|idempotent|lock|lease|never|always)' <Diff> # claims
grep -nE '^\+.*(TODO|FIXME|XXX|HACK)' <Diff>
grep -nE '^\+\s*(export (const|function|class)|def |class )' <Diff>          # new exports: find a consumer for each
```

## Strengths to recognise (write them down)
Exact-identity matching with fuzzy merge deliberately avoided; enrich-never-overwrite; batched lookups and bulk writes with explicit caps; partial lists refused as data; ambiguous matches refused, never guessed; three-valued outcomes with unread kept apart from empty; the read-failure branch evaluated before the empty branch; pure view models with a unit test per counting rule; latest-per-key chosen deterministically; last good snapshot kept on refresh failure; truncation surfaced; one record per run rather than per item; failures logged without failing the job; new types as seeds not migrations where that is the convention.

## Reporting
Use the `pr-self-review` interchange format. Title the defect, not the symptom ("External IDs not trimmed when stored", not "duplicates on re-import"). One clause of fix. Pattern predates the change → `predates: yes` and why it still counts (heavier rows, newly reachable path, keying locked in). One finding per defect; spans server and UI → report where it should be fixed with `also_affects`.