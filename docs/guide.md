# dimi: what every file is, and why

A plain-language tour of the `dimi` plugin's development-loop half (skills, agents, hooks) and the per-repo starter in `templates/project-claude/`. The agent-engineering half (`harness-reference`, `review-agent`, `harden-mcp`, `client-profile`, `refresh-harness`) is documented in the plugin README. Skills are invoked as `/dimi:<name>`.

---

## The five kinds of thing

Claude Code can be extended in five ways. The bundle uses all five, and the distinction matters because each one runs at a different moment and is good for a different job.

| Kind | What it is | When it runs | Good for |
|---|---|---|---|
| **Skill** | A Markdown file of instructions Claude follows when you invoke it (`/name`) or when the task clearly matches its description | When you ask | A *method*: how to plan, how to review, how to design a tool. Advisory — Claude follows it as well as it follows any instruction. |
| **Hook** | A shell script Claude Code runs automatically at a lifecycle moment (after an edit, before a command, when a turn ends, when a session starts) | Every time, automatically | Things that must happen *every single time with no exceptions*. Deterministic — not up to the model. |
| **Subagent** | A separate Claude with its own context window, tools and model, which does a job and returns a summary | When Claude or you delegate to it | Work whose raw output you don't want in your main conversation (searches, test logs), or work that benefits from fresh eyes (review), or work that can run in parallel. |
| **Rule** | A short Markdown file in `.claude/rules/`, optionally scoped with `paths:` globs | Unscoped: every session. Scoped: only when Claude reads or edits a matching file | *Judgement* Claude should apply in one area of the code (how to read data, how UI states behave). Advisory, like `CLAUDE.md`, but modular and loaded only where relevant. |
| **Permission rule** | An allow/deny pattern for tools and commands in `settings.json` | Every tool call | Fewer "may I?" prompts for safe, repetitive commands; hard blocks for dangerous ones. |

Rule of thumb from the official docs: **if Claude ignores an instruction twice, it shouldn't be an instruction — make it a hook.**

---

## Folder layout

```
plugins/dimi/            (installed as a plugin; same for every repo)
  skills/        11 + 5 skills   — development loop + agent engineering
  agents/        5 agents        — delegates for search, review, verification, specs, parallel work
  hooks/hooks.json               — registers the 4 hooks
  scripts/       4 scripts       — automatic gates and context (configured via plugin options)
templates/project-claude/        (copied into each repo; about that repo)
  .claude/settings.json          — permission allow/deny, enabledPlugins; no hooks block
  .claude/rules/                 — 4 starter files of path-scoped judgement; grows via /compound
  CLAUDE.md.snippet              — lines to paste into the repo's CLAUDE.md
```

---

## Skills (`plugins/dimi/skills/<name>/SKILL.md`)

Invoke with `/dimi:<name>`. Each is one file.

### `pr-self-review` — the full gate before you commit or push
**Purpose:** reproduce the review your teammates would do, on your working tree, before they see it.
**What it does:** builds the diff of everything you've changed (committed on the branch, staged, unstaged *and untracked*) against `main`; runs a compliance table (ticket key in branch/commits, forbidden paths, customer names, escape hatches like `as any`, debug leftovers, required tests, what `git add -A` would sweep in); then loads the two checklist skills below as stages 2 and 3; then grades every finding **Blocker / Should fix / Minor**, each marked **CONFIRMED** (traced in code) or **PLAUSIBLE**; writes a report outside the repo with Strengths and "Checked, nothing found"; and finally drafts your commit message(s) and PR description.
**Why it exists:** in a real team review of a large change, most Blockers fall into the categories this gate checks — duplicates at scale, data that should never be committed, gates bypassed by a second path, headline claims that fail on a real tenant. Running it yourself saves a review round.
**The one thing to edit:** the **Repo policy** block near the top (ticket regex, forbidden paths, required tests, `SCALE` assumptions). It's the only place repo facts live in the review skills.

