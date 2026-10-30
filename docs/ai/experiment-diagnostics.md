> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: experiment-diagnostics.md (re-using from earlier)". If no, read it and announce "Context loaded: experiment-diagnostics.md".**

# Experiment-Driven Diagnostics

Read this before running probe loops, tuning experiments, diagnostic parameter sweeps, or any session that generates curated artifact evidence about product guidance.

## Contract

- When a probe produces implausible user-facing guidance, pause the experiment queue immediately — do not log it as evidence and move on.
- Treat implausible guidance as a product bug, not an anomalous data point. Fix the shared diagnostic source using TDD (write a failing behavior test, fix the source, verify), then regenerate the canonical probe artifact.
- Record both the discovered product risk and the corrected artifact path before resuming the experiment queue.
- Curated artifacts are validation fixtures for product guidance, not raw observations. Promote an artifact to durable evidence only after it reflects correct behavior.
- Probe artifacts that predate a guidance fix are stale. Replace them before citing them in downstream docs or recommendations.

## When to apply

- Auto-populate tuning, capacity diagnostics, recommendation-quality probes, or any loop where generated output becomes user-facing advice.
- Any session that appends to a curated results file or doc that others will act on.

## Steps when implausible guidance is found

1. **Pause the experiment queue.** Note the failing probe ID and the implausible guidance text.
2. **Write a failing behavior test** from the user's perspective: "when scenario X, the recommendation should say Y, not Z."
3. **Fix the shared diagnostic source** — the function, prompt template, or calculation that emitted the bad guidance. Do not patch the artifact directly.
4. **Verify**: run the failing test; confirm it passes; confirm no other probes regress.
5. **Regenerate the canonical probe artifact** for the failing scenario.
6. **Record** the product risk (what a user would have read) and the corrected artifact path in the session log or scratch doc.
7. **Resume** the experiment queue from where it paused.

## Notes

- Implausible guidance includes: recommendations that contradict domain constraints (e.g., "increase max walk to 80 minutes" when the product domain makes that harmful), advice that inverts expected directionality, or outputs that no reasonable user would act on safely.
- If the root cause is a missing guardrail in the diagnostic logic, add a contract test or lint rule after fixing it (see bugfix-tdd's enforcement capture step).
