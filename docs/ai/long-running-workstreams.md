> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstreams.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstreams.md".**

# Long-Running Workstreams

## Contract

- Maintain a `scratch.md` control surface for any workstream spanning multiple sessions, compaction events, or multi-hour autonomous loops.
- The top "Current Truth" section stays under ~30 lines and contains only what the next agent needs to continue without re-reading history.
- The "Next Steps" queue must reflect actual current state. Update it before moving to any new step.
- After every compaction or session resume, run the re-read ritual before substantive work.

## Scratch File Shape

```md
## Current Truth For Compaction
<!-- Keep under ~30 lines. Update before every long pause or handoff. -->
<current state summary>

## Next Steps
1. <immediate next action>
2. <second action>

## Archaeology
<!-- Completed loops, prior run evidence, superseded plans.
     Summarize + link rather than reproduce verbatim. -->
```

## Compaction Re-Read Ritual

When a session context is compacted or a new session continues the workstream:

1. Read scratch, starting at "Current Truth."
2. Move items completed in the last loop from "Next Steps" into a dated archaeology entry.
3. Compact the top section: remove duplicated facts, update status, keep it actionable.
4. Then continue with step 1 of the updated "Next Steps."

This ritual is mandatory before any substantive action. A stale "Current Truth" makes the scratch useless after a context reset.

## Maintenance Rules

- Scratch is the control surface; learning captures and evidence docs are the audit trail. Keep them separate.
- If the "Current Truth" section is no longer the first thing a cold agent reads and understands in under 60 seconds, run a compaction pass.
- Archaeology degrades over time. During compaction, prefer a one-paragraph summary plus a link over reproducing full prior content verbatim.
- If the scratch file grows large enough that its control section is buried, schedule a compaction pass as the first step of the next loop.

## Canonical Files

- `docs/specs/<feature>/scratch.md` — per-workstream scratch file (common convention)