### `pr-correctness-scalability-review` — stage 2, usable alone
**Purpose:** find the bugs linters can't: logic that is wrong at real scale, or in the second run, or under failure.
**What it does:** ten "lenses" applied to the diff — pairs that must agree (trim on lookup vs store), *run it twice* (idempotency, retry, concurrency), every constant is a cliff (what happens past a cap?), real scale (reads that grow with history), failure modes (unread vs empty), claims vs code, hard-coded/copied/shipped-ahead, data semantics, what the tests prove, frontend specifics.
**Why it exists:** these were the categories of the Blockers in the review — duplicates past a cap, untrimmed ids, whole-tenant reads in the browser.

### `pr-security-data-review` — stage 3, usable alone
**Purpose:** security and data-handling for a multi-tenant product.
**What it does:** threat-models the diff first (new routes, new data flows, new outbound calls, new agent tools), then checks tenant isolation, authorization and gate bypass via alternate paths, server-side validation, injection (SQL/query DSL/CSV/XSS/prompt), SSRF, secrets and env flags, PII minimisation, customer data in the repo, unsafe defaults, dependencies. Secrets are checked first, including untracked files. It must end with a "checked, nothing found" list so you can see coverage.

### `plan-from-ticket` — before you write code
**Purpose:** answer the reviewer's questions *before* implementing, when changing the answer is free.
**What it does:** restates the problem and acceptance criteria; maps where the change lands and which existing code is canonical; forces written decisions on identity keys, idempotency, scale, failure modes, where settings live, security and reuse; lists the tests that would fail without the change; breaks the work into one-commit steps; lists follow-ups. Writes a two-page plan outside the repo.
**Why it exists:** most of the review's findings were design decisions, not typos. This is the review skills run forward.

### `ui-states-review` — before committing UI
**Purpose:** check every state a screen can be in, not just the happy path.
**What it does:** a state matrix per data source (loading, empty, **unread**, partial, truncated, stale, permission denied, large) and an action matrix (partial success, retryable vs permanent failure, stale-version 409), plus forms (pickers not free text), data truthfulness (labels mean what they count; thresholds shown are those of the run), design tokens, keyboard models, and the Playwright specs those states need.
**Why it exists:** several review findings were "failed read shown as 'none exist'" or "Reject says nothing was linked after links were written". Deep accessibility and copy are left to the `design:*` skills you already have.

### `tidy` — remove the scaffolding before anyone else sees it
**Purpose:** while working, Claude leaves itself breadcrumbs — `// added for PROJ-123`, `# per the customer's workbook`, `// step 3 of the plan`, a docstring that restates the signature, commented-out code "in case". Useful during the ticket, wrong at handover.
**What it does:** inventories every comment, docstring, log string, test name, identifier and scratch file the change added; classifies each as keep (explains *why*), rewrite (a why buried in narrative), delete (narrative, what-comment, commented-out code, debug, placeholder docstring), resolve (TODO → ticket or PR Deferred section), rename (ticket/customer in an identifier or test name) or untrack (plan/handoff files in the tree); applies the edits; then proves the diff is comment-only and the touched checks still pass.
**Why it exists:** ticket and customer context belong in the commit message and PR, not in code; a reviewer should never see the session. The source rule lives in `repo-hygiene.md`, the gate line in `pr-self-review`, the refusal in `commit-push-pr` — this is the fixer.

### `agent-tool-design` — when adding a tool a model can call
**Purpose:** get the *contract* right for anything your in-app assistant (or an MCP server) exposes.
**What it does:** description written for the model, strict input schema with no tenant/actor fields, bounded outputs with a truncation flag and PII projected out, structured error envelopes, reads tenant-scoped from claims, **writes as proposals** a human accepts, injection posture, per-tool tests and evals, and the rule that no tool ships without a consumer.
**Why it exists:** the review flagged tools shipped ahead of any consumer, one of which could return personal data.

### `agent-bootstrap` — when starting an agent project
**Purpose:** choose a framework on criteria and scaffold the things that are painful to add later.
**What it does:** first rule: fetch *current* docs (Context7 / web) before writing code — frameworks change faster than model training data. Then a short requirements interview, a scored framework choice (Claude Agent SDK, OpenAI Agents SDK, LangGraph, Pydantic AI, Google ADK, Vercel AI SDK, Mastra, or none), a scaffold with caps, tracing, human-in-the-loop, evals and tests from day one, and an ADR recording the docs consulted.

