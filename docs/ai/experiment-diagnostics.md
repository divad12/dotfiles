# Experiment Diagnostics

## Contract

- When a probe or experiment produces implausible user-facing guidance, pause the experiment queue before logging the artifact as evidence.
- Fix the diagnostic source first: write a behavior test capturing the bad output, fix the shared logic, and rerun the canonical probe.
- Only promote corrected artifacts to durable evidence or curated docs. An artifact that embeds known-bad guidance becomes a misleading fixture for future agents.
- Record both the discovered product risk and the corrected artifact path before resuming the probe queue.

## Notes

- Experiment artifacts are not only observations — they are validation fixtures for product guidance. When an artifact exposes bad guidance, fix the guidance and regenerate the artifact before promoting it to durable evidence.
- What counts as implausible: a recommendation that contradicts domain constraints, a metric far outside the expected range, or guidance a product owner would immediately reject.
- This applies to any long-running probe or tuning loop where the system being probed produces user-facing output: recommendation calibration, AI output evaluation, capacity diagnostics, or auto-populate tuning.
