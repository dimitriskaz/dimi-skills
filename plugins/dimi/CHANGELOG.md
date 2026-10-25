# Changelog

## 1.3.0 - 2026-10-25

- New skills for the demo-branch workflow: `poc` (mark demo-only shortcuts with a greppable marker, keep a ledger of demo-only / owed / ported features on the demo branch, merge the default branch in without rewriting shared history, push straight to the demo branch behind a light gate, status with drift detection) and `port` (compute the real feature delta minus what is upstream or in your open PRs, build a local integration worktree of main + open PRs, classify every POC hunk as reuse / rewrite / drop, choose the PR base — main, or stacked one level on the PR it depends on — then build through plan-from-ticket and update the ledger).
- Options: `demo_branch`, `demo_marker` (default `DEMO-ONLY`).
- `pr-self-review` fails a production diff containing the demo marker; `commit-push-pr` refuses to run on the demo branch or with the marker in the diff. Starter rule and `CLAUDE.md` snippet updated.

Fixed (pre-release review of this version against a scratch repo and the Claude Code docs):

- Bash guard: `git push origin`, `git push origin HEAD` and `git push -u origin` while on a protected branch were not blocked; the push parser now resolves implicit refspecs and `HEAD`, and also blocks deletes of protected branches, `--all`/`--mirror`, `+refspec` force pushes, and `git rebase` on the configured demo branch. Protected-branch message no longer repeats the default branch.
- Stop gate: a missing package manager or linter was reported as a failed check and blocked once per turn, forever. The gate now detects the package manager from the lockfile or `packageManager` field (pnpm, npm, yarn, bun), skips a check whose tool is not installed and says so once as a warning, and treats "command not found" the same way. `typecheck_script` and `py_lint_cmd` accept `none` to disable.
- All hooks exit 0 when `jq` is absent (the Stop gate could not read `stop_hook_active` and blocked twice per turn); the session banner reports the missing `jq`.
- Stop gate: the where-I-stopped note was written before changing to the project directory, so it landed in the wrong place when the hook's cwd differed; an empty last message no longer erases the previous note; files over 1 MB no longer slow the tree signature; `DBG-` probe lines left by the `debug` skill are caught as debug leftovers.
- `ticket_regex` set to `none` (or empty) disables the commit-key check in the guard and the banner.
- Format hook: prettier runs only when the repo has adopted it (local install or a prettier config), so a global prettier no longer reflows files in repos that do not use it.
- SessionStart banner also runs on `fork`; SessionEnd hook no longer declares a timeout it cannot raise (1.5 s shared budget).
- Options: skills and agents now read options through `${user_config.KEY}` (the documented mechanism); `CLAUDE_PLUGIN_OPTION_*` is only available to hook scripts, so earlier skill text that relied on it never saw the configured value. `plugin.json` carries real `default` values for `ticket_regex`, `protected_branches`, `typecheck_script`, `typecheck_budget_s`, `py_lint_cmd`, `py_dir_regex`, `eslint_fix_on_edit` and `demo_marker`.
- Demo-marker gates match the marker in the shape `poc` writes (`MARKER(`) and exclude `.claude/**`, `CLAUDE.md` and `AGENTS.md`, so the starter rule file and this repository no longer trip them. `pr-self-review` fails when the head or base is the demo branch.
- Skills: `git check-ignore` calls use `--no-index` (they never reported force-added ignored files); the stand-alone diff build defines `$DIFF`; the diff-build snippet and the repo-policy block live once in `pr-self-review/references/diff-and-policy.md`; `tidy` and `compound` are offered to the author rather than "run" (they are not model-invocable); `commit-push-pr` pre-computes the demo-branch, marker and secrets checks, finds the self-review report through a fixed `LATEST` pointer, and gains `--base`; `port` uses `git log --cherry-mark` instead of a `git cherry` pathspec (which git rejects), cleans its worktree on every exit and cherry-picks with `-n`; `poc push` checks it is on the demo branch and defines the ticket key the guard requires; `debug` and the `debugger` agent stash only the fix files; `agent-evals` template is valid YAML and replay mode is the CI gate; `release-notes` places the capture spec under Playwright's `testDir` and has a no-Playwright path; ripgrep hints in `review-agent` and `harden-mcp` references use `-e` alternation (the former `\|` matched a literal pipe); `refresh-harness` covers every file carrying a dated fact; dated facts moved out of `harden-mcp/SKILL.md`; as-of notes added to the references that lacked them.
- Agents: `reviewer` has `maxTurns` and skips checks the compliance gate already ran; `implementer` drops `permissionMode` (ignored for plugin subagents); `verifier` resolves the default branch the documented way.
- Second review round: the Bash guard now parses `git` global options, `--repo`, `HEAD`/`@` aliases, `-n`, every sweeping-add spelling, `git stage`, `git commit -a`, `git pull --rebase`, reads the ticket key from the `-m` value only, compares protected branches by exact name, ignores quoted text, and runs on bash 3.2 (macOS). The Stop gate validates the budget option, times out once per branch (not once per edit), flags `.only(` only in test files, scopes the Python regex to Python files, and reports skipped checks on a block too. The session note is consumed by the session that ends. The eslint toggle accepts true/false.
- Second review round, skills: every path outside the repo and every repo scan is resolved from the repository top level (`git rev-parse --show-toplevel`), so the review skills work from a subdirectory; a missing default branch fails loudly instead of silently reviewing uncommitted changes only; re-run mode starts from the `LATEST` pointer; one secrets regex (defined in `diff-and-policy.md`) with redaction, scanning untracked files too; `port` no longer `cd`s into its integration worktree and cherry-picks with a conflict-safe sequence; `debug` and the `debugger` agent stash with `-u` so new files are covered; four ripgrep hints in the MCP checklist escape their parentheses; the client profile's severity-override table is consumed by `harden-mcp` and `review-agent` with a mapping for `pr-self-review`; remaining "run `/dimi:<skill>`" instructions for non-invocable skills now ask the author.
- Docs: template README and guide counts (5 hooks, 6 agents, 23 skills); `.claude/.cache/` added to the ignore and never-stage guidance; the `Agent(fork)` deny rule in the starter settings is noted as untested against `context: fork` skills.

