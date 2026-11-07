---
name: prose
description: House rules for the text dimi writes for people — PR descriptions, commit bodies, release notes, reports, walkthroughs, review findings, replies to reviewers — so it reads as a careful engineer wrote it, not a model: one idea per sentence, the actor named, no hedging stacks, no filler, no decorative structure. Background knowledge; loaded when writing or editing prose a reader will keep.
user-invocable: false
---

# Prose rules

The reader is busy, knows the domain, and did not watch the work. Every sentence must earn its place.

**Say the thing.** Lead with the outcome or the answer. State facts and decisions; do not narrate the process that found them. No "it is worth noting", "importantly", "in order to", "due to the fact that". No closing summary that restates the body.

**One idea per sentence**, with a verb and an actor. "The job retries on timeout" beats "retries are performed". Split a sentence that holds two ideas; cut a clause that adds none. Spell out articles and verbs that terse notes drop.

**Plain words.** Use, help, show, start, stop. Not utilise, leverage, facilitate, delve, robust, seamless, pivotal, holistic. No abstract nouns standing in for a mechanism (paradigm, substrate, north star, flywheel). Name the mechanism or the number instead of a feeling ("the import takes 15 minutes at 2,000 workbooks", not "the import is quite slow").

**No manufactured contrast or rhythm.** No "not X, but Y". No lists padded or trimmed to three. No colon as a mid-sentence connector before a reveal. No synonym cycling: pick one term for one thing and repeat it.

**Hedge once, where it is true.** "May" or "probably", once, when the uncertainty is real and named. Not "might potentially possibly". Mark the unverified as unverified; do not soften a Blocker into a suggestion.

**Punctuation and layout.** Sentence case headings. No em dashes or en dashes as asides; use a comma or a full stop. No decorative bold on every noun; bold at most the first words of a bullet. No emoji. Straight quotes. A bullet list only for parallel items, one or two sentences each; a single point stays in prose. Headers only when the text is long enough to need navigation.

**Numbers and names.** Expand an acronym the first time. A figure that changes what the reader does goes on its own line or in a small table; a figure that does not is cut. Code identifiers only when the reader must go there, in backticks, at most one per sentence.

**No model voice.** No "Certainly", "Great question", "I hope this helps", no apologies, no asides about one's own reasoning. A finding states what the code does, what happens, and the fix.

**Check**: read the draft once as the recipient. Cut what you would skim.
