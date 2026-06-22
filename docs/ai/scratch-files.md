# Scratch Files for Long-Running Workstreams

## Contract

- Keep one `scratch.md` per long-running autonomous workstream as its single control surface.
- Structure the file with three sections: **Current Truth** (what is true now and what the next agent needs after compaction), **Next Steps** (ordered queue of what to do), and **Archaeology** (completed items and older logs).
- After context compaction or a long idle period, re-read `scratch.md` first, then update the Current Truth section before continuing.
- **Compaction cleanup** — after compaction, move completed Next Steps into a short Archaeology entry, delete duplicated detail in favor of short notes or links, and compact the Current Truth section before proceeding. A current-control section that grows as large as the archive defeats the file's purpose.
- The scratch file is a control surface, not an evidence log. Artifacts (test results, run outputs, screenshots) live in separate files. The scratch file holds current truth and the next queue only.
- Gauge: resuming after compaction should require only "What's next? Write it down, then do it." If re-reading the scratch file takes more than two minutes, it is overdue for cleanup.

## Canonical Files

- `docs/specs/<feature>/scratch.md` — feature-level control surface for a long-running autonomous task
- `scratch.md` at project root — when the workstream spans the whole project

## Notes

- A scratch file is separate from living triage files and per-run artifacts. Triage files explain what happened; scratch state tells the next agent what to do without rediscovering the thread.
- Archaeology grows from the bottom; current sections stay at the top. Compaction cleanup keeps the top sharp.
- If the file is too large to re-read quickly, compact before continuing — a bloated scratch file is worse than none.
