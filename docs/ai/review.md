> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Code Review

## Contract

- Orchestration skills (e.g. `deep-review`) say how to run a review workflow. This doc holds reusable review contracts that apply across projects.
- Global review contracts live here. A project's `docs/ai/review.md` holds only project-specific deltas and links here; do not restate a global contract in a per-project doc.
- Findings that target capabilities the project's AGENTS.md explicitly de-scopes are inadmissible. Before raising a finding, check whether AGENTS.md says "No X yet" or "X is not needed" for the area being reviewed. The same rule that says "violations of project rules are major findings" must also say "exclusions in project rules trump default-convention findings."
- When a bug fix surfaces a reusable bug class, route the learning in order: fixed incident log → lessons-learned entry (root cause, principle, anti-pattern, enforcement candidate) → promotion to `docs/ai/`, regression tests, lint rules, or architecture constraints when the class recurs or has high blast radius.
- Bug-learning artifacts form an abstraction ladder — symptom → bug class → shared contract violation → enforcement. Do not let separate incident logs, lessons files, and pattern cards become competing ledgers for the same class.
- A fixed bug is only fully learned when the bug class leaves behind a mechanical or documented guardrail that makes the next similar mistake harder to write.

## Notes

- **Where review guidance lives:**

  | Scope | Location |
  |---|---|
  | Review workflow orchestration | `.agents/skills/deep-review/SKILL.md` |
  | Reusable review contracts (this file) | `~/dotfiles/docs/ai/review.md` |
  | Project-specific review rules and lenses | `<project>/docs/ai/review.md` (delta only) |

- Bug learning that generalizes across projects belongs in `docs/ai/` or in the learning system; project-local shakedown logs and lessons files should stay project-local until the class is confirmed cross-project.
