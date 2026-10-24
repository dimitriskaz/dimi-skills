# Working in dimi-skills

This repository is a Claude Code plugin marketplace. Follow these conventions when adding or changing skills.

## Never

- Add client names, client architecture, client data, credentials or anything learned on a specific engagement. This repository travels to every engagement.
- Add repository facts (ticket regexes, paths, script names, folder globs) into a skill body. They go in plugin `userConfig` options, the `pr-self-review` "Repo policy" block, or the per-repo `templates/project-claude/` starter.
- Edit files in an installed plugin cache. Change them here, then release.

## Skills

- One folder per skill under `plugins/<plugin>/skills/<skill-name>/`, with a `SKILL.md`. Folder names are kebab-case.
- Keep `SKILL.md` under 500 lines. Put long material in a `references/` folder and link to it from `SKILL.md` with relative links.
- Write descriptions that lead with the main use case and include phrases a user would actually say. Description plus `when_to_use` is truncated at 1,536 characters in the skill listing.
- Use `disable-model-invocation: true` for skills with side effects, `user-invocable: false` for background knowledge, and `context: fork` for self-contained review tasks.
- Keep `` !`command` `` injections safe to run anywhere: a failing command aborts the skill, so add a fallback (`|| echo "..."`).
- Reference other skills' files with `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/...`; reference files in the same skill with relative links or `${CLAUDE_SKILL_DIR}`.

## Hooks and agents

- Hook scripts read `CLAUDE_PLUGIN_OPTION_<KEY>` first, env vars second, defaults last; never hard-code a repo value.
- Every hook must exit 0 fast when nothing changed, and must never block more than once per turn (`stop_hook_active`). Dry-run each script against a scratch git repo before release; a broken Stop hook blocks every turn for every user.
- Hooks are registered in `hooks/hooks.json` only. The per-repo template must not repeat them, or they run twice.
- Agents that review the working tree must not use `isolation: worktree` (a worktree branches from the default branch and cannot see uncommitted work). Only `implementer` is isolated.

## Facts that go stale

- Keep dated facts (versions, statuses, prices, spec revisions) in reference files with an "as of" note at the top, never in `SKILL.md` instructions.
- Code patterns must be tested before they are committed, and must not depend on a specific framework version unless the file says so.

## Releasing

1. Validate: `claude plugin validate ./` and `claude plugin validate ./plugins/dimi --strict`.
2. Add a `plugins/dimi/CHANGELOG.md` entry and bump `version` in `plugins/dimi/.claude-plugin/plugin.json` (patch for fact updates, minor for new or changed skills or checks, major for breaking changes).
3. Merge through a pull request. Tag the release `v<version>` (one plugin, one version) so users can pin the marketplace to it.
