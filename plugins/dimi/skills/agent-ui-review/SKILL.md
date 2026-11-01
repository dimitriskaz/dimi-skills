---
name: "agent-ui-review"
description: "Review a chat, copilot or agent screen for every state the conversation can be in — streaming, stalled, disconnected mid-answer, stopped by the user, tool calls in flight, approval gates for writes, budget and context limits hit, retrieval that found nothing vs retrieval that failed, citations, the audit trail of what the agent did and what can be undone — plus the prompt-injection rules that apply to rendering model output, and the Playwright specs those states need. Use before committing a model-backed screen (one that renders a model's stream, shows an agent's tool calls or asks a person to approve an action the agent proposed), or when pr-self-review meets one in a diff."
when_to_use: "Triggers: /dimi:agent-ui-review, \"review the chat UI\", \"check the agent screen\", \"is the copilot panel ready\", \"UX pass on the assistant\", \"what happens if the stream drops\", \"review the approval dialog\". Screens without a model behind them, including live dashboards on a WebSocket → ui-states-review only."
argument-hint: "[component or page paths]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*) Bash(grep *)
---

# Agent UI review

`ui-states-review` covers what a screen does when a request loads, fails or is forbidden. A screen with a model behind it has states that review does not know: an answer that is half written when the connection drops, a tool call that has run for forty seconds, a proposal waiting for someone to approve it, a budget that ran out before the task finished, a source that was never read. This skill names those states, checks each is handled and truthful, and lists the specs that pin them. Run `ui-states-review` as well for the ordinary parts of the same screen (lists, forms, permissions); do not repeat its checks here.

For the backend side of the same mechanisms (budgets A1–A4, approvals B2–B5, egress D3–D4) the owner is `review-agent`; cite its check ids when a UI finding has a server-side twin, and report the defect once, where it should be fixed.

If the `design` plugin is installed: deep accessibility → `design:accessibility-review`; copy → `design:ux-copy`.

## 0. Inputs

