> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstream.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstream.md".**

# Long-Running Workstream

Reference for autonomous workstreams that span multiple sessions, compactions, or many-hour agent loops.

## Contract

- Maintain a `scratch.md` control surface alongside run-level evidence files.
- Keep the "Current Truth" section sharp enough that a resumed agent can continue without re-reading the whole thread.
- After every compaction or session resume, re-read and compact `scratch.md` before continuing.

## Scratch File Structure

```md
# Current Truth For Compaction
<State that is true now. No history, no "we tried X". Just what the next agent needs to act.>

## Next Steps
- [ ] Concrete item with enough detail to execute without asking
- [ ] Item 2

## Archaeology
### Run N — YYYY-MM-DD
<Compact summary of what changed. Link to run artifacts instead of embedding them.>
```

## Compaction Re-read Ritual

After session resume or context compaction:

1. Re-read "Current Truth" and "Next Steps".
2. Move completed Next Steps into a single archaeology entry (one line per item, date, link to artifact if any).
3. Delete archaeology detail that is now covered by a link to a run artifact.
4. Compact the top section — it should stay sharper than the archaeology below it.

## Notes

- Evidence artifacts (triage files, run logs, test outputs) record what happened. `scratch.md` tells the next agent what to do next. Both are needed; they serve different purposes.
- Name the file to the workstream, not the session: `docs/specs/<feature>/scratch.md`, not `scratch-2026-04-29.md`.
- The "Current Truth" section is the only piece an agent must read before continuing. If it is getting long, compact it first.
