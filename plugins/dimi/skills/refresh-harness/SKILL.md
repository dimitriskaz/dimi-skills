---
name: refresh-harness
description: Update the dated facts in the dimi harness reference - framework versions and statuses, MCP and A2A spec revisions, deprecations, embedding and reranker models, prices, benchmark versions and acquisitions - by checking official sources, then prepare a pull request. Run only from a checkout of the dimi-skills repository.
argument-hint: "[frameworks | mcp | rag | observability | orchestration | cross-cutting | all]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Edit Write WebFetch WebSearch Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git remote *) Bash(git checkout *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(gh pr create *) Bash(claude plugin validate *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Refresh the harness reference

Area to refresh: $ARGUMENTS (default: all). Cadence: run it on the first working day of each month, and whenever a spec revision, framework major version or acquisition is announced.

## Context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/refresh-harness.sh`

## Before you start

- The remote must be the `dimi-skills` repository and the working tree clean. If not, stop and ask the user to run this from a clean checkout of dimi-skills. Never edit the installed plugin cache.
- Create a branch named `refresh/<today>`.

## Files that carry dated facts

Every file below has an "as of" note in its first blockquote line (or a dated fact that depends on one). An area refresh edits the files in its rows; `all` edits every row. Paths are relative to the repository root.

| Area | Files to check and update |
| --- | --- |
| frameworks | `plugins/dimi/skills/harness-reference/references/frameworks.md`; `plugins/dimi/skills/agent-bootstrap/references/landscape.md` (names and positioning only) |
| mcp | `plugins/dimi/skills/harness-reference/references/tools-and-mcp.md`; `plugins/dimi/skills/harden-mcp/references/checklist.md` (spec revision in the first line, the section 1 summary of what it changed, P1 and P2); `plugins/dimi/skills/harden-mcp/references/patterns.md` |
| rag | `plugins/dimi/skills/harness-reference/references/rag.md` |
| observability | `plugins/dimi/skills/harness-reference/references/observability.md` |
| orchestration | `plugins/dimi/skills/harness-reference/references/orchestration.md` (A2A revision and governance dates, builder shutdowns); `plugins/dimi/skills/harness-reference/references/overview.md` and `playbook.md` (as-of line only) |
| cross-cutting | `plugins/dimi/skills/harness-reference/references/cross-cutting.md` (platform identity, gateway and guardrail products, regulation dates) |
| every area | `plugins/dimi/skills/harness-reference/references/sources.md` (add new sources; confirm the URL shapes it flags); `plugins/dimi/skills/review-agent/references/rubric.md` and `plugins/dimi/skills/review-agent/references/patterns.md` (as-of line and any check that names a framework default); `plugins/dimi/README.md` (check that no line carries a spec date or version — the minimum Claude Code version on the install line is a requirement, not a dated fact, and stays) |

`plugins/dimi/skills/harness-reference/SKILL.md` carries no date: it tells readers to quote the oldest as-of line among the reference files.

## Steps

1. **List the dated claims.** Read `plugins/dimi/skills/harness-reference/references/sources.md` ("Where to check first") and the files for the chosen area from the table above. List every claim that can go stale: versions, GA or preview status, release and deprecation dates, spec revisions, prices and multipliers, model names, benchmark versions, ownership.
2. **Check each claim at its source.** Use official docs, release notes and changelogs; for package versions use `https://pypi.org/pypi/<package>/json` and `https://registry.npmjs.org/<package>/latest`. For a full refresh, if an Agent tool is available, split the work by area across subagents, each returning claim, old value, new value and source URL; otherwise work through the areas in the table order.
3. **Edit only what changed.** Keep each file's structure and style. Set the "as of" date in the first blockquote line of every file you edit, keeping that file's format: either `> As of <D Month YYYY>. <one sentence on how to re-verify>` or, in the harness-reference files, `> From *The Agentic Harness: A Layer-by-Layer Guide*, as of <D Month YYYY>. …`. Add any new source to `sources.md`. A claim whose source cannot be reached or is ambiguous keeps its old value and gets an inline bracketed note immediately after the fact: `[unverified as of <today>]`.
4. **Propagate changes that alter advice.** If a framework enters maintenance mode, a spec deprecates or adds a feature, a default changes, or a hosted feature changes its data-retention terms, update the matching checks in `plugins/dimi/skills/review-agent/references/rubric.md` and `plugins/dimi/skills/harden-mcp/references/checklist.md`, and the "Defaults to apply without being asked" list in `plugins/dimi/skills/harness-reference/SKILL.md`.
5. **Sweep for stragglers.** In the files of the refreshed area (every file in the table for `all`), grep for the previous as-of date string (for example `24 October 2026`); a file outside that area keeps its own date, because its facts were not re-checked. When the MCP spec revision changed, grep the whole repository for the previous revision string (the one `checklist.md` named before this refresh) in every form it appears; nothing may remain outside `CHANGELOG.md` except historical references that say when something was introduced or changed ("introduced in <revision>", "the <revision> revision changed …", "since <revision>", "<revision> onward"). Also grep for `[unverified as of` and list the hits in the pull request.
6. **Record the release.** Add an entry to `plugins/dimi/CHANGELOG.md` and bump `version` in `plugins/dimi/.claude-plugin/plugin.json`: patch for fact updates, minor for new or changed checks.
7. **Validate.** If the Claude Code CLI is available, run `claude plugin validate ./` and `claude plugin validate ./plugins/dimi --strict`, and fix any errors.
8. **Prepare the pull request.** Stage the edited files by explicit path and commit as `docs: refresh <area> reference facts (as of <D Month YYYY>)`: this repository uses conventional commits without ticket keys. The dimi Bash guard asks for a ticket key unless its ticket check is off for this repository (the `ticket_regex` plugin option set to `none`, or `GUARD_TICKET_REGEX=none` in the `env` of the repository's `.claude/settings.json` when the option is unset). If it blocks the commit for a missing ticket key, stop and ask the user to turn the check off for this repository or to give a key; never route around the guard (`-F`, `--no-verify`, another shell). Then push the branch and open a pull request whose description has a table of changes (claim, old, new, source) and the list of unverified claims. Do not merge it.

## Rules

- Never invent or estimate a version, date or price. If a source cannot be reached or is ambiguous, leave the claim as it is and mark it `[unverified as of <today>]` as in step 3.
- Prefer primary sources (vendor docs, release notes, specs, registries) over blogs and aggregators.
- Never add client names, client architecture or client data to this repository.
