> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Code Review

Cross-cutting review contracts. Review *orchestration* (how to run passes) belongs in the invoking skill (e.g. `/deep-review`); this doc holds shared contracts; project-specific review criteria belong in `<project>/docs/ai/review.md` as a delta that links here and adds only the project-specific differences.

## Contract

- **Determine scope first.** Default to uncommitted changes. If the worktree is clean and the branch is ahead, review the branch diff.
- **Base branch.** Read project coordination docs (`PROGRESS.md`, `AGENTS.md`) for an explicit target branch before computing the diff. Fall back to `main` only when no project-specific base is declared. Hard-coding `main` creates noisy diffs in projects with an active integration branch (`m3`, `master`, a release branch).
- **Include untracked files.** Uncommitted scope includes new untracked files. Use `git ls-files --others --exclude-standard` to list them and `git diff --no-index -- /dev/null "$file"` to produce an added-file patch for each one.
- **Scope exclusions.** Before raising a finding, check whether the project's `AGENTS.md` explicitly de-scopes the area ("No ARIA yet", "desktop only", "no i18n", "no mobile"). A de-scoped capability is inadmissible — drop it, do not defer it. The reviewer-override that raises severity for rule *violations* must also suppress findings in areas the project has *explicitly excluded*. Apply both directions.

## Finding Categories

- **Must Fix** — correctness bugs, type errors, security issues, data integrity failures, accessibility failures, test failures (pre-existing or new).
- **Easy Wins** — dead code, naming, convention violations, missing error handling with a clear fix.
- **Fix These Too** — DRY violations (non-deferrable), fragile code, pre-existing correctness issues in touched areas, Boy Scout cleanups.
- **Defer** — only genuinely large work (new tables, new endpoints, multi-file architecture). DRY violations cannot be deferred.

### Deferred item format

For each deferred item:
- **What's happening**: 2–3 sentences in user/product terms. Avoid "unsafe cast" / "type error" unless there is no honest product framing.
- **User-facing impact**: what the user sees, loses, or risks. If none: "No user-facing impact — purely internal."
- **Why not now**: one sentence.
- **Where**: file:line.

This format is mandatory. Without the user-facing impact line, deferred items read as engineering todos and cannot be weighed against product priorities.

## Canonical Skills

- `/deep-review` — multi-pass parallel review orchestration.

## Notes

- Per-project `docs/ai/review.md` should link here and add only project-specific lenses, severity calibrations, or excluded concerns.