## 1.2.0 - 2026-10-25

- New skills: `debug` (root-cause loop with a log and a stop rule after two killed hypotheses), `agent-evals` (golden tasks, deterministic asserts then a calibrated judge, repeated trials with a tolerance, replay mode for CI and budgeted live mode, injection fixtures), `walkthrough` (linear explanation of a module or flow with code references and a diagram, audience-tuned), `release-notes` (release notes grouped by module and feature plus Playwright-captured illustrated docs per module/feature/step against a demo tenant; `--docs` for the whole product).
- New agent: `debugger` (runs the `debug` loop in its own context; sonnet; stage/commit nothing).
- New hook: `SessionEnd` writes a one-line where-I-stopped note (time, reason, branch, uncommitted count, first line of the last message) to the plugin data dir; the `SessionStart` banner reads it back as "Last session here: …". The Stop hook now records the first line of the last assistant message for that note.
- `address-review`: review fixes must not annotate provenance in code; run `tidy` if any slipped in.

## 1.1.0 - 2026-10-24

- New skill `grill-me`: stress-test a plan, spec, ticket or design in conversation, one question at a time with a recommended answer each, depth-first through the problem, shape, identity, idempotency, scale, failure, trust, settings, proof, consumer and sequence branches. Reads `CLAUDE.md`, `.claude/rules/` and `.claude/fde-client-profile.md` before asking, delegates code reading to `explore`, and hands off to `plan-from-ticket` or `agent-bootstrap`.

## 1.0.0 - 2026-10-24

First release of the unified `dimi` plugin (merges the former dev-workflow and fde-toolkit plugins into one).

**Development loop**
- Skills: `plan-from-ticket`, `ui-states-review`, `tidy` (remove working notes before handover), `pr-self-review` (loads `pr-correctness-scalability-review` and `pr-security-data-review` as stages; calls `review-agent`/`harden-mcp` for agent and MCP code), `commit-push-pr`, `address-review`, `compound`, `agent-tool-design`, `agent-bootstrap`.
- Agents: `explore` (haiku, read-only), `reviewer` (opus, read-only, preloads both checklists), `verifier`, `spec-writer`, `implementer` (worktree-isolated).
- Hooks: format on edit; Stop gate (debug leftovers by file class, per-package typecheck with a time budget, Python lint); Bash guard (force push, protected and default branches, `--no-verify`, sweeping `git add`, commit without ticket key); session banner on startup/resume/clear/compact. Portable across GNU coreutils and stock macOS.
- Options via `userConfig`: ticket regex, default branch, protected branches, typecheck script/fallback/budget, Python lint command and path regex, local checks line, eslint-on-edit toggle.

**Agent engineering**
- `harness-reference`: background knowledge from *The Agentic Harness: A Layer-by-Layer Guide* (facts as of 24 October 2026), split into topic files.
- `review-agent`: forked, read-only production-readiness review with a 57-check rubric, report template and tested fix patterns.
- `harden-mcp`: forked, read-only MCP server review against the 2026-07-28 spec revision (43 checks), with tested auth, SSRF and path-confinement patterns.
- `client-profile`: creates `.claude/fde-client-profile.md`, which the other skills read.
- `refresh-harness`: manual workflow to re-verify dated facts and prepare a pull request.

Every skill honours `.claude/fde-client-profile.md` when present.