### `compound` — after a PR, make the lesson permanent
**Purpose:** the fourth step of Plan → Work → Assess → **Compound**. Planning and assessing exist already; this writes what was learned where Claude reads it next time.
**What it does:** collects the self-review findings, PR review comments, the corrections you made this session, and plan-vs-reality deviations; triages each into exactly one bucket — drop (one-off), **rule** (judgement → `.claude/rules/<topic>.md`, path-scoped), **hook** (must never happen again), **skill** (a procedure), or **repo fact** (`CLAUDE.md`); merges into existing rule files rather than adding siblings; prunes rules Claude already follows; escalates anything violated on two branches to a hook.
**Why it exists:** review findings cluster. The same handful of themes recur across a team's PRs until something writes them down where Claude reads them. Compounding is what stops a reviewer finding the same things next quarter. Manual-only (`disable-model-invocation`) so rules only change when you decide.

### `commit-push-pr` — the end-of-work command
**Purpose:** the thing you'll run most. Commit in the ticket format with explicit paths, push, open or update a draft PR.
**What it does:** pre-computes branch, status, ahead/behind, untracked files and existing PR with inline bash (no turn spent asking); refuses if behind `main` with overlaps, if untracked files look foreign, if a secret-looking string is in the diff, or if the latest self-review has open Blockers; runs lint/typecheck; proposes the commit split and waits for a yes; pushes without force; creates or updates the PR with a body drafted from the diff and the self-review handover note. Never approves, comments or merges.
**Why it exists:** Claude Code's creator reports running his equivalent dozens of times a day; it removes the most repetitive prompt of the day and guarantees the hygiene rules on every commit.

### `address-review` — work through a reviewer's comments
**Purpose:** the step between the review arriving and the next round. Paste the comments (or attach the report); nothing is fetched or posted.
**What it does:** builds a worklist (one row per distinct point, duplicates merged); **verifies each claim against the code before changing anything** — Confirmed / Partly / Disagree / Unclear with evidence; groups confirmed items by root cause; proposes dispositions (fix now / push back / answer / defer / ask) and confirms the contested ones with you; fixes one root cause per commit with the test that would fail without it; re-runs `pr-self-review` to show every item `Fixed` and nothing new broken; writes reply text per comment plus a summary for you to paste; ends by offering `/dimi:compound`.
**Why it exists:** reviewers are colleagues, not oracles — good reviewers mark their own uncertain findings as plausible rather than confirmed. Fixing everything blindly is as wrong as ignoring it. And the reviewer's comments are the richest input `/dimi:compound` will ever get.

---

## Rules (`templates/project-claude/.claude/rules/*.md` → the repo's `.claude/rules/`)

Short files of judgement. `repo-hygiene.md` has no `paths:` and loads every session (keep it tiny). The other three load only when Claude touches a matching file:

| File | Loads when editing | Carries |
|---|---|---|
| `data-reads.md` | `services/**`, `packages/**` | history reads, caps, identity keys, run-it-twice, serial awaits, NULL logic, prefix matching, verify-must-fail, where thresholds live |
| `ui-states.md` | `apps/**` | unread ≠ empty, partial success, permanent vs retryable errors, values of the run, labels mean what they count, pickers, tokens, blocks |
| `connectors.md` | `services/**/connectors/**`, `services/**/integrations/**` | read-only allowlists, SSRF, partial lists refused, PII projection, secrets, retry granularity, timeouts, runbook permissions |

All seeded from the review's recurring findings. Every `.md` in the directory is loaded, so nothing but rules goes there. Budgets: unscoped total under ~60 lines, each scoped file under ~30. `/dimi:compound` is the intended way to grow them; `/doctor` proposes cuts.

---

## Hooks (`plugins/dimi/scripts/*.sh`, registered in `hooks/hooks.json`)

All four need `jq` installed. Configure them once per repo in `/plugin` → dimi → **Configure options**; the scripts read those as `CLAUDE_PLUGIN_OPTION_*`, fall back to `STOP_*`/`GUARD_*` env vars, then to defaults.

### `format-file.sh` — runs after every file edit
**Moment:** `PostToolUse` on `Edit|Write`.
**Does:** prettier on the touched file (TS/JS/JSON/CSS/MD/YAML), `eslint --fix` on TS/JS, `ruff format` + `ruff check --fix` on Python. Always exits 0 — it never blocks and swallows tool errors.
**Why:** formatting and auto-fixable lint should never be what turns CI red.
**Tune:** `HOOK_ESLINT_FIX=0` if your eslint is slow.

