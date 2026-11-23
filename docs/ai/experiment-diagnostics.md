> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: experiment-diagnostics.md (re-using from earlier)". If no, read it and announce "Context loaded: experiment-diagnostics.md".**

# Experiment Diagnostics

## Contract

- Run probes to observe system behavior, not to confirm pre-formed beliefs.
- When a probe produces implausible user-facing guidance (e.g. a recommendation to increase a parameter to an absurd value), treat it as a product bug — not a data point.
- On implausible guidance: pause the experiment queue, write a behavior test asserting correct guidance for the probe input, fix the shared diagnostic source, rerun the canonical probe artifact, then resume the queue.
- Regenerate artifacts that encoded bad guidance before promoting them to durable evidence. An artifact produced before the fix is a regression fixture for the bug, not evidence of correct behavior.
- Distinguish implausible guidance (product bug — pause and fix) from surprising but plausible tuning results (data point — record and continue).

## Notes

- A probe loop that records implausible guidance without fixing it embeds a known defect into durable evidence. Future agents reading those artifacts may treat bad guidance as ground truth.
- The fix-then-regenerate step matters: an artifact regenerated after the fix serves as a regression guard; the original does not.
- This applies to any workflow that generates user-facing advisory copy driven by configurable logic: auto-populate tuning, scoring calibration, rule-engine diagnostics, budget suggestions, capacity guidance.
