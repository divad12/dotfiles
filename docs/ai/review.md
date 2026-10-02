> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Code Review

## Contract

- Review orchestration logic lives in `.agents/skills/deep-review/SKILL.md`. Load it for orchestration steps; do not restate them here.
- Global review principles apply across all projects. Per-project `docs/ai/review.md` adds only project-specific deltas.
- Do not restate global contracts in per-project docs — point here and add only the project-specific delta.

## Review Layering

| Layer | Location | Purpose |
|---|---|---|
| Orchestration | `.agents/skills/deep-review/SKILL.md` | Multi-pass review workflow |
| Global contracts | `~/dotfiles/docs/ai/review.md` | Reusable scope, triage, and routing rules |
| Per-project | `<project>/docs/ai/review.md` | Project conventions and AGENTS.md exclusions |

## Scope Calibration

Before raising a finding, check whether AGENTS.md or CLAUDE.md explicitly de-scopes the area (e.g. "No ARIA yet", "desktop-only", "single-user"). De-scoped capabilities are inadmissible as findings. Asymmetric calibration — enforcing violations but not exclusions — produces false-positive findings that add out-of-scope work.

## Bug Report Routing

After any review surfaces a confirmed bug:
1. Fix via `/bugfix-tdd` (failing test first).
2. Capture root cause, principle, anti-pattern, and enforcement candidate via `/learn`.
3. When a pattern repeats or has high blast radius, promote it to a lint rule, contract test, shared helper, or docs/ai rule — not just a narrative lesson.

Bug-learning files should form an abstraction ladder (incident → principle → enforcement), not competing ledgers across docs.
