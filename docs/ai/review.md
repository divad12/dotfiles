> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Review Contracts

Reusable contracts for code and product review. Load before running or configuring a review workflow. Orchestration skills (`deep-review`, `qa-test`) describe how to run a workflow; this doc holds scope rules, severity contracts, and layering principles that apply across projects.

## Contract

- **Scope must follow the project's integration branch.** Before computing a diff, read `PROGRESS.md` or `AGENTS.md` for an explicit target branch. Default to `main`/`master` only when no project-specific base is declared.
- **Uncommitted scope includes untracked files.** Use `git ls-files --others --exclude-standard` alongside `git diff` and `git diff --cached`. New helpers and test files are part of the changeset.
- **Apply AGENTS.md exclusions before raising a finding.** If the project's `AGENTS.md` says "No X yet" or "X is not needed", that area is inadmissible for review regardless of general conventions.
- **Rule compliance is bidirectional.** AGENTS.md rule violations are elevated to at least major. AGENTS.md de-scoped areas exclude default-convention findings. Both directions apply.
- **Subagent reviewers must see AGENTS.md.** Include the project's AGENTS.md (or a relevant excerpt) in every independent reviewer dispatch, not just the diff and reviewer instructions.
- **Surface findings in plain English with user-facing impact.** If there is no user-facing impact, say so explicitly. Engineering-todo framing without impact is not sufficient for deferred items.

## Finding Severity

| Severity | Description |
|---|---|
| Must fix | Correctness bugs, type errors, security issues, data integrity failures, accessibility failures, test failures |
| Easy wins | Dead code, simple extractions, naming improvements, missing error handling, convention violations |
| Fix these too | DRY violations (non-negotiable), fragile code, pre-existing correctness issues in touched areas |
| Defer | Genuinely large work: new tables, new endpoints, multi-file architecture changes |

**DRY violations cannot be deferred.** Any duplicated logic a reviewer surfaces gets extracted inline.

**Pre-existing correctness issues in touched code must be fixed**, not noted. "The diff didn't introduce it" is not a reason to leave broken behavior in place.

## Layering

- **Global** (`~/dotfiles/docs/ai/review.md`, this file): finding contracts, severity rules, scope commands, and layering principles that apply across every project.
- **Per-project** (`<project>/docs/ai/review.md`): project-specific review lenses, domain severity overrides, and repo conventions. Point to this doc and add only the delta. Do not restate global contracts.
- **Orchestration skills** (`deep-review`, `qa-test`, etc.): sequence, reviewer dispatch, consolidation, and auto-fix rules.

Keep one source of truth per concept. Duplication between global and per-project review docs causes drift.

## Notes

- **Asymmetric rule calibration is a documented failure mode.** A skill that elevates AGENTS.md violations to major but ignores AGENTS.md exclusions will add out-of-scope changes and erode trust in findings. Always apply exclusions on the same pass as violations.
- **Base branch detection matters.** Projects with active integration branches (e.g. `m3`, `develop`) produce large noisy diffs when reviewed against `main`. Read project coordination docs before choosing the base.
- Bug-learning outputs (fixed incident log, lessons learned, bug patterns) should form an abstraction ladder, not competing ledgers. Route through a single learning system; update one entry's evidence trail when new sources emerge rather than creating sibling entries.
