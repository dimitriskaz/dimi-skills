---
name: refresh-harness
description: Update the dated facts in the dimi harness reference - framework versions and statuses, MCP and A2A spec revisions, deprecations, embedding and reranker models, prices, benchmark versions and acquisitions - by checking official sources, then prepare a pull request. Run only from a checkout of the dimi-skills repository.
argument-hint: "[frameworks | mcp | rag | observability | all]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Edit Write WebFetch WebSearch Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git remote *) Bash(git checkout *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(gh pr create *) Bash(claude plugin validate *)
---

# Refresh the harness reference

Area to refresh: $ARGUMENTS (default: all).

## Context

Repository remote: !`git remote get-url origin 2>/dev/null || echo "no git remote"`

Working tree: !`git status --short 2>/dev/null | head -20`

Today (UTC): !`date -u +%Y-%m-%d`

## Before you start

- The remote must be the `dimi-skills` repository and the working tree clean. If not, stop and ask the user to run this from a clean checkout of dimi-skills. Never edit the installed plugin cache.
- Create a branch named `refresh/<today>`.

## Steps

1. **List the dated claims.** Read `plugins/dimi/skills/harness-reference/references/sources.md` ("Where to check first") and the reference files for the chosen area. List every claim that can go stale: versions, GA or preview status, release and deprecation dates, spec revisions, prices and multipliers, model names, benchmark versions, ownership.
2. **Check each claim at its source.** Use official docs, release notes and changelogs; for package versions use `https://pypi.org/pypi/<package>/json` and `https://registry.npmjs.org/<package>/latest`. For a full refresh, split the work by area across parallel subagents, each returning claim, old value, new value and source URL.
3. **Edit only what changed.** Keep each file's structure and style. Update the "as of" date in the note at the top of every file you edit. Add any new source to `sources.md`.
4. **Propagate changes that alter advice.** If a framework enters maintenance mode, a spec deprecates or adds a feature, a default changes, or a hosted feature changes its data-retention terms, update the matching checks in `plugins/dimi/skills/review-agent/references/rubric.md`, `plugins/dimi/skills/harden-mcp/references/checklist.md` and the defaults list in `harness-reference/SKILL.md`.
5. **Record the release.** Add an entry to `plugins/dimi/CHANGELOG.md` and bump `version` in `plugins/dimi/.claude-plugin/plugin.json`: patch for fact updates, minor for new or changed checks.
6. **Validate.** If the Claude Code CLI is available, run `claude plugin validate ./` and `claude plugin validate ./plugins/dimi --strict`, and fix any errors.
7. **Prepare the pull request.** Commit, push the branch and open a pull request whose description has a table of changes (claim, old, new, source). Do not merge it.

## Rules

- Never invent or estimate a version, date or price. If a source cannot be reached or is ambiguous, leave the claim as it is and mark it "unverified as of <today>".
- Prefer primary sources (vendor docs, release notes, specs, registries) over blogs and aggregators.
- Never add client names, client architecture or client data to this repository.
