# dimi-skills

A Claude Code plugin marketplace with one plugin, `dimi`: a reviewer-grade development loop (skills, agents, hooks) and forward-deployed engineering know-how for LLM agents. One rule: generic, reusable know-how only. Anything specific to a repository or a client lives in that repository (`.claude/rules/`, `CLAUDE.md`, `.claude/fde-client-profile.md`).

## What you get

| Half | Skills | Also |
| --- | --- | --- |
| **Development loop** | `help`, `grill-me`, `plan-from-ticket`, `ui-states-review`, `agent-ui-review`, `tidy`, `pr-self-review` (+ `pr-correctness-scalability-review`, `pr-security-data-review`), `commit-push-pr`, `address-review`, `compound`, `debug`, `walkthrough`, `release-notes`, `report`, `build-report`, `poc`, `port`, `agent-tool-design`, `agent-bootstrap`, `agent-evals` | 6 agents (`explore`, `reviewer`, `verifier`, `spec-writer`, `implementer`, `debugger`); 5 hooks (format on edit, Stop gate, Bash guard, session banner, session-end note) |
| **Agent engineering** | `harness-reference`, `review-agent`, `harden-mcp`, `client-profile`, `refresh-harness` | reference library with "as of" dates; rubrics with tested fix patterns |

They compose: `pr-self-review` calls `review-agent`/`harden-mcp` when a diff touches agent or MCP code; `agent-bootstrap` reads `harness-reference`; every skill honours `.claude/fde-client-profile.md`. Details: [plugins/dimi/README.md](plugins/dimi/README.md) and [docs/guide.md](docs/guide.md).

## Install

In a Claude Code session:

```
/plugin marketplace add dimitriskaz/dimi-skills
/plugin install dimi@dimi-skills
```

Or from a shell:

```
claude plugin marketplace add dimitriskaz/dimi-skills
claude plugin install dimi@dimi-skills --scope user       # follows you to every repository; never committed into client code
claude plugin install dimi@dimi-skills --scope project    # team repositories: commit enabledPlugins so collaborators get it (see templates/project-claude)
```

Install at **user** scope by default. Use **project** scope in team repositories where everyone should get the same gate — and copy `templates/project-claude/` in too, because a plugin cannot carry permissions or `.claude/rules/`. The repository is private, so your machine needs GitHub access to it (for example through `gh auth login`). Cloud sessions do not load plugins; install and use it from the terminal, VS Code or the desktop app.

### Updates and pinning

- Third-party marketplaces do not auto-update by default. Turn it on in `/plugin` → Marketplaces, or update manually: `claude plugin marketplace update dimi-skills`, then `claude plugin update dimi@dimi-skills`.
- The `version` in `plugins/dimi/.claude-plugin/plugin.json` controls updates: users stay on a version until it is bumped.
- To pin to a release, add the marketplace with a ref: `/plugin marketplace add dimitriskaz/dimi-skills#v1.8.0`.

## Recommended marketplaces

dimi is one plugin. These third-party marketplaces pair well with it; each is installed from its own repository, keeps its own prefix and its own licence (all MIT), and nothing from them is copied into dimi.

