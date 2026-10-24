---
name: "pr-security-data-review"
description: "Security and data-handling review of a working-tree or PR diff for a multi-tenant product: tenant isolation, authz gates and bypasses, injection, SSRF, secrets and env flags, PII and data minimisation, customer data in git, exports/XSS/prompt injection, unsafe defaults, new dependencies. Use alone or as stage 3 of pr-self-review."
---

# Security and data-handling review

Stage 3 of `pr-self-review`; also usable alone ("security pass before I push", "is there PII in my changes"). Input: a diff file `$DIFF` (working tree against the base branch including untracked files, or a PR's own base...head) and the code readable as it is now. Output: findings in the `pr-self-review` interchange format (category `security` or `data-handling`) plus a **mandatory** `CHECKED_CLEAN:` list naming every section below that was examined with the one-line reason it is clean. If the repo has its own security-review skill, run it too against the same tree and include its result.

If run alone, build the diff as `pr-correctness-scalability-review` does (merge-base diff plus `--no-index` diffs for untracked files).

**Confidence bar.** Report a security finding when you can show the path from an input an attacker or careless user controls to the effect. A missing defence with no reachable path is a `conventions` note, not a security finding. PLAUSIBLE when the path depends on deployment or vendor behaviour you cannot see; name the confirm step.

**Before commit, secrets come first.** Untracked and staged files are where credentials leak: run the secrets greps in section 3 over `$DIFF` and `git ls-files --others --exclude-standard` before anything else. A real secret anywhere in the tree about to be committed is a Blocker, and if it was ever committed on this branch it must be rotated, not just removed.

## 1. Threat-model the diff first (before any grep)

From the diff, list:
- **New or changed routes / endpoints / CLI commands / jobs**, and the gate on each (none, authenticated, tenant-scoped, admin).
- **New reads and writes of tenant data**, and through which layer (data layer with tenant header; direct DB; filesystem; object store).
- **New outbound calls** (vendor APIs, LLMs, webhooks, downloads): host selection, allowlists, verbs, pagination links followed.
- **New data flows**: where does user-, customer- or connector-sourced text end up? Logs, run outputs, result rows, findings/issues, LLM context, exports (CSV/PDF), UI, fixtures, error trackers.
- **New settings / config / env flags / feature switches**: who can change them, validated, audited, which verdict they influence, default in production.
- **New tools exposed to an agent or model**, and which have a consumer today.
- **New dependencies** (lockfile deltas) and **infra changes** (IaC, env vars, roles).

Everything below is checked against this list. A section with nothing in the list is still recorded in `CHECKED_CLEAN` as "no new surface".

## 2. Checklist

### Tenant isolation
- Every read/write carries the tenant from **session or job claims**, never from the request body, URL or model output. For each `tenant_id`/`tenantId` in added lines, trace its source. A client-supplied tenant key accepted anywhere is a Blocker.
- Workers/agents never touch tenant tables directly; every data-layer call carries the tenant.
- Two-step flows: the commit route re-reads the stored proposal and **refuses proposals from another tenant**.
- Shared processes: per-tenant sessions are request-scoped (`ContextVar`, built per call, reset after), never module-level. A cross-tenant (`tenant_b`) test exists.

### Authorization and gate bypass
- Every write path is gated. Check **both halves** of two-step flows (propose *and* commit; preview *and* apply).
- **Alternate paths**: if the edit route refuses a record class or field (user records, encrypted fields), do import, bulk patch, agent write and fill-empty refuse too? Trace the record type through every write path in the diff.
- Replay/idempotency checks run **after** kind and ownership checks, not before.
- Read visibility is a *deliberate* choice: a GET open to every tenant user that exposes approver names, allowlists or exception lists → "probably acceptable, confirm it is intended".
- Authorization stays server-side; UI-only `disabled` flags are not authorization.

### Input validation and request bounds
- Verdict-affecting settings validated **server-side** for shape and range (`'abc'` for a percentage, non-list for a list, `min_pct=0`, `max_count=99999`). Unknown key → whole patch refused.
- Model output schema-validated before any write; edge types checked against the registry; a person accepts every write.
- Ids entering URLs or queries format-checked (GUID / resource-path regex).
- **Bounds per request**: body size, list length (a 100-item batch driving ~200 sequential lookups is a DoS lever as well as a timeout), pagination depth, upload size and type.
- **Files and paths**: filenames or paths from user or connector input sanitised against traversal; content type and size enforced; stored names generated, not supplied.

### Injection
- SQL or any vendor query DSL: parameterised values, enum-validated tokens, regex-validated identifiers, bounded integers; constants via `json.dumps`/parameters, never concatenated text. The data layer's filter compiler is the only path to the store.
- **CSV/spreadsheet export**: values starting with `=`, `+`, `-`, `@`, tab or CR neutralised (prefix `'` and quote). Hostnames, titles, owners, test names are attacker-influenced.
- **XSS**: no `dangerouslySetInnerHTML`/`innerHTML`/`v-html`; server-built strings rendered as text; URL params used only as map keys.
- **Prompt injection**: record/connector text reaches the model only as tool results; model output re-validated and needs human Accept; no silent writes; system-prompt rules do not let the model assert facts it has not read ("test X covers this" when X is inactive).

### LLM and agent code (when the diff touches prompts, tools, agents or MCP)
- **Rule of two**: no agent or flow combines (a) untrusted input, (b) sensitive data or systems, and (c) the ability to change state or communicate externally, without a human approval between. Map each changed agent against the three.
- **Untrusted content labelled**: retrieved, fetched or tool-returned text is wrapped with its source and kept out of the instruction section of the prompt.
- **Secrets kept from the model**: no credentials in prompts, tool results, context or traces; injected at execution time inside the tool.
- **Outbound channels gated**: tools that fetch arbitrary URLs, send email/webhooks, or render links or images from model output are allowlisted or approval-gated.
- **MCP servers vetted**: allowlisted, versions pinned, tool definitions reviewed, remote servers behind a gateway; `.mcp.json` changes are reviewed like dependency changes.
- **Model versions pinned** (no floating aliases in production config); prompt and output capture off by default in traces.
- If `.claude/fde-client-profile.md` exists, its data classes, residency, retention and risk tiers set the severities here. Run `/dimi:review-agent <changed paths>` for the full 57-check rubric and `/dimi:harden-mcp <path>` for MCP servers, and fold their findings into this report rather than re-deriving them.

### Outbound calls and SSRF
- Hosts fixed or chosen from a constant allowlist, never a typed URL; vendor region/redirect headers not followed.
- Pagination links followed only on the same scheme and host and an allowlisted path, with a page cap that **errors rather than returns a silent partial list**.
- Read-only connectors enforce `(method, path-regex)` allowlists in the single request function, **pinned by a test**; the only POSTs are token minting and documented query jobs.
- 429/Retry-After through the shared envelope; retry inside the request, not around the whole walk.
- **Least privilege in runbooks**: roles/scopes customers are told to grant match what the code calls; nothing granted for an unused tool; no broad permission when read suffices.

### Secrets and configuration
- Secrets and tokens: `repr=False`/redacted; never in logs, errors or exceptions; sent only to the token endpoint (tested); cached per session; single re-mint on 401.
- Error envelopes carry status and path only, never bodies, query strings or vendor error text.
- Fixtures use obvious placeholders (`demo-not-a-secret`, zero GUIDs). `.env*`, key files, exported tokens and local DB dumps are **never staged**.
- **Env flags and dev modes** (fixture replay, local credential-store defaults, mock providers): refused outside development **in code**, with the production value set by IaC, not a README. New env vars have a safe default when unset.
- **Mock/stub/demo data** lives only in tests, e2e stubs and fixtures, never in `src`.

### Personal data and data minimisation
A product that handles personal data collects the minimum. For every projected field and every row a tool returns: "who needs this, and where does it go?"
- **Projections drop** emails, user names, IPs, MACs, locations, command text unless a reviewed test needs them; prefer stable object ids over user principal names or emails.
- Distinguish **durable stored records** (protected by a stored-field allowlist) from **run outputs, failed-subject lists, finding descriptions and model context**, which usually are not. Passing a whole raw row through as the subject is a red flag.
- **Tools that can return personal data but have no consumer** (a summary tool with a rows mode that returns user, IP and location per event) are a Blocker-level data-handling finding even when latent. Remove until a reviewed consumer needs them.
- Logs and error trackers carry ids, counts, key names and error codes — never setting values, emails, credential config, payloads.
- Auto-written findings/issues: at most N subjects in the description; triage fields left for a person.

### Customer data and identifiers in the repo
- Customer names, their tooling, record ids, workbook content (catalogues, crosswalks, mapping rows "transcribed from" a customer), POC ticket keys baked into **dedupe keys or source refs** (unchangeable later without breaking dedupe).
- Fixture organisations and controls that look real ("<Customer>, Inc.").
- Design notes under policy-ignored paths that were force-added: `git diff --name-only --diff-filter=A $BASE | xargs -r git check-ignore -v`; also `git diff --cached --name-only | xargs -r git check-ignore -v` before commit.
- Merged history is permanent → Blocker or Should fix, never Minor. Before commit is the cheapest moment to remove it; once pushed it needs a history rewrite.

### Defaults, tenant controls and audit
- A feature **on by default with no per-tenant opt-out** (findings raised for every tenant after deploy) is a product decision to record and confirm; flag it.
- Verdict-affecting settings audited: who, when, old value, new value. `console.info` of key names is not an audit trail.
- Approved exceptions and change approvals are **records with approver and expiry**, not lists in a config blob.

### Integrity: concurrency, verification, deletion policy
- Read-then-write dedupe with no unique constraint or lock → duplicates under overlapping runs. Name the lease; confirm it covers manual runs, retries and saved tests, or mark PLAUSIBLE.
- "Verify" must **fail** on mismatch (a configured id pointing at a different account or workspace → mixed evidence from two sources passing as one).
- Partial reads refused as data so a coverage test cannot PASS on items it never saw; a 2xx with an embedded `errors` list or partial-result flag treated as error; unreadable sources reported as unread, not omitted.
- If records policy **forbids deleting**, every record-creation bug (duplicates, wrong keys) is permanent: raise severity.

### Dependencies and infrastructure
- New packages: why needed, maintained, licence acceptable, no known vulns (`npm audit` / `pip-audit` if available); versions pinned; lockfile updated consistently with the manifest.
- IaC changes: new roles/policies least-privilege; no secrets in env definitions; production flags set.

## 3. Quick greps (read around every hit)
```bash
# secrets — run first, over the diff and over untracked files
grep -niE '^\+.*(secret|password|passwd|token|api[_-]?key|BEGIN (RSA|EC|OPENSSH|PRIVATE)|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,})' $DIFF
git ls-files --others --exclude-standard | grep -iE '(\.env|\.pem|\.key|\.p12|credentials|\.sqlite|\.dump|\.bak)$'

grep -nE '^\+.*(dangerouslySetInnerHTML|innerHTML|v-html)' $DIFF
grep -nE '^\+.*(tenant_id|tenantId)' $DIFF | grep -vE 'session|claims|headers'       # tenant from where?
grep -niE '^\+.*(\.post\(|\.put\(|\.patch\(|\.delete\(|method[:=]\s*.(POST|PUT|PATCH|DELETE))' $DIFF
grep -niE '^\+.*(nextLink|next_link|\bnext\b).*(get|fetch|request)' $DIFF
grep -niE '^\+.*(email|UserPrincipalName|IPAddress|Location|MACAddress|hostname|username)' $DIFF
grep -nE '^\+.*(console\.(log|info|warn|error)|logger\.|logging\.|print\()' $DIFF   # what is logged?
grep -niE '^\+.*(toCsv|\.csv|text/csv|xlsx)' $DIFF
grep -niE '^\+.*(process\.env|os\.environ|getenv)' $DIFF                             # new flags and their defaults
grep -niE '^\+.*(mock|stub|fake|demo)' $DIFF | grep -vE '(test|spec|fixture|e2e)s?/'   # mock data in src?
grep -niE '<CUSTOMER_TERMS from the pr-self-review policy block>' $DIFF
git diff --name-only $BASE | grep -E '(package-lock|yarn\.lock|pnpm-lock|poetry\.lock|requirements|pyproject)'
```

## 4. Strengths to recognise (write them down)
Read-only allowlists pinned by tests; fixed hosts with no override; same-host pagination with an erroring cap; per-session token caches with `repr=False`; error envelopes with status and path only; projections that drop PII; no free-form query language; a config key deliberately not named `tenant_id`; writes only through the data layer with the tenant header; both propose and commit gated; ambiguous references refused; commits that take only a proposal id and write what the server stored; logs with keys and ids only; cross-tenant tests; dev modes refused in production by code.

## 5. Reporting
Use the `pr-self-review` interchange format with category `security` or `data-handling`. Then `CHECKED_CLEAN:` — one line per section above that you examined (secrets in tree; tenant isolation; authorization; input validation and bounds; injection, naming the DSLs; SSRF and read-only enforcement; env flags and config; PII in logs; PII in outputs; customer data; force-adds; CSV/XSS; prompt injection; least privilege; defaults/tenant controls; audit; integrity; dependencies/infra) with the one-line reason. Never list a section you did not actually check; write "not checked — <why>" instead.