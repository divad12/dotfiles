> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Review Contracts

Read this when writing per-project review guidelines, or when routing bug-fix learnings after a fix.

## Contract

### Layering

| Layer | Purpose |
|---|---|
| `.agents/skills/deep-review/SKILL.md` | Orchestration: how to run a multi-pass review |
| `~/dotfiles/docs/ai/review.md` (this file) | Reusable contracts: scope, finding categories, bug-learning routing |
| `<project>/docs/ai/review.md` | Project-specific deltas only |

Do not restate global contracts in per-project review docs. Link here and add only what differs: extra reviewers, excluded concerns, project-rule exceptions (e.g., "No ARIA work yet", "desktop-only: skip mobile viewports").

### Exclusion symmetry

If a review rule says "violations of project rules are findings", its mirror must also hold: **capabilities the project explicitly de-scoped are not findings**. Before raising a finding, check whether the project's AGENTS.md or docs has a "No X yet" or "X is not needed" clause for the area being reviewed. De-scoped concerns are inadmissible as findings.

### Bug-learning routing

After any bug fix, route the learning through this ladder:

1. **Incident** — what happened, file:line, when.
2. **Lesson** — root cause, principle, anti-pattern.
3. **Bug pattern** — class of bug, enforcement candidate (test, lint, shared helper, `docs/ai/` contract).
4. **Enforcement hook** — when the class repeats or has high blast radius: add a regression test, lint rule, shared factory, or `docs/ai/` entry that makes the next instance harder to write.

Bug-learning files are a ladder, not competing ledgers. One entry per bug class; update evidence, confidence, and enforcement status as the class recurs.

## Notes

- The deep-review skill says *how* to run a review; this doc says *what contracts* those runs enforce.
- A finding the project explicitly de-scoped is not a valid finding, even if it would be valid by default conventions.
- When per-project review guidance has stabilized, extract the reusable contracts into this file and keep the per-project doc as a delta pointer.
