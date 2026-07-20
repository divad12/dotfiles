> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Review Contracts

## Contract

- Orchestration skills (`/deep-review`, `/fly` gates) say how to run the workflow. This doc holds the reusable contracts for what to look for and how to route findings.
- Global review contracts belong here. Project-specific review lenses belong in `<project>/docs/ai/review.md` as a delta that links here and adds only project-specific constraints.
- Do not restate a global contract in a project doc; add the project-specific override and point here for the rest.

## Scope

Determine the correct review base before starting:

- Read `PROGRESS.md`, `AGENTS.md`, or equivalent to find the declared integration branch (`main`, `master`, `m3`, etc.).
- Use that branch as the review base. Do not default to `main` without checking.
- State the base branch choice in the review summary so the reader can verify the scope.

## Finding Admissibility

Before raising a finding, check whether the project has explicitly de-scoped the area:

- Read `AGENTS.md` for any "No X yet", "X is not needed", or "X is out of scope" declarations.
- If the area is de-scoped, the finding is inadmissible — do not raise it.
- Asymmetric calibration (enforcing violations but ignoring de-scoping) produces false positives. The inverse rule is equally mandatory: de-scoped features trump default-convention findings.

Projects that share this rule: no ARIA/screen reader work yet, no mobile/RTL, no i18n, single-user, desktop-only — any of these means the corresponding finding class is inadmissible until the de-scoping is lifted.

## Bug-Fix Routing

After every deterministic bug fix, route the learning through `/learn`:

1. **Fixed incident** — root cause, symptom, fix, and affected files.
2. **Principle** — the violated contract at the highest actionable level. Climb until the principle helps future work find sibling bugs across the codebase, not just the one that just occurred.
3. **Anti-pattern** — the thought pattern or shortcut that produced the bug.
4. **Enforcement candidate** — at least one mechanical check that would prevent recurrence: a test, lint rule, schema scan, shared helper, or checklist item.

Bug-learning files form an abstraction ladder, not competing ledgers. If a project keeps both a fixed-incident log and a bug-patterns doc, keep them at different abstraction rungs (specific incident vs. reusable bug class) rather than duplicating the same content.

## Notes

- Review scope must follow the project's declared integration branch. Wrong base produces a noisy diff that buries real findings in unrelated volume.
- Admissibility check is mandatory for any project with explicit de-scoping rules. Reviewers default to industry conventions (WCAG, mobile, i18n) unless the project's rules say otherwise.
- Enforcement candidates are not optional refinements — a bug class without one is only partially learned.
