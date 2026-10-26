---
name: debug
description: Find and fix a bug by root cause, not by trial and error — capture, reproduce as a failing test, baseline, isolate, one hypothesis at a time with a running log, fix, prove with the regression test, remove the scaffolding. Use when something fails, a test is red, CI is broken, or "it worked before". Stops and re-plans after two failed hypotheses instead of looping.
argument-hint: "[error message, failing test, ticket, or description of the symptom]"
---

# Debug: root cause, with a log

Debugging goes wrong in one way: trying things. Each attempt that does not work leaves its residue in the code and in the context, the next attempt is made on top of it, and after three rounds nobody knows what state anything is in. This skill replaces that with a loop that always knows where it is, because it writes down where it is.

Triggers: `/dimi:debug`, "this is failing", "CI is red", "it worked yesterday", "why does X happen", a pasted stack trace. For a long investigation delegate to the `debugger` agent so the transcript stays out of your main context; it follows this same skill.

## 0. Capture before touching anything

Create `$OUT/debug-<slug>.md` and write (`$OUT` is the session's scratchpad directory if it gives one — set `OUT=<scratchpad path>` on the line before the block — else `../debug-<repo>/` next to the checkout, never inside the repo; paths are top-level-relative, so this works from any subdirectory; each Bash call is a fresh shell, so every block below that uses `$TOP` or `$OUT` starts with these lines):
```bash
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
REPO=$(basename "$TOP")
OUT=${OUT:-$TOP/../debug-$REPO}; mkdir -p "$OUT"
```
`<KEY>` below is the ticket key in the branch name (`git rev-parse --abbrev-ref HEAD`, matching `${user_config.ticket_regex}`); if there is none, ask the author — the Bash guard refuses a commit without it.
- **Symptom**: the exact error text or wrong output, where it appears (test name, endpoint, screen), and the expected behaviour in one line.
- **Since when**: last known good (commit, date, deploy); what changed in between (`git log --oneline <good>..HEAD -- <area>`, recent dependency bumps, config or data changes).
- **Environment**: local / CI / preview / production; which tenant or data; which versions (node, python, browser). Many "bugs" are environment deltas.
- **Blast radius**: who is affected and how badly — this sets how fast to move and whether to roll back first.

Do not form a theory yet.

## 1. Reproduce — as the narrowest failing command, ideally a test

Reproduce deterministically before diagnosing. The order of preference:
1. An existing test made to fail, or a new failing test that encodes the symptom (this will become the regression test — write it in the repo's test style; if it is committed before the fix, as `test(<KEY>): <symptom>`, the author commits it).
2. The single command that fails (one spec, one endpoint call with a fixed payload, one script), not the whole suite.
3. A manual repro with exact steps, as the last resort — and write the steps down.

If it does not reproduce: say so, list what was tried, and stop — flakiness and environment deltas are different investigations (compare envs, run 5×, check clocks and timezones, look for shared state).

## 2. Baseline — first run the tests

Before any change, run the touched packages' tests and typecheck and record the result. A failure you did not cause is a follow-up, not a detour. If it is a regression, `git bisect` with the repro is faster than reading. The repro must live **outside the tree**: older commits do not have a test written now (committed at HEAD or not), so running it in place makes them look good and bisect blames the wrong commit. Save the test to `$OUT` and let a script copy it in at each step, skipping (exit 125) commits where it cannot run; run this in one Bash call with the §0 lines first:
```bash
cd "$(git rev-parse --show-toplevel)" || exit 1        # <test path> below is top-level-relative, here and in the script
cp <test path> "$OUT/repro-<slug>.<ext>" || exit 1
cat > "$OUT/bisect-<slug>.sh" <<'EOF'
#!/bin/sh
# usage: bisect-<slug>.sh <saved test> <its path in the repo>; exit 0 good, 1 bad, 125 skip this commit
cd "$(git rev-parse --show-toplevel)" || exit 125
mkdir -p "$(dirname "$2")" && cp "$1" "$2" || exit 125
<build step, if the test needs one> >/dev/null 2>&1 || { git checkout -q -- "$2" 2>/dev/null || rm -f "$2"; exit 125; }
<narrowest command that runs "$2">; rc=$?
git checkout -q -- "$2" 2>/dev/null || rm -f "$2"          # leave the commit as it was checked out
[ "$rc" -eq 0 ] && exit 0; [ "$rc" -eq 1 ] && exit 1; exit 125   # other codes (no tests collected, import error) = cannot test
EOF
git bisect start HEAD <good> && git bisect run sh "$OUT/bisect-<slug>.sh" "$OUT/repro-<slug>.<ext>" <test path>
git bisect reset; cp "$OUT/repro-<slug>.<ext>" <test path>
```
Bisect does not need a clean tree: it refuses a step only when the checkout would overwrite local changes (an edited file the range also changes, an untracked file at a path an old commit tracks). If it refuses, `git stash push -u -- <those paths>` with explicit paths, and `git stash pop` after `git bisect reset`. The script restores the committed version at each step; the last line puts your copy back, tracked or untracked.

## 3. Isolate

Find the boundary where correct becomes wrong, by halving:
- **Layer by layer**: data at rest → read path → logic → serialisation → UI. Assert at each boundary (log the value with its type and length, not `console.log(obj)`).
- **Input by input**: minimise the failing input until removing anything more makes it pass.
- **Time**: what the code *thinks* the time, timezone and clock are; what the browser thinks vs the server.
- Add logging at *boundaries*, one line per probe, with a unique prefix (`DBG-<slug>`) so every probe is found by one grep; this skill removes its own probes in §6 and the Stop gate blocks any `DBG-` line left behind. Never scatter prints.
- Read the real code at the boundary, including the other end of any pair (Lens 1 in `${CLAUDE_PLUGIN_ROOT}/skills/pr-correctness-scalability-review/SKILL.md`): lookup vs store, two walkers, the alternate write path.

## 4. Hypotheses — one at a time, in the log

Table in the log file:

| # | Hypothesis | Prediction (what we should observe if true) | Test | Result |
|---|---|---|---|---|

Rules: one hypothesis at a time; the prediction is written *before* the test; a result that does not match the prediction kills the hypothesis — do not patch the hypothesis to fit. Remove the probe before the next hypothesis so attempts do not stack: probes are single lines carrying `DBG-<slug>`, so `git -C "$TOP" grep -n --untracked 'DBG-<slug>'` lists them; delete exactly those lines, re-run the grep until it prints nothing, and delete a file only if the probe created it. Never stash, drop or `git checkout` a file to remove a probe: the same file holds the regression test or the author's uncommitted work, and `git stash drop` destroys it.

**Stop rule**: after two killed hypotheses, stop testing and step back — re-read the capture, the plan for this area and `.claude/rules/`; ask whether the model of the system is wrong (it usually is at this point). If the author is present, say what has been ruled out and ask one question. Never run three unexamined attempts in a row.

## 5. Fix the cause, not the symptom

- The fix changes the thing that was wrong in step 3, not the place where it was noticed. Catching the exception, adding a retry, widening a type, adding an escape hatch (`as any`, `ts-ignore`, `eslint-disable`, `type: ignore`) or special-casing the failing input are symptom fixes; each is a `pr-self-review` finding.
- If the real fix is large, make the smallest correct fix now and open a follow-up with the log attached; do not ship a workaround silently.
- Follow the repo's canonical pattern for the area; if the bug exists because a copy diverged from the canonical implementation, fix the divergence or delete the copy.

## 6. Prove it

1. The regression test from step 1 passes, and fails again if the fix is reverted. Prefer committing the failing test first (`test(<KEY>): …`, as `plan-from-ticket` does; the author commits) so it survives the revert; when running as the `debugger` agent, which commits nothing, use the stash check alone. The check: `git stash push -u -- <fix files>` with explicit paths (`-u` so a fix that is a *new* file is stashed too — without it `git stash push -- newfile` fails with "did not match any file(s) known to git" and the test keeps passing, a false proof), confirm `git stash list` shows the new entry, run the test (it must fail), `git stash pop`. Never a bare `git stash`: it takes the test with the fix.
2. The touched packages' tests and typecheck pass (baseline from step 2 restored or better), one command at a time.
3. Related inputs: the neighbours of the minimised input (empty, one, many, unicode, timezone edge) — add a test for any that fail.
4. Remove every `DBG-<slug>` line and probe: ask the author to run `/dimi:tidy` scoped to this change, or follow `${CLAUDE_PLUGIN_ROOT}/skills/tidy/SKILL.md` §1–4 inline.

## 7. Report and compound

Final section of the log, then the summary to the author:
```
Root cause: <one sentence: what was wrong and why it produced the symptom>
Evidence: <path:line of the cause; the observation that confirmed it>
Fix: <what changed>  ·  Regression test: <name>
Ruled out: <hypotheses 1..n in one line each>
Follow-ups: <larger fix, flaky test, env delta, with proposed ticket titles>
```
If the cause is a class of mistake (untrimmed id, NULL in a NOT IN, browser clock, copied helper), offer `/dimi:compound` (do not run it): it turns the lesson into a rule so it is caught at review next time, not in debugging.
