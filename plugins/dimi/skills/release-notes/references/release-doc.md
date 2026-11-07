# The Word release document

One `.docx` per release, sent to customers and their administrators, about the feature the release delivers. It is a deliverable, not part of the docs site: it is written outside the repository and never committed. It follows the same writing standard (`style.md`) and the same "nothing internal" rule as the docs; the build gates it with the same checks.

## How it is built

The source is Markdown with front matter, written by the skill; `scripts/release-doc.sh` turns it into Word:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/release-doc.sh '<source .md>' '<output .docx>' '<template .docx or empty>' '<ticket_regex>' '<deny regex or empty>'
```
It copies the source and its screenshots into a build folder beside the output, tags the screenshots with a print resolution (so Word shows every one at 80% of its on-screen size, one consistent scale), keeps each step on the same page as its screenshot, gates that copy, converts it with pandoc (2.11 or later) using the template, gives every picture a thin border, checks that every image made it in, and, when LibreOffice is installed, renders page previews into the build folder. It refuses an output path inside the repository. Without pandoc it stops with the install command for each platform; the Markdown source is still there to convert later.

- **Template**: the repo's own Word template when the `release_doc_template` option names one (its styles, fonts, colours, header and footer win), else the plugin's `release-doc/reference.docx`: Calibri at 11 pt on one-inch margins, a left-aligned cover under an accent rule with no page number, section headings with a hairline under them, a contents column without bullets, figures with space above and a caption kept with them, a padded "action required" box, tables with a shaded header row and roomy cells, and "Page X of Y" in the footer from page 2. A company template only needs these styles to look right: Title, Subtitle, Date, Abstract, Heading 1 to 3, Body Text, First Paragraph, Compact, Contents Entry, Block Text, Captioned Figure, Image Caption, Table, Hyperlink, Footer.
- **Contents**: a heading marked `{.contents}` and a list of links under it, which the build turns into a quiet column of links, not a Word contents field. A contents field makes Word ask to "update the fields in this document" when it opens, which reads as a broken file to a customer.
- **Screenshots**: the ones the release run captured for its docs pages, referenced by their path in the published `img/` folder. A step screenshot sits indented under its step, as on a docs page; its alt text becomes the caption.

## The source

The document is about the feature the release delivers, usually the one a ticket built. The body explains that feature completely, so a customer can understand it and use it from the document alone. Everything else the release contains (other improvements, fixes, setting changes, deprecations) is reference material in an appendix that starts on its own page, and the appendix is left out when there is nothing to put in it. When a release delivers two or three features, each gets its own section in the body, in order of importance.

```markdown
---
title: "<Feature, as the user would name it>"
subtitle: "<Product> <version> · Release notes"
date: "<release date as the locale writes it>"
abstract: "<two sentences: what the reader can now do and why it matters; one more if anything needs action, with the date>"
description: "<Feature> in <Product> <version>: what it does, who can use it and how."
---

# Contents {.contents}

- [Summary](#summary)
- [Action required](#action-required)
- [<Feature>](#feature-anchor)
- [Availability and support](#availability-and-support)
- [Appendix](#appendix)

# Summary

<Two or three sentences: the problem the feature solves for the reader, what they can do now, and when it is available.>

# Action required

> **<Who>, before <date>:** <what to do, with the exact labels and path>. <What happens if they do not.>

# <Feature, as the user would name it>

<What it is and why it matters, in two or three sentences, in the reader's terms.>

## Who can use it

<Roles and plans, by their product names.>

## Before you begin

- <Setup, data or permission the reader needs first.>

## How to use it

1. <Step, location first, labels in bold.>

   ![<What the picture shows.>](/<repo>/<published docs>/img/<module>/<scene id>.png)

2. <Step.>

<The result: what the reader sees and where it lives.>

## Settings

| Setting | What it does | Default | Who can change it |
| --- | --- | --- | --- |
| **<label>** | <effect> | <default> | <role> |

## Good to know

- <A limit the reader can reach and what happens at it.>
- <What the feature does not do, and the workaround.>

<If the docs site is public: "Read more in [<page title>](https://docs.example.com/<page>)".>

# Availability and support

<Plans and regions it is available on, rollout dates, and how to get help.>

# Appendix {.newpage}

Everything else in <Product> <version>.

## Other improvements

- <Effect, in the reader's terms.>

## Fixes

- <The problem the reader saw> no longer happens.

## Other setting and permission changes

| Setting | What changed | Default | Who can change it |
| --- | --- | --- | --- |

## Deprecated and removed

- <Feature> is deprecated and will be removed on <date>. Use <replacement> instead.

## Known limitations

- <Limitation as the user meets it, and the workaround.>
```
Leave out any section with nothing in it, and its line in Contents. **Action required** stays in the body, never in the appendix: it is the one thing a reader must not miss. Leave the whole appendix out when nothing else shipped. A heading's anchor is its text in lower case with spaces as hyphens (`# Bulk export` → `#bulk-export`).

## Rules specific to the document

- Links only to `https://` pages or to `#sections` of the document itself. A relative link to a docs page works on the website and is dead in Word; the build refuses it.
- Every new feature gets its steps and screenshots here, even when the docs site has the same task: the document has to stand on its own for a reader who never opens the site.
- No PR, ticket or commit references, as on the site; the trace in the tools folder carries them.
- The file name is the product, the version and the feature (`<Product> <version> - <Feature>.docx`), the way a customer will find it in their downloads.
- The body is the feature: never pad it with the appendix's items, and never move the action required into the appendix.
- Page through the previews (or the document in Word) before handing it over: the cover, every screenshot with its caption, the action box, the tables, the page numbers.
