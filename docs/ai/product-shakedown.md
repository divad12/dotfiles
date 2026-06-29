> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: product-shakedown.md (re-using from earlier)". If no, read it and announce "Context loaded: product-shakedown.md".**

# Product Shakedown

## Contract

- After any browser flow that generates or persists data, run a targeted DB invariant check for the exact constraint that motivated the investigation. Browser test success does not prove generated-data quality.
- Treat optimistic update freshness, visible flicker, stale cache, and revert-then-correct behavior as **bugs**. These break trust in saved work and belong in bug bashing, not enhancement queues.
- Keep a scale-realism scenario backlog. Run at least one large-fixture shakedown (e.g. 60 groups, 500–1000 participants) per milestone, exercising every major surface — not only the main feature path on a small fixture.
- Bug class severity is determined by user-visible trust breakage, not engineering effort.

## Severity Calibration

Prioritize in this order during a bug bash:

1. **Interaction timing regressions** — optimistic updates that flicker, revert, or double-update; stale data visible after a save; counts that disagree with underlying data.
2. **Persisted-data invariants** — generated data that violates uniqueness, coverage, or ordering constraints, only visible via DB state inspection.
3. **Surface gaps** — tabs, views, or API endpoints not exercised under realistic load.
4. **Orientation affordances** — legends, hover states, read-only markers. Valuable UX improvements, but route these to enhancements unless they block task completion or corrupt architect trust in the data.

## Persisted-Data Verification Pattern

For any bug discovered in generated or persisted state:

1. Run the browser flow that exercises generation.
2. Run a targeted DB invariant check for the exact constraint (uniqueness across a partition, max per group, coverage across legs, etc.).
3. Record the invariant and the observed result in the scratch or triage doc.
4. Do not close the bug until the DB check passes. Browser suite green is not sufficient.

## Scale Realism

Single-group or small-fixture shakedowns overfit to the happy path. Bugs in tab navigation, group selectors, counts, and auto-generated content diversity often only appear under realistic event load. Add at least one large-fixture shakedown scenario per milestone.

Track single-group assumptions as a first-class shakedown risk. A surface that works for one group may silently break for 60.

## Notes

- "No user-facing impact" is not a valid triage for optimistic flicker. Architects lose trust in saved state when the UI appears to revert.
- End-to-end flow success ≠ generated data quality. Pair browser flows with DB invariant checks for generated-data bugs.
