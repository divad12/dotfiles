> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstream.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstream.md".**

# Long-Running Workstreams

Read this when managing a multi-hour or multi-compaction agent workstream, or when setting up a scratch control surface for autonomous continuation.

## Contract

- Maintain a `scratch.md` as the primary control surface, separate from run artifacts, triage files, and evidence logs.
- Keep the top section as the compaction-safe anchor: a brief "Current Truth" summary and an always-current "Next Steps" queue. Re-read this first after every compaction or session resume.
- Treat the scratch file as a control surface, not an archive. Evidence and detailed logs belong in dedicated artifact files. Scratch holds only the minimal state needed to resume without re-reading everything.
- Run a cleanup pass each time you re-read scratch after compaction: update Current Truth, move completed next-steps into a short archaeology entry, delete duplicated detail in favor of links, and compact before continuing.
- If the Next Steps queue is ever empty, surface it as a human decision point rather than guessing what comes next.

## Scratch File Shape

```md
## Current Truth For Compaction
<2–5 sentence summary: what's done, what's broken, what the key unknowns are.>

## Next Steps
- [ ] <concrete next action>
- [ ] ...

## Archaeology
### <date> — <short label>
<Terse entry: what changed, what was tried, what the result was. Links to artifacts.>
```

A resumed agent should be able to read only the Current Truth and Next Steps sections and know exactly where to start. If it can't, the file needs a cleanup pass.

## Canonical Files

- `<workstream-root>/scratch.md` — control surface (current truth + next steps + archaeology). Not a log.
- `<workstream-root>/<run-label>.md` — per-run evidence artifacts. Append-only.

## Verification

- After compaction, confirm: Current Truth reflects the actual current state; Next Steps points to the real next action; Archaeology is terse enough that the whole section is still scannable.
- If re-reading scratch takes more than ~30 seconds, it needs a cleanup pass before continuing.

## Notes

- Archaeology is a soft-delete: it preserves breadcrumbs without crowding the current-work view. Each entry should be short enough to skim.
- The scratch file is not a substitute for actual evidence artifacts. Evidence explains what happened in detail; scratch tells the next agent where to pick up.