### `stop-check.sh` — runs when Claude thinks it's finished
**Moment:** `Stop` (every time Claude ends a turn).
**Does:** if anything changed vs `main`: greps changed files for debug leftovers (`.only(`, `fit(`, `debugger`, `breakpoint()`); runs the `typecheck` script **only for the packages whose `.ts` files changed, one at a time, under a time budget** (default 150 s — past it, it asks Claude once to run it scoped and then stops blocking); runs your Python lint if any `.py` changed. On failure it exits 2 with the reason — Claude is **not allowed to stop** and must fix it. On pass it caches a signature of the tree so it doesn't re-run until something changes.
**Why:** this is the deterministic floor under "the fix loop". The failure arrives while Claude still has the context to fix it, not after push.
**Safety:** after it blocks once in a turn (`stop_hook_active`) it lets Claude stop, so it cannot loop forever.
**Options:** typecheck script name, whole-repo fallback (ideally incremental `tsc -b`), budget seconds, Python lint command and path regex, default branch.

### `guard-bash.sh` — runs before every shell command
**Moment:** `PreToolUse` on `Bash`.
**Does:** blocks (exit 2 with reason) force pushes, pushes to protected branches, `--no-verify`, sweeping `git add -A` / `git add .`, and `git commit -m` messages without the ticket key. Everything else passes.
**Why:** the review's "unrelated evidence PNG churn" and "customer data committed" findings are what `git add -A` does. Cheap to prevent, expensive to undo.
**Options:** ticket regex, protected branches.

### `session-context.sh` — runs when a session starts, resumes, or compacts
**Moment:** `SessionStart` with source `startup | resume | compact`.
**Does:** prints a short block into Claude's context: branch, ticket key, commits behind `main`, changed files, your local check commands, the three house rules, and (after compaction) a reminder to re-read the plan.
**Why:** `/clear` and compaction are the main defence against context drift, but they cost re-orientation. This makes them nearly free, without bloating `CLAUDE.md`.
**Options:** local checks line (display only), ticket regex, default branch. Also announces `.claude/fde-client-profile.md` when present.

---

## Subagents (`plugins/dimi/agents/*.md`)

Each is a Markdown file: frontmatter (name, model, tools, isolation…) plus a system prompt. Ask for them by name: *"use the explore subagent to find…"*, or Claude picks them from their descriptions.

| Agent | Model | Can edit? | Isolated worktree? | Use it when |
|---|---|---|---|---|
| **`explore`** | haiku (cheap, fast) | No | No | Anything that would dump many files into your conversation: "where is X handled", "trace callers of Y". Returns conclusions with `path:line`, not file contents. |
| **`reviewer`** | opus, high effort | No | No | "Review my changes." Fresh context — it hasn't seen the reasoning that produced the code, which is why it catches things. Preloads the two review checklist skills and returns findings in the `pr-self-review` format. |
| **`verifier`** | sonnet | No | No | "Prove it works." Runs lint/typecheck/tests/relevant specs for what changed and returns a table of commands, exit codes and evidence. Never fixes — it is the independent check, and the thing to put behind a `/goal`. |
| **`spec-writer`** | sonnet | Only e2e + evidence dirs | No | A UI change needs its Playwright spec. Reads two existing specs first and matches their conventions; prioritises the risky states (failed read, 403, partial success). |
| **`implementer`** | opus | Yes | **Yes** — branches from `main` | One *independent* unit of work, start to commit, in parallel with others. Not for splitting a ticket you're mid-way through: its worktree can't see your uncommitted changes. |

Why "No" on worktree isolation for most of them: they need to see *your current working tree*, including uncommitted edits. An isolated worktree branches from `main` and wouldn't.

---

## `settings.json` (per repo, from the template)

**`enabledPlugins`** — `dimi@dimi-skills: true`, so collaborators get the plugin; each still runs `claude plugin install dimi@dimi-skills --scope project` once. No `hooks` block: the plugin registers the hooks, and declaring them here too would run them twice.