| Marketplace | Add it | Install | What it gives you next to dimi |
| --- | --- | --- | --- |
| [ponytail](https://github.com/DietrichGebert/ponytail) | `/plugin marketplace add DietrichGebert/ponytail` | `/plugin install ponytail@ponytail` | A stance for *writing* code: the least code that works, climbed rung by rung (exists already, standard library, platform, installed dependency, one line, then the minimum), never cutting validation, data-loss handling, security or accessibility; `shortcut:` markers with a debt ledger; a cost band above the prompt. Entry: `/ponytail full`, `/ponytail-review`, `/ponytail-audit` |
| [cursor/plugins](https://github.com/cursor/plugins) | `/plugin marketplace add cursor/plugins` | `/plugin install pstack@cursor-plugins` | pstack: state a goal and a checkable done condition and `/pstack:poteto-mode` picks the playbook and shows evidence; named principles to steer with mid-task; a decision log and overnight contract for unattended runs; `unslop`, `no-comments`, `tdd`, a benchmark checklist |
| [cursor/plugins](https://github.com/cursor/plugins/tree/main/cursor-team-kit), cursor-team-kit | see below | see below | `thermo-nuclear-code-quality-review`, an unusually strict maintainability review (code-judo simplifications, branching growth, files past 1,000 lines, thin wrappers, casts, logic in the wrong layer), plus `deslop`, `verify-this`, `fix-ci`, `loop-on-ci`, `review-and-ship`, `what-did-i-get-done`, `weekly-review` |

How they overlap with dimi: `/ponytail-review` and pstack's bug-fix, feature and PR playbooks parallel `pr-self-review` and the dimi loop, so use one per task; the thermo-nuclear review covers structure, which `pr-self-review` does not, so it runs well after it. Ponytail installs its own hooks (status line, band), which run beside dimi's.

**cursor-team-kit** is written for Cursor and is not in Cursor's Claude Code marketplace file (only `pstack` and `origin-apps` are). Its `skills/` are plain `SKILL.md` files, so Claude Code can still load it two ways:

- Quick, one skill: copy `cursor-team-kit/skills/thermo-nuclear-code-quality-review/` into `~/.claude/skills/`. It then runs as `/thermo-nuclear-code-quality-review` and is updated by copying again.
- Whole kit, updatable: declare an inline marketplace in `~/.claude/settings.json`, then `/plugin install cursor-team-kit@cursor-team-kit`. Claude Code fetches only that subdirectory; with no Claude Code manifest in it, the entry acts as the manifest and its `skills/` and `agents/` load while its Cursor `rules/` are ignored.
  ```json
  {
    "extraKnownMarketplaces": {
      "cursor-team-kit": {
        "source": {
          "source": "settings",
          "name": "cursor-team-kit",
          "owner": { "name": "Cursor" },
          "plugins": [
            { "name": "cursor-team-kit", "description": "Cursor team kit: thermo-nuclear review, deslop, verify-this, CI and shipping skills",
              "source": { "source": "git-subdir", "url": "cursor/plugins", "path": "cursor-team-kit" } }
          ]
        }
      }
    }
  }
  ```

Read a plugin's repository before installing it: its hooks and skills run with the same access dimi has. Third-party marketplaces do not auto-update; `claude plugin update <plugin>@<marketplace>` refreshes one, and `/plugin` → Marketplaces turns auto-update on per marketplace.

## Using it on a repository

1. Install at project scope and copy [`templates/project-claude/`](templates/project-claude/README.md) into the repo (permissions, `enabledPlugins`, starter `.claude/rules/`, `CLAUDE.md` snippet). Set the plugin options: `/plugin` → dimi → **Configure options** (ticket regex, default branch, typecheck script, Python lint command, local checks line).
2. Not sure which skill fits? `/dimi:help [task]` lists them all, including the manual-only ones Claude cannot see on its own.
3. Per ticket: `/dimi:plan-from-ticket` → `/dimi:grill-me` (optional, pressure-test the plan; it also works on a fresh idea before planning) → build → `/dimi:ui-states-review` (UI; plus `/dimi:agent-ui-review` for chat or agent screens) → `/dimi:tidy` → `/dimi:pr-self-review` → `/dimi:commit-push-pr` → paste the review into `/dimi:address-review` → `/dimi:compound`. Something red at any point: `/dimi:debug`.
4. The hooks run on their own: format on edit, Stop gate, Bash guard, session banner, session-end note. If Claude feels slow or several shells appear, read [docs/guide.md](docs/guide.md) → "If Claude feels slow".

## Demo branch and productionising (FDE)

A long-lived demo branch is normal on an engagement. Keep it honest with `/dimi:poc`: `init` once, `mark` every shortcut (`DEMO-ONLY(<feature>): why`), `push` straight to the shared demo branch behind a light gate, `sync` the default branch in by merge (never rebase), `ledger` to set a row by hand, `status` for what is demo-only, owed, in review or ported. When a feature is ready for production, `/dimi:port <feature>` computes the real delta, builds a local integration worktree of main plus your open PRs, classifies each hunk as reuse / rewrite / drop, picks the base (main, or stacked one level on the PR it depends on) and hands the build to the normal loop. The marker can never reach main: `pr-self-review` fails on it.

## Using it on a client engagement

1. In the client repository, run `/dimi:client-profile <client name>` to create `.claude/fde-client-profile.md`. Commit it: it is part of your handover.
2. Work normally. `harness-reference` loads when Claude works on agent code and applies the client profile's rules first; `/dimi:agent-bootstrap` scaffolds a new agent against those constraints.
3. Before milestones, run `/dimi:review-agent` and, if the project has an MCP server, `/dimi:harden-mcp`.

Keep client-specific skills (deploy steps, runbooks, conventions) in the client repository's `.claude/skills/`, not here.

## Repository layout

```
.claude-plugin/marketplace.json      marketplace definition (one plugin: dimi)
docs/guide.md                        what every development-loop file is and why; habits and settings beyond the plugin
templates/project-claude/            per-repo starter: settings (permissions, enabledPlugins), rules/, CLAUDE.md.snippet
plugins/dimi/
  .claude-plugin/plugin.json         manifest with userConfig options; bump version per release
  CHANGELOG.md · README.md
  skills/                            25 skills (20 development loop and agent building, 5 agent engineering)
  agents/                            explore, reviewer, verifier, spec-writer, implementer, debugger
  hooks/hooks.json                   5 hook registrations → scripts/
  scripts/                           5 hook scripts (format-file, stop-check, guard-bash, session-context, session-end-note),
                                     review helpers (review.sh), shared lib.sh, state/ (skills' pre-computed state)
```

## Maintaining

- Validate before merging: `claude plugin validate ./` and `claude plugin validate ./plugins/dimi --strict`.
- Hook scripts in `plugins/dimi/scripts/` are dry-run against a scratch git repo before release, on a GNU PATH and a macOS-like one (see the guide's "Testing the hooks"); a broken Stop hook blocks every turn for every user.
- Refresh dated facts monthly (the first working day): `/dimi:refresh-harness` from a clean checkout of this repository.
- One plugin, one version: every release bumps `plugins/dimi/.claude-plugin/plugin.json`, adds a `CHANGELOG.md` entry and is tagged `v<version>`.
- See [CLAUDE.md](CLAUDE.md) for authoring conventions.
