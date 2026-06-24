> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: long-running-workstreams.md (re-using from earlier)". If no, read it and announce "Context loaded: long-running-workstreams.md".**

# Long-Running Workstreams

Read this before starting or continuing any multi-hour or multi-session autonomous workstream.

## Contract

- Maintain a `scratch.md` as the single control surface for any long-running autonomous workstream.
- The scratch file has three permanent sections:
  1. **Current Truth For Compaction** — the minimal state a fresh agent needs after context compaction: what is true now, what already happened, where we are.
  2. **Next Steps** — an always-current ordered queue. The only required intervention should be "what's next? write it down, then do it."
  3. **Archaeology** — older per-run logs and completed steps, linked not restated.
- Treat the top section as the source of truth; Archaeology exists so Current Truth can stay short.
- Route durable learnings through `/learn`; scratch.md is not a learning backlog.
- Place the scratch file in the project's coordination directory (e.g. `docs/specs/<milestone>/scratch.md`), not a generic tmp location.

## Compaction Cleanup

After each context compaction, before continuing work:

1. Update **Current Truth For Compaction** to reflect what is now true.
2. Move completed Next Steps items into a short dated Archaeology entry.
3. Delete duplicated detail from Current Truth that now lives in Archaeology.
4. Compact the top section until it is shorter than before compaction.

A scratch file that skips compaction cleanup grows into a transcript. Future agents will spend as much effort reading it as they would starting over.

## Notes

- Distinguish scratch from durable evidence: triage files, run logs, and test traces live in separate files; scratch.md holds only state and queue.
- If the workstream needs a long-range plan (many tasks, dependencies), keep a separate plan file and point to it from Next Steps rather than embedding it inline.
- Promote any durable principle discovered during the workstream through `/learn` so it survives into the learning store; don't leave it buried in Archaeology.