**`permissions`** —
- `allow`: commands Claude may run without asking: read-only git (`status`, `diff`, `log`…), `gh pr view/checks`, your lint/typecheck/test scripts, `ruff`/`pytest`, reading any file, editing under `apps/`, `services/`, `packages/`. This is what makes fix loops fast — Claude doesn't stop to ask before running `tsc`.
- `deny`: `Agent(fork)` (stops Claude spawning copies of itself on its own — fork mode is on by default since v2.1.302 and is the usual reason for "several shells working at once"; your named agents are unaffected), force pushes, `--no-verify`, reading `.env*` and key files. Belt to the hook's braces.

The judgment call: `Edit(apps/**)` etc. means Claude edits those trees without asking. Remove those three lines if your team prefers approving edits.

---

## `CLAUDE.md.snippet`

Lines to merge into your `CLAUDE.md`: the commands, a **Speed** section (narrowest check, heavy commands one at a time, no agents or forks for checks, one task per session), the workflow (which skill when), the "after two failed corrections, `/clear`" habit, what to preserve when compacting, and three repo gotchas drawn from the review. Keep the whole `CLAUDE.md` under ~200 lines — the official guidance is that long files get ignored. Run `/doctor` after merging; it proposes cuts.

---

## How a ticket flows through all of this

1. `/dimi:plan-from-ticket PROJ-1234` → two-page plan with a test list and commit steps.
2. Implement. `format-file.sh` tidies every edit; `guard-bash.sh` stops the dangerous commands; `explore` keeps searches out of your context.
3. Claude says "done" → `stop-check.sh` runs typecheck/lint/leftovers; if red, Claude keeps going.
4. UI involved → `/dimi:ui-states-review`; missing specs → `spec-writer`.
4b. `/dimi:tidy` → working notes out, why-comments kept, diff proven comment-only.
5. "use the verifier subagent" → evidence table.
6. `/dimi:pr-self-review` → report, commit messages, PR description. Fix Blockers.
7. `/dimi:commit-push-pr` → commits with explicit paths, push, draft PR with the drafted body. Your teammates review a PR that has already been reviewed once.
8. Review comes back → `/dimi:address-review` with the comments pasted: verify, fix by root cause, re-validate, paste the replies.
9. `/dimi:compound` → findings become path-scoped rules (or hooks, or skills). Next ticket starts smarter.

If you ever wonder "where should this new rule go?": a *method* → skill; *judgement in one area of the code* → `.claude/rules/` (path-scoped); *must happen every time* → hook; *needs its own context or fresh eyes* → subagent; *a command Claude should or shouldn't run* → permissions.

---

## If Claude feels slow, or you see several shells working at once

Three usual causes, in order of likelihood, and what the plugin does about each:

1. **Fork mode** (on by default since v2.1.302): Claude spawns copies of itself for side tasks, each with its own shell, and while fork mode is on it can't wait for a subagent. The per-repo template's `settings.json` denies `Agent(fork)`; the named agents still work. Delete that line to allow forks again (or set `CLAUDE_CODE_FORK_SUBAGENT=0`).
2. **Parallel heavy commands**: typecheck in one shell, tests in another, lint in a third — Node processes fighting for CPU, each slower than alone. The `CLAUDE.md` snippet's **Speed** section, the `verifier` and `implementer` agents and `pr-self-review` all say: heavy checks one at a time, scoped to the touched package.
3. **Whole-repo checks on every turn**: the Stop hook typechecks **only the packages whose `.ts` files changed**, one at a time, under a time budget (option `typecheck_budget_s`, default 150 s). Past the budget it asks Claude once to run it scoped and then stops blocking. If your packages have no `typecheck` script, set the whole-repo fallback option to something incremental (`pnpm exec tsc -b`), or the gate silently does nothing.

Then look at the session: `/context` shows how full the window is (full = slow and forgetful → `/clear`); `/effort` may be higher than the task needs; `/model` may be on Opus for a Sonnet-shaped task (`opusplan`). After two failed corrections on one issue, `/clear` and restate.

## Testing the hooks before a release

A broken Stop hook blocks every turn for every user, so every change to `scripts/` is dry-run against a scratch repository before it is merged:

