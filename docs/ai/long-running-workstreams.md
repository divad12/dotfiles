> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstreams.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstreams.md".**

# Long-Running Workstreams

Read this when managing a multi-hour or multi-session autonomous workstream where the agent must resume after compaction or hand off context across runs.

## Contract

- Maintain a `scratch.md` control surface alongside any evidence or triage files. Evidence explains what happened; scratch state tells the next agent what to do without rediscovering the whole thread.
- Keep the "Current Truth" section current and sharp. Archaeology grows below it and stays compressed.
- Apply compaction-time maintenance every time context is compacted or a session resumes: update "Current Truth", move completed next-steps into a short archaeology entry, delete detail now covered by links or evidence files, and compact the top section before continuing.
- Do not let the scratch file grow into a second transcript. Garbage-collect it on every re-read after compaction.

## Scratch File Structure

Use this shape for `scratch.md`:

```
## Current Truth (update at every compaction)
<3-5 line summary of the actual state right now>

## Next Steps
- [ ] <next immediate action>
- [ ] <next queued action>

## Archaeology
### <YYYY-MM-DD> - <brief session note>
<single short paragraph; delete detail covered by evidence files or issue trackers>
```

Keep "Current Truth" and "Next Steps" together at the top; archaeology grows at the bottom. If "Next Steps" is empty, the workstream is done.

## Canonical Files

- `docs/specs/<feature>/scratch.md` — primary control surface for a feature workstream.
- Separate evidence files (`triage.md`, `shakedown-log.md`, run artifacts) hold full detail; scratch summarizes.

## Verification

After any compaction or resume, check that "Current Truth" reflects the actual current state, not an earlier snapshot. A stale "Current Truth" is the sign that the compaction maintenance step was skipped.

## Notes

- Do not write the same content to both scratch.md and evidence files. Scratch summarizes; evidence files contain full detail.
- This pattern is most valuable for: shakedown loops, experiment queues, autonomous workstreams, and any session expected to compact at least once.
- If the workstream has a living triage file, keep them separate: triage captures what was found; scratch captures what to do next.
