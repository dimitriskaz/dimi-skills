---
name: tidy
description: Clean working notes out of a change before handover — session narrative in comments, ticket and customer references in code, what-comments that restate the code, commented-out code, debug leftovers, placeholder docstrings, scratch files — keeping only comments that explain why. Proves the result is comment-only (no behaviour change). Run before pr-self-review or commit-push-pr.
argument-hint: "[paths, or nothing = whole working tree change]"
disable-model-invocation: true
---

# Tidy: remove the scaffolding, keep the load-bearing comments

While working, Claude leaves itself breadcrumbs: `// added for PROJ-123`, `# per the customer's workbook`, `// step 3 of the plan: wire the route`, `// TODO for now`, a docstring that restates the signature, a block of commented-out code "in case". They help during the ticket and are wrong at handover: they narrate a session nobody else was in, pin ticket and customer context into code where the commit message and PR carry it, and bury the few comments that matter. This skill removes the scaffolding and keeps the load-bearing comments.

Triggers: `/dimi:tidy`, "clean up the comments", "remove the working notes", "make this handover-ready". `pr-self-review` flags the need; `commit-push-pr` refuses the serious cases; this skill fixes them.

## 0. Scope

Only lines **this change added or modified** (the working tree against the default branch, including untracked files), never the rest of the file — pre-existing comments are a separate conversation. Resolve the options first (they are substituted only in this file), then build the diff with §1 of `${CLAUDE_PLUGIN_ROOT}/skills/pr-self-review/references/diff-and-policy.md` (`$OUT` is the session's scratchpad directory if it gives one — set `OUT=<scratchpad path>` before the lines below — else `$TOP/../tidy-<repo>/` next to the checkout, absolute; `$DIFF=$OUT/review.diff`); work from its `+` lines. `$ARGUMENTS` narrows to paths.
```bash
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository" >&2; exit 1; }
REPO=$(basename "$TOP"); OUT=${OUT:-$TOP/../tidy-$REPO}
DB='${user_config.default_branch}'; case "$DB" in '$'*) DB='';; esac; [ -z "$DB" ] && DB=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); DB=${DB:-main}
```

Read `.claude/rules/repo-hygiene.md` and `CLAUDE.md` for the repo's comment conventions (docstring style, whether `TODO(KEY)` is allowed). If `.claude/fde-client-profile.md` exists, its client name is a term to remove.

## 1. Inventory

Collect every added/changed instance of:
- comments and docstrings (`//`, `/* */`, `#`, `"""`, `'''`, JSDoc, `<!-- -->`, YAML `#`);
- string literals in logs, errors and test names (`describe`, `it`, `test(`), fixture names and identifiers that carry a ticket key, a customer, a person, or a date;
- files that are working artefacts, not product: `PLAN.md`, `HANDOFF.md`, `NOTES.md`, `TODO.md`, `*.scratch.*`, review reports, exported chats, screenshots not under the repo's evidence convention; `.claude/.cache/` (the hooks' cache dir) and Playwright auth state (`storageState`, `.auth/`) are never staged either.

Quick greps over the `+` lines (confirm each by reading; `TICKET_REGEX` and `CUSTOMER_TERMS` come from the Repo policy block in the file above):
```bash
grep -nE '^\+.*(//|#|/\*|\*|"""|<!--)' $DIFF | grep -niE "(<TICKET_REGEX>|<CUSTOMER_TERMS>|as discussed|per the (ticket|workbook|customer|call|review)|for now|temporary|hack|quick fix|claude|assistant|session|step [0-9]|plan\.md|handoff|added (as part of|for|in)|updated (on|to)|changed (to|from)|20[0-9]{2}-[0-9]{2}-[0-9]{2}|see (above|below)|this (function|method|class|file) (does|is|handles|returns))"
grep -nE '^\+\s*(//|#)\s*(const|let|var|def |class |if \(|for \(|return |import |export |[a-zA-Z_]+\(.*\);?\s*$)' $DIFF   # commented-out code
grep -nE '^\+.*(console\.(log|debug)|print\(|logger\.debug|debugger|DBG-[A-Za-z0-9_-]+|TODO|FIXME|XXX)' $DIFF   # DBG- probes are what the Stop hook blocks
git -C "$TOP" ls-files --others --exclude-standard | grep -iE '(plan|handoff|notes|todo|scratch|review|report|transcript)\.(md|txt)$|^\.claude/\.cache/|storageState|\.auth/'
```

