> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Review

## Contract

- Global review orchestration lives in `.agents/skills/deep-review/SKILL.md`. This file holds the reusable layering and routing contracts.
- Per-project review lenses and project-specific constraints belong in `<project>/docs/ai/review.md` as a delta. Point to this file rather than restating global contracts.
- Before raising a finding, check whether the project's AGENTS.md or CLAUDE.md explicitly de-scopes the area. Capabilities the project has deferred (e.g. "No ARIA/screen reader work yet", "no i18n", "desktop-only") are inadmissible findings. Project exclusion rules have the same authority as inclusion rules.
- Review finding severity follows project-declared scope, not industry defaults.

## Layers

| Layer | Location | Purpose |
|---|---|---|
| Review orchestration | `.agents/skills/deep-review/SKILL.md` | How to run multi-pass review |
| Global review contracts | `docs/ai/review.md` (this file) | Layering, routing, and scope rules |
| Project review deltas | `<project>/docs/ai/review.md` | Project-specific lenses only; links here |

## Bug Learning Routing

After any review that confirms a real bug fix:

1. **Fix** using bugfix-tdd (failing test first, then fix, then verify).
2. **Learn**: invoke `/learn` to capture the bug class and prevention artifact.
3. The review thread records the incident; `docs/learnings/` holds the durable pattern.

One source of truth per bug class. Do not maintain separate fixed-bug logs outside the learning system.

## Notes

- An agent reviewing code shares context with the agent that wrote it; rule compliance audits must re-read project rules fresh rather than relying on recall.
- Orchestration skills describe how to run a workflow; global docs hold reusable contracts; project docs hold only project-specific deltas.
