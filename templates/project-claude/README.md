# Per-repo starter (`templates/project-claude/`)

Everything a plugin cannot carry, because it is about one repository:

| File | Why it lives in the repo, not the plugin |
| --- | --- |
| `.claude/settings.json` | Permission allow/deny lists (plugins cannot set permissions) and `enabledPlugins` so collaborators get `dimi` on checkout. **No hooks block** — the plugin registers the hooks. |
| `.claude/rules/*.md` | Path-scoped judgement for this repo's folders. `/dimi:compound` writes here. Globs assume `apps/`, `services/`, `packages/`; adjust. |
| `CLAUDE.md.snippet` | Commands, Speed rules, workflow, compaction rule, gotchas — merge into the repo's `CLAUDE.md`. |

## Install into a repo

1. Copy `.claude/` into the repo root (merge with any existing `settings.json`; keep theirs if it already has permissions, add `enabledPlugins`).
2. Each collaborator once: `claude plugin marketplace add dimitriskaz/dimi-skills` then `claude plugin install dimi@dimi-skills --scope project`. (Committing `enabledPlugins` turns it on; it does not download it.)
3. `/plugin` → dimi → **Configure options**: ticket regex (`none` for repos without ticket keys), default branch, typecheck script, Python lint command, local checks line, and `demo_branch` if the repo has one.
4. Merge `CLAUDE.md.snippet` into `CLAUDE.md`; run `/doctor`.
5. Check the `paths:` globs in `.claude/rules/*.md` match the repo layout.
6. Add `.claude/.cache/` (the hooks' fallback state directory) and `.claude/worktrees/` (where the `implementer` agent's worktrees live until you `git worktree remove` them) to the repo's `.gitignore`.
7. New session → `/hooks` shows five plugin hooks, `/agents` six agents, `/dimi:` autocompletes twenty-two skills (`harness-reference` is background knowledge, not invocable).

`jq` must be on PATH for the hooks; without it they exit quietly and the session banner says so. The Stop gate keeps its cache in the plugin data directory and falls back to `.claude/.cache/` when the scripts run outside the plugin. The Stop gate never blocks on a missing tool: a package manager or linter that is not installed is reported once as a warning and that check is skipped. The `Agent(fork)` deny rule in `settings.json` has not been tested against `context: fork` skills (`review-agent`, `harden-mcp`); if those fail to start, remove that rule.