```bash
T=$(mktemp -d); cd "$T"; git init -q -b main; git commit -q --allow-empty -m 'chore(PROJ-1): init'; git remote add origin "$T"; git fetch -q origin; git checkout -qb feat/PROJ-2
echo x > a.ts                                              # a change
export CLAUDE_PROJECT_DIR="$T" CLAUDE_PLUGIN_ROOT=<path to plugins/dimi> CLAUDE_PLUGIN_DATA=/tmp/pd
echo '{"stop_hook_active":false}' | bash "$CLAUDE_PLUGIN_ROOT/scripts/stop-check.sh"; echo "rc=$?"     # 0 = may stop, 2 = blocked with reason on stderr
echo '{"stop_hook_active":true}'  | bash "$CLAUDE_PLUGIN_ROOT/scripts/stop-check.sh"; echo "rc=$?"     # must be 0
printf '{"tool_input":{"command":"git push origin main"}}' | bash "$CLAUDE_PLUGIN_ROOT/scripts/guard-bash.sh"; echo "rc=$?"   # must be 2
echo '{"source":"clear"}' | bash "$CLAUDE_PLUGIN_ROOT/scripts/session-context.sh"                                           # prints the banner
```
Run it twice: once with GNU tools on PATH and once with a PATH that lacks `timeout`, `sha1sum` and GNU `xargs` (stock macOS). The scripts carry fallbacks for all three; the test is what proves they still do. Keep stderr captures outside the repo, or they count as untracked changes.

## Beyond the plugin: habits and personal settings worth adopting

Nothing below lives in the repo. These are things you type, or set once on your machine. They are drawn from Anthropic's best-practices guide, the Claude Code team's own power-user tips, and current practitioner write-ups (Oct 2026). Grouped by the moment you'd use them.

### Starting work

| Habit | How | Why |
|---|---|---|
| **Plan before code, for anything you can't describe in one sentence** | `Shift+Tab` into plan mode (or `claude --permission-mode plan`), refine, `Ctrl+G` to edit the plan in your editor, then approve. Or `/dimi:plan-from-ticket`. | Separating exploration from execution avoids solving the wrong problem. Skip it for one-line fixes. |
| **Let Claude interview you for bigger features** | *"I want to build X. Interview me in detail using AskUserQuestion — technical, UX, edge cases, tradeoffs. Then write SPEC.md."* Then start a **fresh session** to implement from the spec. | The questions surface things you hadn't considered; the fresh session has clean context. |
| **Two-Claude plan review** | One session writes the plan; a second reviews it "as a staff engineer". | Fresh context catches what the author's context can't. |
| **Name sessions** | `claude --name "PROJ-1234-import-links"`, or `/rename` later. | `claude --resume` becomes usable when you have many. |

### While working

| Habit | How | Why |
|---|---|---|
| **Ask for fixes as a goal, not a prompt** | `/goal pnpm typecheck exits 0 and the touched tests pass; stop after 20 turns` | A separate evaluator re-checks after each turn; Claude iterates without you re-prompting. The Stop hook is the floor; `/goal` is the ceiling. |
| **Delegate anything that dumps text** | *"use the explore subagent to find…"*, or append **"use subagents"** to a request to apply more compute. | Keeps file dumps and logs out of your main context — the scarce resource. |
| **Side questions without polluting context** | `/btw <question>` | Answered from current context, never enters history. |
| **Correct early; after two failed corrections, stop** | `Esc` to interrupt. `Esc Esc` / `/rewind` to restore code and conversation to a checkpoint. After two failed corrections: `/clear`, then one better prompt incorporating what you learned. | Failed attempts stay in context and skew later reasoning. A clean session with a better prompt almost always beats a long session with accumulated corrections. |
| **Compact deliberately** | `/compact focus on <X>`; or `/rewind` → *Summarize from here / up to here*. Or have Claude write `HANDOFF.md` and start fresh from it. | Auto-compaction fires when the session is least sharp. Choosing what survives beats letting it choose. |
| **Re-plan instead of patching** | When a session goes sideways, go back to plan mode rather than correcting mid-stream. | The Claude Code team's rule. |
| **Have Claude show evidence, not claims** | *"Run the tests and show me the output"*; *"diff behaviour between main and this branch"*; *"take a screenshot and compare to the design, list the differences, fix them"*. Or *"use the verifier subagent"*. | Reviewing evidence is faster than re-running checks yourself, and it works for sessions you weren't watching. |
| **Don't accept the first answer** | *"Validate your understanding before opening a PR"*; after a weak attempt: *"discard this and implement the elegant solution"*; `/simplify` after a change. | The first draft is rarely the one you'd merge. |
| **Point at patterns and files** | `@path/to/file`, *"follow the pattern in X"*, paste screenshots, `cat error.log \| claude -p "explain"`. | Precision in the prompt is fewer corrections later. |
| **Speak, don't type** | `/voice` (hold space) in the CLI; mic button on desktop; `fn fn` on macOS. | The team reports ~3× faster input and more detailed prompts. |

