# Writing standard for public product documentation

Every page in the published folder, and the Word release document, follows this. The reader is a customer, an administrator or an evaluator who knows their own job and has never seen the code. They arrive from a search with a task in mind and leave as soon as it is done.

## Voice

- Second person, present tense, active voice. Steps are imperative: "Select **Upload**", not "The user can click Upload".
- Plain words, one idea per sentence, short paragraphs. The house prose rules in `${CLAUDE_PLUGIN_ROOT}/skills/prose/SKILL.md` apply.
- No marketing ("powerful", "seamless", "best-in-class"), no filler ("simply", "just", "easily", "obviously", "please note"), no humour, no exclamation marks, no promises about the future except dated deprecations in release notes.
- Sentence case for every heading and title.
- Say what the product does, not how it is built. "Imports keep the links between sheets", never "the parser records relations in a join table".

## The product's own words

- **UI labels exactly as on screen**, in bold: **New import**, **Save changes**. Take them from the screen or the locale files, never from a component or route name. When a label changes in the product, it changes in the docs in the same release.
- **Navigation** as a path of bold labels: "Go to **Settings** > **Members**."
- **Text the user types** in backticks: enter `Q1 budget`. Keys in `<kbd>`: <kbd>Ctrl</kbd>+<kbd>K</kbd>.
- **Verbs that work on any device**: select (a button, a menu item, a tab), choose (from a list), enter (text), turn on and turn off (a toggle), open, close, go to, drag. Not click, tap or hit.
- **One term for one thing.** If the screen says "workspace", the docs never say "tenant", "org" or "account" for it. Every product term the reader needs is in the glossary, defined as the product uses it.
- **Roles and plans by their product names**, exactly as the product shows them.

## Task pages

- Title: a verb and the object, in the user's terms. "Import a spreadsheet", "Invite a member", "Export an audit log". Not "Using imports" or "Import feature".
- First paragraph: what the task achieves and when to do it, in one or two sentences.
- **Before you begin**: the role needed, the plan or licence if the feature depends on one, and the data or setup that must exist. Omit the section only when nothing is needed.
- **Steps**:
  - Numbered, one action per step, three to ten steps. More than ten: split the task.
  - Location first, then the action: "In **Imports**, select **New import**."
  - A condition starts the step: "If the workbook has more than one sheet, choose the sheet to import."
  - An optional step says so first: "Optional: …".
  - The result of a step is a plain sentence after it, not a numbered step: "The preview lists each column."
  - Never more than one way to do the same thing in the main steps. A faster way goes in a Tip.
- **Result**: what the reader sees when the task is done and where the result lives.
- **Related**: two to four links to the next likely tasks or the concept page.

## Concept and reference pages

- A concept page explains what a module is for, the few terms it introduces, who can use it and what it does not do. It links to its task pages. No steps.
- A reference page is a table the reader scans: settings (what it does, default, who can change it), roles and permissions (action by role), limits (the limit, what happens when it is reached, whether it can be raised).
- Limits and defaults are written as the user meets them: "A workbook can be up to 50 MB. A larger file is refused with **File too large**."

## Screenshots in the text

- A screenshot sits under the step it illustrates, introduced by that step, never by "the screenshot below shows".
- One where the screen changes in a way the reader needs to see. The first step of a task shows where in the product it starts; the last shows the result. Not every step needs one.
- Alt text describes what the picture shows and its state, in a sentence: "The New import panel with a workbook selected." Never "screenshot", "image" or a file name.
- An instruction never lives only in a picture: the step's text says everything.
- A screenshot never shows something the text tells the reader not to do, an internal screen, or a role the page is not about.

## Callouts

| Callout | Use for |
| --- | --- |
| Note | a useful aside the task does not depend on |
| Tip | a faster or better way |
| Important | something the reader must do or know to succeed |
| Warning | data loss, something that cannot be undone, a security or billing consequence |

At most one per section, never two in a row. The syntax for each framework is in `pages.md`.

## Numbers, dates and units

- Numerals for counts and measurements; a space before units ("50 MB", "10,000 rows").
- Dates as the docs' locale writes them, unambiguous (en-US: "March 2, 2026"). Times with their time zone.
- No precision the reader cannot use: "about 15 minutes for 2,000 imports", not "14.7 minutes".

## Accessibility

- Every image has alt text; decorative images do not belong on the page.
- Never refer to colour or position alone: "select **Delete**", not "select the red button on the right".
- Link text names the destination: "see [Import limits](../reference/limits.md)", never "click here".
- Tables have a header row; no table is used for layout.

## Release notes

- Written for the customer: what they can do now, what changed for them, and what they must do.
- Each item leads with the effect: "You can now import workbooks with links between sheets." "Exports no longer stop at 10,000 rows."
- A fix describes the problem the user saw, not the cause in the code.
- Breaking changes say who is affected, what to do, in order, and by when.
- Deprecations give the date and the replacement.
- Each item links to the page that documents it.

## Never in the published folder

The gate (`docs-check.sh`) fails a page on most of these; the rest are on the writer:
- file paths, code identifiers, function, component, table or column names, API internals
- PR, issue or ticket numbers, commit hashes, branch names
- environment names and hosts (staging, preview, localhost), feature-flag keys, environment variables
- internal codenames, team, squad or employee names, Slack channels
- test data labels ("Test Tenant 3", "foo", "lorem ipsum"), working markers (TODO, FIXME, DEMO-ONLY)
- anything the client profile forbids, real customer names or data, personal data in text or images
- unreleased features, roadmap promises, internal reasons for a decision

## Weak and strong

| Weak | Strong |
| --- | --- |
| Using the Imports feature | Import a spreadsheet |
| Click the Upload button in the ImportPanel component. | Select **Upload**. |
| Simply drag your file and you're done! | Drag the workbook onto the panel. |
| The tenant admin can configure this (see #412). | You need the **Admin** role. |
| Fixed a race in the relation upsert. | Importing the same workbook twice no longer creates duplicate links. |
| ![screenshot](img/a.png) | ![The preview, listing the columns that become links.](img/imports/imports-03-preview.png) |
| Coming soon: bulk imports. | (nothing until it ships) |
