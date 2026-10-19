> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: experiment-driven-diagnostics.md (re-using from earlier)". If no, read it and announce "Context loaded: experiment-driven-diagnostics.md".**

# Experiment-Driven Diagnostics

## Contract

- When running experiment or probe loops to diagnose product behavior, treat implausible outputs as bugs — pause the experiment queue, write a behavior test, fix the shared diagnostic source, and rerun the canonical probe artifact before updating curated docs.
- Record both the discovered product risk and the corrected artifact path in session notes before resuming the experiment queue.
- Do not promote a probe artifact to durable evidence until it reflects corrected product guidance.
- Keep a probe backlog separate from fixed artifacts. A run that revealed a bug is not a completed probe — it becomes a regression-test case.

## Notes

Probe artifacts serve two purposes: observations (what the product does) and validation fixtures (what it should do). When a probe exposes bad guidance or implausible recommendations, it transitions from observation to defect. The correct sequence is: stop → write failing test → fix the root cause → rerun the probe → update the artifact. Skipping any step risks promoting known-bad guidance to canonical docs where future agents treat it as ground truth.

This principle applies to any experiment loop that produces user-facing guidance: capacity diagnostics, recommendation tuning, auto-populate probes, ranking experiments, and similar workstreams.
