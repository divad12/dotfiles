> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: experiment-diagnostics.md (re-using from earlier)". If no, read it and announce "Context loaded: experiment-diagnostics.md".**

# Experiment-Driven Diagnostics

Read this when running a probe or tuning loop that generates user-facing guidance artifacts (recommendation text, diagnostic summaries, tuning docs).

## Contract

- Treat experiment artifacts as validation fixtures for product guidance, not just session logs.
- When a probe produces implausible user-facing guidance (unrealistic recommendations, wrong thresholds, misleading diagnostic copy), treat it as a product bug — not an observation to log and continue past.
- Do not promote a bad artifact to durable evidence or curated docs. Regenerate it after fixing the source.

## When a Probe Exposes Bad Guidance

1. **Pause the experiment queue.** Do not advance to the next probe or update curated docs while bad guidance is in the artifact.
2. **Write a behavior test** that asserts the correct guidance output for the triggering input. Confirm it fails.
3. **Fix the shared diagnostic source** — the function, template, or rule that produced the bad copy.
4. **Rerun the canonical probe** so the artifact reflects corrected behavior.
5. **Record both the discovered product risk and the corrected artifact path** before resuming the queue.

## Notes

- Implausible guidance in an experiment artifact is a defect in recommendation logic, not a data anomaly.
- A bad artifact promoted to docs becomes a false baseline that future agents treat as evidence.
- If fixing the source is out of scope for this session, mark the artifact `[KNOWN-BAD]` explicitly and exclude it from curated docs until regenerated.
