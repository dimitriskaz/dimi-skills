# Page templates, front matter and framework syntax

As of 2026-11. The callout and navigation syntax below is each framework's own and changes between major versions: confirm it against the version in the repo's `package.json` or `requirements` before writing the first page.

## Front matter

Every page starts with front matter; the gate fails a page without `title` and `description`.

```yaml
---
title: Import a spreadsheet
description: Bring a workbook into your workspace and keep the links between its sheets.
---
```
Add the framework's own fields where the repo already uses them (`sidebar_position` in Docusaurus, `icon` in Mintlify, `sidebar.order` in Starlight). The `description` is the search snippet: one sentence on what the page lets the reader do.

## Templates

### index.md: the product overview

```markdown
---
title: <Product> documentation
description: Learn how to <the product's one job> with <Product>.
---

# <Product> documentation

<Two sentences: what the product does and for whom.>

## Start here

- [Get started](getting-started/index.md): sign in, set up your workspace and complete a first <task>.
- [Key concepts](getting-started/concepts.md): the few terms the rest of the docs use.

## What you can do

| Area | What it is for |
| --- | --- |
| [Imports](imports/index.md) | Bring spreadsheets in and keep the links between sheets. |

## Reference

[Roles and permissions](reference/roles-and-permissions.md) · [Settings](reference/settings.md) · [Limits](reference/limits.md) · [Glossary](reference/glossary.md) · [Troubleshooting](troubleshooting.md) · [Release notes](release-notes/index.md)
```

### <module>/index.md: concept page

```markdown
---
title: Imports
description: What imports do, the terms they use and who can run them.
---

# Imports

<What the module is for, in two or three sentences: the problem it solves for the reader.>

## How it works

<The model the reader needs, in plain words: what goes in, what comes out, what is kept. One diagram or screenshot if it helps.>

## Terms

- **Link**: <definition as the product uses it>.

## Who can use it

<Roles, as on the roles page.>

## Tasks

- [Import a spreadsheet](import-a-spreadsheet.md)
```

### <module>/<task>.md: task page

```markdown
---
title: Import a spreadsheet
description: Bring a workbook into your workspace and keep the links between its sheets.
---

# Import a spreadsheet

Import a workbook when you want its sheets as tables, with the lookups between sheets kept as links.

## Before you begin

- You need the **Editor** role or higher.
- The workbook is an `.xlsx` or `.csv` file of up to 50 MB.

## Steps

1. In the left menu, select **Imports**.

   ![The Imports page with the New import panel.](../img/imports/imports-01-open.png)

2. Select **Upload**, then choose the workbook.

   ![The New import panel with the Upload button outlined.](../img/imports/imports-02-upload.png)

3. Check the preview. It lists each column and shows which ones become links.

   ![The preview, listing the columns that become links.](../img/imports/imports-03-preview.png)

4. Select **Import**.

The workbook appears in **Imports** with the status **Complete**.

## Related

- [Import limits](../reference/limits.md)
- [Fix a failed import](../troubleshooting.md#the-file-could-not-be-read)
```
Images in a numbered step are indented under it (three spaces) so the list numbering continues.

### reference/roles-and-permissions.md

```markdown
| Action | Viewer | Editor | Admin |
| --- | --- | --- | --- |
| View imports | Yes | Yes | Yes |
| Run an import | No | Yes | Yes |
| Delete an import | No | No | Yes |
```

### reference/settings.md

```markdown
| Setting | What it does | Default | Who can change it |
| --- | --- | --- | --- |
| **Keep links on import** | Turns lookups between sheets into links. | On | Admin |
```

### reference/limits.md

```markdown
| Limit | Value | What happens at the limit |
| --- | --- | --- |
| Workbook size | 50 MB | The upload is refused with **File too large**. |
```

### troubleshooting.md: one entry per message

```markdown
## The file could not be read

**What you see**: **The file could not be read.** under the upload panel.

**Why it happens**: the workbook is password-protected or not a real `.xlsx` file.

**What to do**: remove the password in your spreadsheet app, save the file as `.xlsx`, and upload it again. If the message stays, contact <support contact>.
```
The heading is the message as the product shows it, so a reader searching for the text finds the entry.

### release-notes/<version>.md

```markdown
---
title: <Product> <version>
description: What is new, improved and fixed in <Product> <version>, released <date>.
---

# <Product> <version>

Released <date>.

<Two sentences: the headline change and who benefits.>

## New

- You can now <effect>. [Learn how](../imports/import-a-spreadsheet.md).

## Improved

- <Effect>.

## Fixed

- <The problem the user saw> no longer happens.

## Breaking changes

- **Who is affected**: <who>. **What to do**: <steps in order>, before <date>.

## Deprecated and removed

- <Feature> is deprecated and will be removed on <date>. Use <replacement> instead.

## Known limitations

- <Limitation, as the user meets it, and the workaround if there is one>.
```
Leave out empty sections. Keep a `release-notes/index.md` listing every version, newest first.

## Callouts by framework

| Framework | Note | Tip | Important | Warning |
| --- | --- | --- | --- | --- |
| Plain Markdown on GitHub | `> [!NOTE]` | `> [!TIP]` | `> [!IMPORTANT]` | `> [!WARNING]` |
| Docusaurus | `:::note` … `:::` | `:::tip` | `:::info` | `:::warning` (data loss: `:::danger`) |
| MkDocs Material | `!!! note` | `!!! tip` | `!!! info` | `!!! warning` (data loss: `!!! danger`) |
| Mintlify | `<Note>` … `</Note>` | `<Tip>` | `<Info>` | `<Warning>` |
| Starlight | `:::note` … `:::` | `:::tip` | `:::note[Important]` | `:::caution` (data loss: `:::danger`) |
| VitePress | `::: info` … `:::` | `::: tip` | `::: info` | `::: warning` (data loss: `::: danger`) |
| Nextra | `<Callout>` | `<Callout type="info">` | `<Callout type="info">` | `<Callout type="warning">` (data loss: `type="error"`) |

## Navigation by framework

| Framework | Where the page order lives |
| --- | --- |
| Plain Markdown | the links in `index.md` and each module's `index.md` |
| Docusaurus | `sidebars.js` or `_category_.json` per folder, `sidebar_position` per page |
| MkDocs | `nav:` in `mkdocs.yml` |
| Mintlify | `navigation` in `docs.json` (`mint.json` in older projects) |
| Starlight | `sidebar` in `astro.config.mjs`, or `sidebar.order` per page |
| VitePress | `themeConfig.sidebar` in `.vitepress/config` |
| Nextra | `_meta.json` (or `_meta.ts`) per folder |

When a page moves or is deleted, add a redirect where the framework has one (Docusaurus client-redirects plugin, MkDocs redirects plugin, Mintlify `redirects` in `docs.json`), so links from support tickets and search results keep working.

## Links and images

- Links between pages are relative (`../reference/limits.md`), with anchors from the heading text.
- Images live under `PUB/img/<module>/` and are referenced relatively from the page. Some frameworks serve images from a static folder instead (Docusaurus `static/`, Mintlify a top-level `images/`): if the repo already does that, follow it and set `imageRoot` in `scenes.json` to match.
