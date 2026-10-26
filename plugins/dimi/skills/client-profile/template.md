# FDE client profile

> Read by the dimi skills to tailor advice. Rules and constraints only: no secrets, credentials, personal data or customer records. Name roles or teams, never people; name products, never endpoints.

**Last updated:** TBD · **Review date:** TBD · **Owner (role or team, not a person):** TBD · **Committed to the client repo:** yes | no

## Engagement

- Client and business unit: TBD
- Use case and success metric: TBD
- Milestones (demo, pilot, security review, go-live): TBD

## Platform

- Cloud and regions: TBD
- Runtime and hosting (Kubernetes, serverless, managed agent runtime): TBD
- Languages and frameworks: TBD
- Agent framework (and why): TBD

## Models

- Approved models and providers: TBD
- Model gateway (product name, not endpoint): TBD
- Pinned model versions: TBD
- Self-hosted models (if any): TBD

## Risk and approvals

| Action class | Examples | Rule |
| --- | --- | --- |
| Read-only internal | TBD | Runs automatically |
| Outbound (anything reaching an external address) | TBD | TBD |
| Reversible writes | TBD | Approval by TBD (role), or without approval with a sampled review by TBD (role) at TBD (rate) |
| Irreversible or financial | TBD | Always needs approval by TBD (role or team) |

**Severity overrides for reviews** (read by `review-agent` and `harden-mcp`, whose rubric or checklist ids go in the first column; severity is Critical, High, Medium or Low. `pr-self-review` maps them to its own scale: Critical → Blocker; High → Should fix, promoted to Blocker when it meets a Blocker criterion; Medium → Minor, promoted to Should fix when it sits on a realistic path; Low → Minor):

| Check id | Severity | Reason |
| --- | --- | --- |
| TBD | TBD | TBD |

## Identity

- Identity provider (product name): TBD
- Delegated (on-behalf-of) access available: TBD
- Agent identities (for autonomous runs): TBD

## Data

| Data class | Examples | Allowed models and regions | Retention |
| --- | --- | --- | --- |
| Public | TBD | TBD | TBD |
| Internal | TBD | TBD | TBD |
| Confidential or personal | TBD | TBD | TBD |
| Restricted or regulated | TBD | TBD | TBD |

- Zero data retention required: TBD
- Regulated regimes (GDPR, HIPAA, PCI DSS, EU AI Act category): TBD
- Hosted features approved or banned: TBD

## Observability

- Tracing and APM backend (product name): TBD
- LLM observability tool: TBD
- Prompt and output capture allowed: TBD

## Evaluation and acceptance

- Eval set location and owner (role or team): TBD
- Acceptance thresholds: TBD
- Who signs off (role or team, not a person): TBD

## Out of scope

- TBD
