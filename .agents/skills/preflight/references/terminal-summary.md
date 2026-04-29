# Terminal Summary

Print to the user after writing the output files.

## Single-session case

```
Preflight checklist created. Fly reads plan.md + checklist.md together.

File: <absolute-path-to-checklist>
[<relative-path-to-checklist>](<relative-path-to-checklist>)

Key decisions:
- <N> tasks across <M> phases
- Deep-review coverage: <summary, e.g., "Final deep-review covers all phases">
- Per-task models: <summary, e.g., "Phase 1 -> haiku, Phase 2 -> sonnet">
- Phase normal review: <e.g., "Phase 1, Phase 3" or "none">
- TDD gaps injected: <e.g., "Task 2, Task 3" or "none">
- LOC distribution: avg <N>, median <N>; inline <X>, subagent <Y>; smallest <id>=<N>, largest <id>=<N>
- Synthetic integration tests injected: <e.g., "Phase 1, Phase 3" or "none">
- Residual manual verification: <count, e.g., "0 phases (all automated)" or "Phase 2: 1 step (real Places API drift smoke)">
- Phase verification tags: <summary, e.g., "Phase 0: tests-only, Phase 1: tests-only, Phase 2: suggest-verify">
- Split: single file

Warnings (if any):
- <warning lines>

Assuming 1M context. Launch CC with:
  claude --model claude-opus-4-7[1m]
(substitute equivalent 1M-context model string if different in your environment)

Ready to execute? In a fresh session, run:
  /fly <relative-path-to-checklist>
```

## Multi-session case

```
Preflight artifacts created. Fly reads plan-N.md + checklist-N.md together per session.
Session split confirmed by user (step 2b).

Plan has <N> tasks. Split into <K> sessions:
  plan-1.md + checklist-1.md  (<tasks> tasks, Phases <start>-<end>)
  plan-2.md + checklist-2.md  (<tasks> tasks, Phases <start>-<end>)
  ...
  plan-K.md + checklist-K.md  (<tasks> tasks, Phases <start>-<end>, includes final gate + final verification)

Key decisions (plan-wide):
- <N> tasks across <M> phases
- Deep-review coverage: <summary>
- Per-task models: <summary>
- Phase normal review: <summary or "none">
- TDD gaps injected: <summary or "none">
- Synthetic integration tests injected: <e.g., "Phase 1, Phase 3" or "none">
- Residual manual verification: <count, e.g., "0 phases (all automated)" or "Phase 2: 1 step (real Places API drift smoke)">
- Phase verification tags: <summary, e.g., "Phase 0: tests-only, Phase 1: tests-only, Phase 2: suggest-verify">
- Split: <K> sessions

Warnings (if any):
- <warning lines>

Assuming 1M context. Launch CC with:
  claude --model claude-opus-4-7[1m]

Run each session in order:
  /fly checklist-1.md
  (fresh session)
  /fly checklist-2.md
  ...
  (fresh session)
  /fly checklist-K.md
```

## Format requirements

- File paths in the single-session case MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path.
- The "Key decisions" section must mirror the `## Decisions` blocks in the checklist file(s).
- The `/fly` command(s) must use the exact relative path(s), copy-paste ready.
- Warnings:
  - `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.` - emit when a phase had to be split mid-way.
  - Omit the entire Warnings block if no warnings apply.