## 2. Classify every item into exactly one bucket

| Bucket | Test | Action |
|---|---|---|
| **Keep** | Explains *why*: a non-obvious decision, an invariant, a constraint from outside the code, a workaround with the upstream issue URL, a public API contract, a licence header | Leave as is |
| **Rewrite** | Contains a real *why* wrapped in narrative or context ("added for PROJ-123 because the import must not overwrite filled fields" → "Never overwrite a filled field on import; enrichment only.") | Keep the why in one sentence, drop the who/when/which-ticket |
| **Delete — narrative** | Describes the session, the plan, the ticket, the customer, the reviewer, or what was done when ("step 3", "as discussed", "per the review", "Claude added", dates) | Remove the comment. The commit message and PR carry this |
| **Delete — what-comment** | Restates the code or the signature ("increment the counter", "returns the user", "this function handles X") | Remove |
| **Delete — commented-out code** | Code behind a comment marker, including "in case we need it" | Remove; git history has it |
| **Delete — debug** | `console.log`/`print` added for the session, `debugger`, trace prints | Remove (the Stop hook already blocks some of these) |
| **Delete — placeholder docstring** | Docstring that adds no information beyond the name and types | Remove, or write the real one if the symbol is public |
| **Resolve — TODO/FIXME** | A deferred item | If the repo allows `TODO(KEY)`: keep only with a real ticket key and one line; else move to the PR's Deferred section and delete. Never "TODO for now" |
| **Rename** | Identifier, test name, fixture or log string carrying a ticket key, a customer or a person | Rename to what it *is* (`acmeImport` → `spreadsheetImport`; `it('PROJ-123 regression')` → `it('re-import does not duplicate trimmed ids')`) |
| **Untrack** | Working-artefact files inside the repo | Move outside the repo (`$OUT`) or delete; never stage |

Bias: when in doubt between Keep and Delete, ask "would a teammate who has never seen the ticket need this to understand the code?" If not, delete. A file with no comments is not a problem; a file with twelve narrative ones is.

Do not touch: comments that pre-date the change; licence headers; generated files; comments the repo's conventions require (e.g. ESLint directives with their justification — though an unjustified `eslint-disable` is a `pr-self-review` finding, not a tidy item).

## 3. Apply

- Make the edits file by file. Keep the diff minimal: remove whole comment lines rather than leaving blank gaps; collapse double blank lines that result.
- Renames go through the editor's rename or a scoped search-and-replace with a review of each hit; never a blind global replace.
- Deleting commented-out code must not leave a dangling reference; deleting a docstring must not break a doc build that requires one (check the repo's lint rules).

## 4. Prove it changed nothing but comments

The tidy must not change behaviour. Verify:
1. `git diff` of the tidy edits: every removed or changed line is a comment, docstring, blank line, log string, test name, identifier rename or untracked file. Anything else is listed under "needs a look" and either reverted or justified.
2. Run the narrowest checks for the touched packages: typecheck (renames), the touched test files (test-name changes), lint (docstring rules). One command at a time.
3. If a rename touched more than the change's own files, say so — that is scope creep and belongs in its own commit.

## 5. Report

```
## Tidy — <branch>
Inventory: N comments · M strings/identifiers · K scratch files
| item | file:line | bucket | action |
Kept (why-comments): …
Rewritten: …   Deleted: …   Renamed: …   Untracked/moved: …
Behaviour-only check: typecheck ✓ · touched tests ✓ · diff is comment-only ✓ | needs a look: …
```

Then offer: fold the tidy into the relevant commits (preferred — a reviewer should never see the scaffolding), but only while those commits are unpushed; otherwise commit separately as `chore(KEY): remove working notes` (rewriting pushed history needs a force-push, which the Bash guard blocks). If a deleted TODO or narrative held a real deferred item, add it to the PR's Deferred section in `commit-push-pr`.

## 6. Compound

If the same kind of scaffolding keeps appearing, the fix is upstream: a line in `.claude/rules/repo-hygiene.md` (already there by default: comments explain why, never ticket, customer or session narrative) and, for the agents, the house rules in `implementer` and `spec-writer`. `/dimi:compound` is where that adjustment lives.
