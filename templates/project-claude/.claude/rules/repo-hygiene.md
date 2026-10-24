# Repo hygiene (applies everywhere; keep this file under 15 lines)

- Stage explicit paths. Never `git add -A`, `git add .` or `-u`; stray evidence, scratch files and `.env` files ride along otherwise.
- Commit as `type(KEY): description`, one logical change per commit, refactor before behaviour.
- No customer names, customer workbook content, POC ticket ids or real-looking organisations anywhere — code, fixtures, comments, keys. Merged history is permanent.
- No `as any`, `@ts-ignore`, `eslint-disable`, `# type: ignore` or a skipped test to get past a check. Fix the cause; if an exception is unavoidable, justify it on the same line.
- Nothing ships without a consumer: no tool, route, setting, constant or module that nothing in this change uses.
- Comments explain *why* — a decision, an invariant, a workaround with its upstream link. Never *what happened or for whom*: no ticket keys, customer or person names, dates, plan steps or session narrative in code, docstrings, log strings or test names. The commit message and PR carry that. No commented-out code; no docstring that restates the signature.
- Two implementations of one rule or metric is a bug. Find the canonical one (most callers, tested) and use it; extract shared plumbing before writing a third copy.
