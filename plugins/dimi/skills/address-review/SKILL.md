---
name: address-review
description: Work through a colleague's review of your change — pasted comments or an attached review report — by verifying each point against the code, fixing what is right, pushing back with evidence on what is not, validating with pr-self-review, and drafting replies for you to paste back.
argument-hint: "[paste the review comments or attach the report]"
disable-model-invocation: true
---

# Address a review

Sits between `pr-self-review` (before the review) and `compound` (after it). Triggers: `/address-review` with the comments pasted or a report attached; "work through this review"; "my colleague found these, fix them".

Input is whatever you give it: pasted GitHub comments, an exported review report (HTML/Markdown/PDF), a Slack thread, a numbered findings list. Nothing is fetched and nothing is posted. You paste the replies back yourself.

Stance: the reviewer is a colleague, not an oracle. **Every point is verified against the code before anything is changed**, and every point gets a disposition and a reply. Nothing is fixed silently, nothing is ignored silently.

## 1. Build the worklist

Read the whole input. Extract one row per distinct point, merging duplicates and restatements:

```
id | reviewer's severity (if any) | path:line (if cited) | claim in one line | kind
```
`kind`: **defect** (code is wrong) · **design** (approach should change) · **question** (needs an answer, not a change) · **nit** (style, naming) · **scope** (beyond the ticket) · **process** (tests, evidence, PR hygiene).

If the input is a structured report (numbered findings with severities and confidence), keep its ids and severities so replies can reference them. If a comment cites a line that has since moved, map it to the current code and note that in the reply.

## 2. Verify every claim before touching code

For each row, read the cited code **and the other end of the mechanism** (caller, store path, consumer, test) as `pr-correctness-scalability-review` does. Record one of:
- **Confirmed** — the reviewer is right; one line on the mechanism.
- **Partly** — right in spirit, wrong in detail; say what is actually true.
- **Disagree** — already handled, or the premise is wrong; cite the evidence (`path:line`, the covering test).
- **Unclear** — you cannot tell what is being asked; draft the question.

Then group confirmed rows by **root cause**. Several comments often share one fix (an untrimmed id explains three "duplicate" comments). The fix list is by root cause, not by comment.

## 3. Propose dispositions, confirm once

Show the worklist with verification and a proposed disposition per row:
- **Fix now** — confirmed defects, design and process points inside the ticket's scope; nits under a minute.
- **Push back** — disagreements, with evidence and an alternative where useful. Never fix something you believe is wrong just to close the thread.
- **Answer** — questions.
- **Defer** — scope points, with a proposed follow-up ticket title.
- **Ask** — unclear items.

Reviewer's Blockers first, then Should-fix, then the rest. If the author is present, confirm the contested rows in one pass (AskUserQuestion). If not, proceed with confirmed "Fix now" rows only and leave the rest as drafts.

## 4. Fix

- One commit per root cause: `type(KEY): <what>`, body line `Addresses review: <ids>`. Stage explicit paths.
- For every fix, add or extend **the test that would fail without it**; the reviewer's comment is that test's description.
- Follow `.claude/rules/` and the canonical patterns in the repo. A review fix is not a licence for a quick hack; no escape hatches.
- Append commits; do not rebase, squash or force-push mid-review unless the team's convention says to. Ask if unsure.
- Run the narrowest check after each fix, then the touched packages' lint/typecheck/tests.

## 5. Validate

Run `pr-self-review` (local mode, re-run mode). It must show every "Fix now" row as `Fixed` with its commit and pinning test, no new Blocker, and a green compliance gate. If the self-review finds something the reviewer did not, fix it in this round and mention it in the summary — reviewers appreciate not having to find it next time. Then push with `commit-push-pr` if you want (it refuses on open Blockers and never force-pushes).

## 6. Draft the replies

One reply per point, short and specific, written to `$OUT/replies.md` for you to paste:
- Fixed: `Fixed in <sha>: <what changed>. Test: <name>.`
- Partly: `Right about X; Y is actually <evidence>. Fixed X in <sha>.`
- Disagree: `I don't think this applies: <evidence>. Happy to change if I'm missing something.`
- Answer / Defer (`Agree, out of scope for KEY — follow-up: <title>`) / Ask.

Plus a **summary** for the PR: what changed by root cause, what was pushed back on, what is deferred, what the self-review additionally caught, checks run (N of M specs, local vs CI).

## 7. Compound

The reviewer's comments are the best learning material you get. End by offering `/compound` with this worklist: confirmed defects become path-scoped rules; anything the reviewer caught that `pr-self-review` missed becomes an addition to the relevant checklist lens.

## Output

```
## Review round — <branch or PR>
| id | severity | claim | verified | disposition | commit / test | reply |
Self-review re-run: Fixed F · Open O · New N
Replies: $OUT/replies.md · Deferred: <titles>
```