### Working in parallel

| Habit | How | Why |
|---|---|---|
| **One ticket, one worktree, one tab** | `claude --worktree PROJ-1234` (or `-w`). 3–5 at once is the team's rhythm; practitioners put the quality ceiling at 3–4 concurrent *tasks*. Keep a spare "scratch" worktree for logs and investigations. | Sessions can't trip over each other. You switch between them instead of waiting on one. |
| **Background a long task** | `Ctrl+B` moves a running task to the background; `claude --bg "…"` starts one; `claude agents` shows them; `/fork` copies the conversation into a background session. | Don't watch a test suite run. |
| **Writer / Reviewer across sessions** | Session A implements; Session B: *"Review @src/… for edge cases, races, consistency with existing middleware."* Feed B's output to A. | Fresh context reviews better than the author's. Same reason the `reviewer` agent exists. |
| **Fan out only when the work is many identical units** | `/batch <instruction>` (5–30 worktree subagents, each opens a PR) or a `claude -p` loop over a file list. | Right for "migrate every component"; wrong as a default — token-heavy. |

### Model and cost

| Setting | How | Why |
|---|---|---|
| **Opus for everything, by default** | `/model`. The team's reasoning: it needs less steering and handles tools better, so it's faster *overall* despite slower tokens. | Fewer corrections beats faster tokens. |
| **Effort by task** | `/effort xhigh` for complex agentic coding; `max` for hard debugging or architecture, per session only (it burns usage fast). `/effort auto` lets Claude choose. | Spend thinking where it pays. |
| **`opusplan`** | `/model opusplan` — Opus plans, Sonnet executes. | Cheaper middle of a ticket. |
| **Fast mode for tight loops** | `/fast` on Opus — up to 2.5× faster at a higher per-token price. | Interactive debugging, not long runs. |
| **Switch per task, not per message** | Changing model, effort or fast mode invalidates the prompt cache. | Caching is where speed and cost come from. |
| **Cost trap** | In `/model`, `Enter` changes your default for all sessions; `s` changes this session only. | Easy to pay Opus prices by accident everywhere. |

### Personal setup (once)

