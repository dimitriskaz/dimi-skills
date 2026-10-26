---
name: client-profile
description: Create or update the client engagement profile at .claude/fde-client-profile.md in the current project - cloud, approved models and regions, languages and frameworks, risk tiers and approval rules, data classes and retention, identity provider, observability stack and acceptance criteria. The other dimi skills read this file to tailor their advice. Use at the start of a client engagement or when the client's constraints change.
argument-hint: "[client or engagement name]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Write Edit Bash(git ls-files *) Bash(git rev-parse *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Client engagement profile

Engagement: $ARGUMENTS (if empty, ask for the engagement name first).

## Context

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/state/client-profile.sh`

## Steps

**Never write into this plugin's own repository.** If the context shows "Plugin repository (dimi-skills): yes", stop: a client profile must never be written to the dimi-skills repository, which travels to every engagement. Ask the user to run this from the client project.

1. **Start from the template** at `${CLAUDE_SKILL_DIR}/template.md`, or from the existing profile if there is one.
2. **Fill what the repository already shows.** Infer cloud and regions from infrastructure code (Terraform, Bicep, CloudFormation, Helm), languages and frameworks from lockfiles, model IDs from config, and tracing backends from dependencies. Mark each inferred value "(inferred from <file>)".
3. **Ask the user for the rest** in one short batch of questions: risk tiers and approval rules, data classes and residency, retention, zero-data-retention or regulated-data needs (HIPAA, PCI DSS), identity provider, approved models, acceptance criteria and deadlines, and whether the file will be committed to the client repository. Leave anything unanswered as `TBD`.
4. **Check the draft before writing it.** Whether or not the file will be committed, write it as if it will be handed over, so it holds rules and constraints only: no secrets, credentials, personal data or customer records. Name roles or teams, never people; name products (gateway, identity provider, APM), never endpoints or hostnames. Scan the draft for key or token shapes (`AKIA`, `sk-`, `ghp_`, `Bearer `, `-----BEGIN`, `password`, `secret`, `token=`, long base64 or hex runs, email addresses) and remove any hit before going on. Fill `Last updated` with today and `Review date` with today plus three months.
5. **Write** `.claude/fde-client-profile.md`. If the user said the file will not be committed and the context shows it is neither tracked nor ignored, add the line `.claude/fde-client-profile.md` to the repository's local exclude file (its path is `git rev-parse --git-path info/exclude`), not to `.gitignore`. Show the user a short summary of what changed and repeat the "rules and constraints only" reminder.
