---
name: client-profile
description: Create or update the client engagement profile at .claude/fde-client-profile.md in the current project - cloud, approved models and regions, languages and frameworks, risk tiers and approval rules, data classes and retention, identity provider, observability stack and acceptance criteria. The other dimi skills read this file to tailor their advice. Use at the start of a client engagement or when the client's constraints change.
argument-hint: "[client or engagement name]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Write Edit Bash(git ls-files *)
---

# Client engagement profile

Engagement: $ARGUMENTS

Existing profile:

!`cat .claude/fde-client-profile.md 2>/dev/null || echo "None yet."`

Repository files:

!`git ls-files 2>/dev/null | head -300`

## Steps

1. **Start from the template** at `${CLAUDE_SKILL_DIR}/template.md`, or from the existing profile if there is one.
2. **Fill what the repository already shows.** Infer cloud and regions from infrastructure code (Terraform, Bicep, CloudFormation, Helm), languages and frameworks from lockfiles, model IDs from config, and tracing backends from dependencies. Mark each inferred value "(inferred from <file>)".
3. **Ask the user for the rest** in one short batch of questions: risk tiers and approval rules, data classes and residency, retention, zero-data-retention or regulated-data needs (HIPAA, PCI DSS), identity provider, approved models, acceptance criteria and deadlines. Leave anything unanswered as `TBD`.
4. **Write** `.claude/fde-client-profile.md`. Show the user a short summary of what changed.
5. **Remind the user** that the file is meant to be committed to the client repository for handover, so it must contain rules and constraints only: no secrets, credentials, personal data or customer records.