| Setting | How | Why |
|---|---|---|
| **Pre-approve safe commands instead of skipping permissions** | `/permissions` — allowlist with wildcards (`Bash(pnpm test *)`), checked into `.claude/settings.json` (the per-repo template does this). `/sandbox` for OS-level isolation with fewer prompts. Auto mode is now the default: a classifier approves routine actions and flags risky ones. | Fewer prompts with an auditable list, not `--dangerously-skip-permissions`. |
| **Chrome extension** | `claude --chrome`, `/chrome` for status. Desktop app has a built-in browser. | The team uses it on every web task to look at the UI and console after a change. Keep Playwright as the repeatable suite. |
| **Code-intelligence plugin for TypeScript** | `/plugin` → code intelligence. | Symbol navigation and error detection right after edits. |
| **GitHub app + Code Review** | `/install-github-app`; add a `REVIEW.md` mirroring the `pr-self-review` policy block. Then `@claude fix the failing check` on PRs. | Automatic first-pass review post-push — the safety net behind your pre-push gate. |
| **Auto-memory and `CLAUDE.md` as a learning log** | End corrections with *"update CLAUDE.md so this doesn't happen again"*. `/memory` to see what Claude saved. `/doctor` proposes cuts when `CLAUDE.md` grows. | The team calls this "compounding engineering": the error rate falls over months. |
| **Status line and notifications** | `/statusline` (shows context usage — the resource you're managing), `/color` to tell sessions apart, terminal notifications on. | You can't manage context you can't see. |
| **Output styles when learning a codebase** | `/config` → *Explanatory* (shows reasoning) or *Learning*. | Useful in unfamiliar code; turn off for speed. |
| **Routines and loops** | `/loop 10m check CI on this PR and fix failures` (local, session-scoped). `/schedule` for cloud jobs that run with the laptop closed (nightly triage, docs from yesterday's PRs). | Babysitting is a machine's job. |
| **Remote control** | `claude remote-control` / the mobile app's Code tab; `--teleport` to move a cloud session to your machine. | Nudge a long run from your phone. |

### Three failure patterns to recognise (official list)

1. **Kitchen-sink session** — unrelated tasks in one context. *Fix:* `/clear` between tasks.
2. **Correcting over and over** — context full of failed approaches. *Fix:* after two, `/clear` and a better prompt.
3. **Trust-then-verify gap** — plausible code, unhandled edge cases. *Fix:* always give Claude a check it can run; if you can't verify it, don't ship it.

### Where to look next

Claude Code ships weekly. Once a month: skim the [what's new](https://code.claude.com/docs/en/whats-new) page and the [best practices](https://code.claude.com/docs/en/best-practices) guide, run `/doctor`, and prune `CLAUDE.md`. The Claude Code team's own habits are in their [power user tips](https://support.claude.com/en/articles/14554000-claude-code-power-user-tips).

---

## What the well-known voices add

Checked against four widely cited sources: Boris Cherny (Claude Code's creator), Simon Willison ("Agentic Engineering Patterns"), Kieran Klaassen ("compound engineering"), and Sébastien Dubois (practitioner guide, updated Oct 2026). Most of what they say is already above — which is the point: the consensus is real. What they add, and where it now lives:

| Voice | Idea | Where it lives now |
|---|---|---|
| Klaassen | **Plan → Work → Assess → Compound.** The loop only improves if learnings are written somewhere Claude reads next time. | `/dimi:compound` skill; `.claude/rules/`; the Compound step at the end of `pr-self-review`. |
| Willison | **First run the tests** — know the baseline before you change anything; a failure you didn't cause is a follow-up, not a detour. **Red/green TDD** with the agent: failing test, watch it fail, commit it, implement. | `plan-from-ticket` §4, first paragraph. |
| Cherny | **`/dimi:commit-push-pr`** as a daily command, with inline bash pre-computing git state so no turn is wasted asking. | `/dimi:commit-push-pr` skill. |
| Cherny | **Normalise abandoning sessions** (he reports 10–20% of his remote sessions get abandoned). | Permission to `/clear` sooner — see "after two failed corrections". |
| Cherny | **Don't over-customise.** He runs Claude Code mostly out of the box. | A standing rule for this bundle: anything that hasn't earned its keep in two weeks gets deleted. |
| Cherny | **Code Simplifier and Verify App subagents** after the main work. | Built-in `/simplify`; `verifier` agent. |
| Klaassen | **Review agents with roles**, findings triaged by priority; **Playwright MCP as the QA team**. | `reviewer` agent with the two checklist skills; Playwright MCP is worth adding for the real-screen states in `ui-states-review`. |
| Willison | **"Hoard things you know how to do"** — every solved procedure becomes a skill. | The test for what deserves a skill: *would I want this exact procedure again?* |
| Willison | **Linear walkthroughs / interactive explanations** to understand unfamiliar code. | Pair with the *Explanatory* output style when onboarding to a module. |
| Dubois | **`HANDOFF.md` then a fresh session** beats `/compact`, which summarises when the session is least sharp. | "Compact deliberately" row above; the `SessionStart` hook automates the mechanical half. |

Caveats: Willison's guide was readable only as pattern headings, so his reasoning is summarised from the titles; Klaassen's interview is partly paywalled. Cherny's habits come from two independent write-ups that agree with each other.

Sources: InfoQ, *Claude Code creator's workflow* (Jan 2026) · *How the creator of Claude Code actually uses it* (Feb 2026) · Simon Willison, *Agentic Engineering Patterns* (Feb 2026) · Kieran Klaassen, *How to make Claude Code better every time* (Feb 2026) · Sébastien Dubois, *Claude Code Tips and Best Practices* (updated 17 Oct 2026) · Anthropic, *Best practices for Claude Code* · Claude Code team, *Power user tips*.
