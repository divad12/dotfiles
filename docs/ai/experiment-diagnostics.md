> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: experiment-diagnostics.md (re-using from earlier)". If no, read it and announce "Context loaded: experiment-diagnostics.md".**

# Experiment Diagnostics

Read this before running probe loops, diagnostic experiments, or tuning sessions that produce artifacts (logs, reports, recommendation outputs).

## Contract

- Treat experiment artifacts as validation fixtures, not just observations. When an experiment produces output that will be cited as evidence, the output must reflect correct behavior.
- When a probe produces implausible user-facing guidance (e.g. "increase max walk time to 80 minutes"), pause the experiment queue before logging it as evidence.
- Write a behavior test that asserts the correct guidance, fix the shared diagnostic source, and rerun the canonical probe before promoting the artifact to durable evidence.
- Record both the discovered product risk and the path to the corrected artifact in the experiment log.
- Do not promote an artifact that contains known-bad guidance to docs, plans, or calibration files — even temporarily. Bad guidance in a durable artifact becomes evidence for the next agent.

## Verification

- Before citing an artifact: confirm it was generated after the last fix to its source logic.
- After fixing diagnostic source logic: rerun the canonical probe and replace the stale artifact.

## Notes

- "Implausible" means: the guidance would cause user harm if followed, contradicts project domain knowledge, or recommends values far outside normal operating range.
- The pattern applies to any loop that writes diagnostic outputs: auto-populate tuning, capacity probes, recommendation calibration, shakedown evidence.
- Pausing the experiment queue costs one run. Promoting a bad artifact costs multiple sessions of confusion downstream.