- A diff or a list of components. For a diff, build it first (the session's scratchpad path in the second argument if it gives one, else `''`):
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh build agent-ui-review '' '${user_config.default_branch}' '${user_config.demo_marker}' '${user_config.demo_branch}' '${user_config.ticket_regex}' '${user_config.local_checks}'
  ```
  It prints the Review context (`Top`, `Out`, `Diff`, `Base`, `Head`, options); write those values literally into later commands — each Bash call is a fresh shell, and a command that expands a variable cannot be pre-approved.
- Read each changed component **and** the stream handler, store or hook it renders from: the states live in the stream reducer and the approval store, the symptoms in the component. Read the server handler that emits the stream too, far enough to know which event types exist; a state the server never sends cannot be rendered.
- `<Top>/.claude/fde-client-profile.md`, if present: its approval rules and data classes decide which writes need a gate and what may appear on screen.
- If a browser tool or Playwright is available and the app runs locally, drive the real screen through the states below with mocked stream events and take screenshots; otherwise reason from code and say so.

## 1. Inventory

For each changed conversation surface list:
- **Transport**: SSE, WebSocket, long poll or request/response; the event types it carries (token, tool call start/end, approval request, usage, error, done); what happens to the stream on reload.
- **Steps shown**: which model and tool steps the user can see, which are hidden, and what the hidden ones can do.
- **Approval points**: every write the agent can propose; which are reversible; who may approve; where the approval is enforced (client, server, harness).
- **Limits**: step cap, token or cost budget, context window and compaction, rate limits, per-tenant quotas, model and tool fallbacks.
- **Sources**: retrieval, web, files, connectors the answer may cite, and whether the citation resolves to something the user may open.
- **Actions taken**: what the agent can change in the world, and which of those the backend can undo.

## 2. Stream states

Fill this table for every conversation surface; a blank cell is a finding.

| State | What the user sees | Must never | Test exists? |
|---|---|---|---|
| Connecting | the request is acknowledged within a second (placeholder or indicator), input kept editable or clearly locked | a dead button; a second send that creates a second run | |
| Streaming | tokens appended in place; a Stop control reachable by mouse and keyboard; layout stable, no scroll fight when the user scrolls up | flicker on every token; focus stolen on each chunk | |
| Stalled (no event for N seconds) | a named "still working" or "taking longer than usual" state after a fixed threshold | silence until the timeout; a spinner forever | |
| Stopped by the user | the partial answer kept and marked as stopped; the server run cancelled, not just the subscription | the answer vanishing; the backend finishing and billing anyway | |
| Disconnected mid-answer | the partial answer kept and marked incomplete; reconnect or resume offered; on resume, continued from the last event, not replayed from the start | partial text shown as complete; the message duplicated on resume | |
| Error after partial output | the partial kept, the error named for that message, retry offered | the whole thread replaced by an error; the user's prompt lost | |
| Completed | the message marked final; usage or cost shown if the product shows it; actions enabled | "generating" indicator left on | |
| Regenerated | previous answer kept or replaced per a visible, deliberate choice; history still reads honestly | a silent overwrite the audit trail cannot explain | |
| Reload mid-run | the run still visible and resumable from the server's state | the run gone from the screen while the server keeps acting | |

## 3. Tool call and step states

| State | Expectation |
|---|---|
| Pending or running | the step is visible with what it is doing in words a user understands; elapsed time after a threshold; arguments shown are redacted per the data classes (no secrets, no other tenants' ids) |
| Succeeded | a result summary the user can expand; the raw result is content, not instructions (section 6) |
| Failed, retryable (timeout, 5xx, tool unavailable) | named per step; the agent's retry visible; the user can stop retries |
| Failed, permanent (403, validation, tool removed) | named; no retry button that can only fail again; the agent's recovery (ask the user, pick another path) visible |
| Cancelled | shown as cancelled with any side effect that already happened (B5) named, not hidden |
| Hidden steps | justified in the inventory; anything that writes or sends is never hidden |
| Parallel tool calls | each with its own state; one failure does not render the others as failed |

## 4. Approval gates

The backend rule (rubric B2) is that writes are human-accepted proposals. The UI is where that rule is kept or lost.

- **The proposal is the exact action**: tool name, arguments and target rendered in full (a diff for edits, the recipient and body for sends, the amount and account for payments). Never a one-line summary the model wrote about itself.
- **Bound to the call** (B3): accept applies to the hash of what was shown. If the agent regenerates arguments after approval, the UI shows a new proposal; it never reuses the earlier accept.
- **Reject with a reason**: the reason reaches the agent as its next input and the thread shows it; rejecting never executes a fallback.
- **Edit before accept** where the product allows; the edited arguments are what is shown and what runs.
- **No accidental accept**: initial focus is not on Accept; Enter does not accept a destructive proposal; batch approval is named as a batch and lists every item.
- **Expiry and timeout** are states: an expired proposal says so and asks again; a stale proposal cannot be accepted after the run moved on.
- **Permission to approve** is checked server-side; a user who may not approve sees a clear "needs approval from" state, not a disabled button that implies otherwise.
- **Record**: the thread keeps who approved, when and with which edits (the audit trail in section 7 reads from this).
- **Reversible writes without a gate** are only acceptable when the client profile allows it and a reviewed sample exists; otherwise a finding, cross-referenced to B2.

## 5. Limits and budgets

Each limit is a state of its own and must not look like a model error.

| Limit reached | What the user sees | Must never |
|---|---|---|
| Step or turn cap (A1) | "stopped after N steps" with the partial result and a way to continue or narrow the task | a generic error; silent stop with the last message looking final |
| Token, cost or time budget (A2) | the budget named; what was finished and what was not | the run continuing past the budget because the client did not know |
| Context truncated or compacted | a visible marker where history was summarised or dropped; earlier messages still readable | the agent "forgetting" with no cue |
| Rate limited or quota | the wait named and counted down where known; input kept | an error that invites an immediate retry that will also fail |
| Model unavailable or fallback | the fallback named if the product shows models; the answer attributed to the model that wrote it | an answer attributed to a model that did not produce it |
| Tool or connector unavailable (MCP server down) | the capability named as unavailable for this turn; the agent's path without it visible | a failed tool rendered as "no results" (section 6) |

## 6. Provenance, truthfulness and rendering

- **Unread is not empty, for retrieval too**: "I searched and found nothing" is only shown when the search ran and returned zero. A failed search, a forbidden source or a skipped tool renders as a named failure. The server must send distinct events for these; if it does not, the UI cannot be fixed alone (cite the server path).
- **Citations resolve**: each cited source opens to something the user may read, and the quoted span exists in it. Citations the model invented are not rendered as links. A number of sources shown is the number used, not the number retrieved.
- **No invented confidence**: confidence, scores or "verified" badges come from a computed signal with a definition, never from model text.
- **Model text is content, not markup**: rendered through a sanitising Markdown renderer; never `innerHTML` or `dangerouslySetInnerHTML` on model or tool output; raw HTML in output is escaped. Links from model or tool output are shown with their real destination and do not auto-open; images from untrusted content are not fetched (D3 — a fetched image URL is a data channel out). Tool results are shown as quoted content, labelled with their source (D4).
- **Actions the model describes are not actions taken**: "I have sent the email" renders as a claim unless a tool event confirms it; the UI shows the tool outcome, not the sentence.
- **Numbers the model computed are marked as model output**; numbers the product computed are not mixed in with them in the same style.
- **Personal data** in prompts, tool arguments and results is shown only to users entitled to see it, and masked in any shared or exported transcript.

## 7. Audit trail, history and undo

- **What the agent did this run** is listed in order: each tool call with target and outcome, each approval with approver, each file or record changed. Readable without expanding the whole thread.
- **Undo** is offered for every action the backend can compensate (B4), applies to that action only, and says what it cannot undo.
- **History persists**: threads survive reload and are attributed to the model and prompt version that produced them where the product shows that; a regenerated answer does not erase the record of the first.
- **Export or share** of a transcript goes through the same redaction as the screen, and never includes hidden steps' secrets.
- **Who did what**: user messages, agent actions and approvals are visually distinct and never attributed to the wrong party.

## 8. Input and conversation hygiene

- Send is disabled only while this thread is streaming; the user can stop and send a new prompt; a queued prompt is shown as queued.
- A draft survives an error and a reload. Attachments have their own states (uploading, scanned, rejected with the reason, too large).
- Editing an earlier message branches visibly or truncates visibly; it never rewrites history in place.
- Slash commands, mentions and tool pickers use constrained inputs; the user is never asked to type ids or JSON.
- Pasted content that looks like a secret is flagged before it is sent to a model, when the product has that rule.

## 9. Keyboard, focus and announcements (quick pass)

- Streaming text goes to a live region that announces when a message completes or stalls, not every token.
- Stop, Accept and Reject are reachable by keyboard; Escape stops a stream only if the partial is kept.
- Focus does not move while tokens arrive; after completion it moves to a sensible place (the message, or back to the input), not to nowhere.
- Reduced motion disables typing animations. Deep audit → `design:accessibility-review` (if installed).

## 10. Evidence

List the Playwright specs (or component tests with a mocked stream) that cover the risky rows — at minimum: disconnect mid-stream keeps the partial and marks it incomplete; Stop cancels the server run (assert the cancel request); an approval dialog shows the exact arguments and rejecting executes nothing; a regenerated proposal cannot reuse an earlier accept; the step cap renders as a named state with the partial result; a failed retrieval renders as a failure, not as "no results found"; model output containing HTML or a markdown image is rendered inert. Real auth and real model calls are never part of these specs; the stream is mocked event by event.

## Quick greps (read around every hit)
```bash
grep -nE '^\+.*(dangerouslySetInnerHTML|innerHTML|v-html|\[innerHTML\])' <Diff>           # model output rendered as markup?
grep -nE '^\+.*(EventSource|WebSocket|ReadableStream|getReader\(\)|text/event-stream)' <Diff>  # a stream: every row of section 2 applies
grep -nE '^\+.*(onerror|onclose|\.catch\(|AbortController|abort\(\))' <Diff>              # disconnect, stop and error handling present at all?
grep -nE '^\+.*(approv|confirm|proposal|needsApproval|requireApproval|interrupt)' <Diff>  # an approval gate: section 4 applies
grep -nE '^\+.*(No (results|sources|documents)|nothing found|found nothing)' <Diff>       # empty-retrieval copy: reachable on failure?
grep -nE '^\+.*(maxSteps|max_turns|budget|usage|tokens|rateLimit|429)' <Diff>              # a limit the UI must render as a state
grep -nE '^\+.*(<img|<a |href=|src=)' <Diff>                                              # links or images sourced from model or tool output?
grep -nE '^\+.*(autoFocus|onKeyDown.*Enter|type="submit")' <Diff>                         # accidental accept on a proposal?
grep -nE '^\+.*(confidence|score|verified)' <Diff>                                        # where does the signal come from?
grep -nE '^\+.*(aria-live|role="(log|status|alert)")' <Diff>                              # announcements: per completion, not per token
```

## Output

Per conversation surface: the inventory, the filled stream table and tool-call table with gaps marked, and the approval and limit checks with their status. Then findings in the `pr-self-review` interchange format (category `correctness` for state and truthfulness bugs, `security` for rendering, egress and approval-binding defects, `conventions` for inputs and focus), a `STRENGTHS:` list, and the list of specs to add. Title the defect, not the symptom ("Dropped stream renders partial answer as final", not "streaming bug"). Where a finding has a server-side twin, cite the `review-agent` check id and name the side that should carry the fix.
