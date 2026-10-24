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
3. `/plugin` → dimi → **Configure options**: ticket regex, default branch, typecheck script, Python lint command, local checks line.
4. Merge `CLAUDE.md.snippet` into `CLAUDE.md`; run `/doctor`.
5. Check the `paths:` globs in `.claude/rules/*.md` match the repo layout.
6. New session → `/hooks` shows four plugin hooks, `/agents` five agents, `/dimi:` autocompletes ten skills.

`jq` must be on PATH for the hooks. The Stop gate keeps its cache in the plugin data directory; if you run the scripts outside the plugin it falls back to `.claude/.cache/`, so add that to `.gitignore`.
