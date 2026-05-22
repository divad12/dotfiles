> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstreams.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstreams.md".**

# Long-Running Workstreams

Read this when running a multi-hour autonomous or semi-autonomous loop: shakedown sessions, tuning runs, migration sweeps, or any workflow that outlasts a single context window.

## Contract

- **Keep a scratch control surface.** For any workstream that spans compactions or multiple agent turns, maintain a `scratch.md` with three sections: Current Truth (one-paragraph state summary), Next Steps (ordered queue), and Archaeology (compressed history). Without this, the next agent context starts from evidence instead of state.
- **Re-read and update on compaction.** At every context window restart or compaction: (1) read `scratch.md` to rehydrate current truth, (2) update Current Truth to reflect what changed, (3) move completed Next Steps items into a short Archaeology entry, (4) delete detail that is now redundant with artifacts or commit history. Current Truth must stay sharper than Archaeology.
- **Keep Current Truth actionable.** The test: the next agent turn should be able to read only Current Truth and Next Steps and continue without re-reading all prior artifacts. Anything that does not meet this bar belongs in Archaeology or a linked artifact file, not Current Truth.
- **Do not let scratch.md become a transcript.** If the file grows past ~200 lines, compact it during the next compaction re-read. Move resolved items to Archaeology, cut Archaeology to one-line summaries after the topic is closed, and delete entries that are fully captured in committed artifacts.
- **Evidence docs and scratch are separate.** Triage files, run logs, and shakedown artifacts are durable evidence; scratch is a disposable control surface. Do not merge them. Scratch is re-writable; evidence docs are append-only audit records.

## Notes

- The canonical example of a control surface that works across compactions: a `scratch.md` with Current Truth at the top, a tight Next Steps queue, and Archaeology that shrinks as work closes rather than growing as a transcript.
- A scratch file is useful only when the current-control section stays tighter than the Archaeology below it. If compaction cleanup is skipped, the file becomes the second giant transcript it was meant to replace.
