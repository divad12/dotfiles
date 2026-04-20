# Fly Multi-Session: Checklist Splitting + Per-Task Integrity Gate

**Status:** Design
**Date:** 2026-04-20
**Supersedes:** `docs/specs/2026-04-18-fly-octopus-design.md`
**Extends:** `docs/specs/2026-04-17-preflight-and-fly-design.md`

## Why this supersedes 2026-04-18

The 2026-04-18 "octopus" design proposed that main `/fly` dispatch per-phase subagents via the Task tool, each subagent coordinating its phase's tasks in a fresh context. Empirical execution on a real 19-task plan surfaced two unrecoverable blockers that make in-process octopus impossible:

1. **Nested Task dispatch is not permitted.** When main `/fly` dispatches a phase subagent via the `Task` tool (subagent_type `general-purpose`), that phase subagent does not itself have Task tool access. The nested dispatch required to run per-task implementers and reviewers from inside a phase subagent fails. The earlier "`/deep-review` precedent validates nested dispatch" argument was wrong: `/deep-review` runs its sub-reviewers via Bash, Codex CLI, and MCP tools, not via further Task dispatches.

2. **`opus-1m` (1M-token opus variant) is not accepted by the Task tool `model` parameter.** The enum is fixed at `haiku | sonnet | opus`. Preflight's coordinator-model annotation (`coordinator: opus-1m`) cannot be passed to a Task dispatch verbatim, violating the checklist-is-contract principle if it is rewritten silently.

Both blockers eliminate the architectural foundation of the 2026-04-18 design. Rather than patch around them, this design drops the in-process octopus concept entirely and replaces it with a simpler multi-session approach.

## Goal

Handle plans that exceed a single CC session's reliable task capacity without relying on in-process subagent coordination.

Three-tier model, simpler than 2026-04-18's three tiers:

| Plan size | What preflight does | What fly does |
|-----------|---------------------|---------------|
| ≤ 20 tasks | Write one checklist file (as in 2026-04-17) | Run single-orchestrator execution (as in 2026-04-17) |
| > 20 tasks | Split into N checklist files, each ≤ 20 tasks | Run single-orchestrator execution per file, across N fresh CC sessions |

No "octopus" concept. No status headers. No phase subagents. No in-process cross-phase coordination. Each checklist file is a complete standalone `/fly` run.

## Design Principles

Carried forward:

1. **Checklist is the contract** (2026-04-17 + 2026-04-18).
2. **Commitment device through markdown checkboxes** (2026-04-17).
3. **Preserve upstream via template reuse** (2026-04-17).
4. **Agent-agnostic where feasible** (2026-04-17). Integrity gate is CC-specific, same acceptable trade-off as Task dispatch.
5. **Deep-review invariant** (2026-04-17). Preserved per-file: each checklist file satisfies the invariant for its tasks (via per-phase deep-review or the final-file's final deep-review).
6. **Auto-fix by default** (2026-04-17).
7. **Checklist is a compressed index** (2026-04-17).

New for this design:

8. **Split files beat status headers.** Instead of one checklist with per-phase `Octopus:` status tokens, preflight writes multiple checklist files. Each is a complete standalone unit. State is implicit: file N done when user moves to file N+1. No runtime state machinery.
9. **Per-task integrity gate is the primary drift defense.** An on-disk bash script verifies each task's reviewer dispatches actually happened (evidence from CC's per-subagent JSONL transcripts) before fly proceeds to the next task. Self-report is not accepted.
10. **1M context assumption.** Preflight sizes files at 20 tasks on the assumption all fly sessions run on Claude opus with 1M context. User launches each session with `claude --model claude-opus-4-7[1m]` (or equivalent). If running at 200K, user halves the cap.

## Architecture

```
                            PREFLIGHT
                               │
                 plan has <= 20 tasks?
                 ┌─────────────┴─────────────┐
                YES                          NO
                 │                           │
                 ▼                           ▼
        single checklist file       split into N checklist files
        <plan>-checklist.md         <plan>-checklist-1.md
                                    <plan>-checklist-2.md
                                    ...
                                    <plan>-checklist-N.md
                                    (last file carries final gate +
                                     final verification)
                 │                           │
                 ▼                           ▼
             Terminal summary reports result + 1M model launch hint

                            FLY (one per session)
                               │
            user runs /fly <file> in a fresh CC session
            (one file per session; user runs all N in order
             across N fresh sessions for split plans)
                               │
                               ▼
                 ┌─────────────────────────┐
                 │  Single-orchestrator    │
                 │  per-task loop (2026-04-17) │
                 │  with these additions:  │
                 │                         │
                 │  - Per-task integrity   │
                 │    gate after step H    │
                 │    (or step I for       │
                 │    batched tasks)       │
                 │                         │
                 │  - Periodic re-read of  │
                 │    SKILL.md every 10    │
                 │    completed tasks      │
                 │                         │
                 │  - Reworded Iron Rule   │
                 │    (traceability, not   │
                 │    "mental verifying")  │
                 └─────────────────────────┘
                               │
                               ▼
                 Phase gates + (on final file) final gate +
                 final verification as in 2026-04-17
```

No subagent dispatches for phase coordination. No receipt parsing. No reconciliation gate. No status headers. The file is the unit; fly runs one file start-to-finish per invocation.

## Preflight Changes

### New: 1M context assumption

Preflight assumes all downstream fly sessions will run on Claude opus with a 1M context window. The per-file task cap is sized for that budget. Preflight's terminal summary tells the user to launch each fly session with `claude --model claude-opus-4-7[1m]` (or equivalent 1M-context model). If running at standard 200K context, user tunes `single_file_cap` down (halve to 10).

### New: Single tunable constant

```
single_file_cap = 20  # tasks per checklist file; halve for 200K sessions
```

### New: Multi-file split logic

If total task count > `single_file_cap`, preflight writes `K = ceil(total_tasks / single_file_cap)` files:

```
<plan-dir>/<plan-basename>-checklist-1.md
<plan-dir>/<plan-basename>-checklist-2.md
...
<plan-dir>/<plan-basename>-checklist-K.md
```

Splitting rules:

1. Respect plan phase boundaries where possible. Never split a phase across two files if the whole phase fits within `single_file_cap`.
2. If a single phase exceeds `single_file_cap` on its own, split it at task boundaries (sequential). Emit a terminal-summary warning.
3. Each file contains a complete set of tasks + phase gates for the phases it covers. Each file is standalone; fly runs each as a full single-orchestrator pass.
4. **Deep-review coverage invariant**: per-phase `/deep-review` gates stay with their original phase, which stays together in one file. The **final `/deep-review` gate + final verification live on the LAST file only** (file K). Files 1 through K-1 have NO final gate and NO final verification.
5. Every file has the same header/decisions block format. Split-case files get a `(File X of K)` marker in the title and a `Next file: <path-to-next>` line at the end (omit on the last file).
6. Every file's `READ FIRST` pointer references the single plan file (not other checklist files).

If total task count ≤ `single_file_cap`, preflight writes one file (same format as 2026-04-17, no split-mode markers).

### Deleted from 2026-04-18

- Tunable Constants: `phase_weight_budget`, `phase_session_cap`, `single_orchestrator_cap` (multi-tier mode selection). Replaced by one constant.
- Two-step mode detection (`mode_family` / `mode`).
- Coordinator model assignment (entire logic and the `coordinator: <model>` phase-header annotation).
- Weighted phase grouping (weights, refactor/migrate/rewrite bonus, budget checks).
- Phase header `Octopus: <status>` token. Phase headers return to the 2026-04-17 format.
- Multi-session handoff file (`-handoff.md`). Not needed; file listing in terminal summary is sufficient.
- Fly Verification addition (`All phases marked Octopus: done`). Gone with the token.
- `opus-1m` anywhere as a dispatch annotation. It remains valid as a MODEL the user launches fly with, not as a Task-tool dispatch parameter.

### Updated terminal summary

Single-file case: same as 2026-04-17 minus `Octopus recursion: deferred` line.

Split case adds:

```
Plan has <N> tasks. Splitting into <K> checklist files:
  <relative-path-to-checklist-1.md>   (<tasks> tasks, Phases <start>-<end>)
  <relative-path-to-checklist-2.md>   (<tasks> tasks, Phases <start>-<end>)
  ...
  <relative-path-to-checklist-K.md>   (<tasks> tasks, Phases <start>-<end>, includes final gate + final verification)

Assuming 1M context for all sessions. Launch CC with:
  claude --model claude-opus-4-7[1m]
(substitute equivalent 1M-context model string if different in your environment)

Run each file in a fresh CC session, in order:
  /fly <relative-path-to-checklist-1.md>
  (close session, start fresh)
  /fly <relative-path-to-checklist-2.md>
  ...
```

## Fly Changes

### New: Per-task integrity gate (primary drift defense)

After filling BOTH Outcome slots for a task (end of step H for standard spec + code, end of step I for batched, or end of the combined-review shortcut), fly MUST invoke the integrity-check script before moving on.

Script location: `~/.claude/skills/fly/integrity-check.sh` (primary path). In plugin-cache installs, use Glob to resolve.

Invocation:

```
bash <path-to-integrity-check.sh> <task-id> <plan-dir> <task-sha>
```

Output is a single line:
- `PASS` (exit 0) - proceed to next task
- `HALT: <reason>` (exit 1) - fly halts immediately, surfaces reason to user

The script checks CC's per-subagent JSONL transcripts at `~/.claude/projects/<encoded-cwd>/<session-id>/subagents/agent-*.jsonl`:

1. Expected review files exist at `<plan-dir>/reviews/task-<id>-{spec,code}.md` (or `-combined.md`).
2. Each review file is non-trivial (>500 bytes), mtime after the task's commit timestamp.
3. For each review file, find the subagent JSONL that contains a `Write` to that file path.
4. That subagent made at least 3 tool_use entries (real engagement: read diff + read code context + write review, at minimum).

If any check fails: `HALT: <reason>`.

**Why this closes the main fabrication vector**: the 2026-04-17 review-artifact mandate caught "no review file exists," but a fly under context pressure could still write a rubber-stamp review file directly (no subagent dispatched) and pass that check. The integrity gate requires evidence from CC's own transcript logging (written by the harness, not by fly) that a subagent actually ran and did real work. Fly cannot forge CC's transcript of its own tool invocations.

**CC-specific.** The integrity gate relies on the CC subagent transcript layout. Non-CC agents (Codex, Cursor) don't produce these transcripts; the script HALTs with "cannot locate CC project dir." Acceptable - the whole Task-dispatch mechanism is already CC-specific.

### New: Periodic SKILL.md re-read (secondary drift defense)

Fly maintains a counter of completed tasks (tasks whose final step checkbox was ticked) in the current session. At every 10th completed task (tasks 10, 20, ...), before proceeding:

1. Read this SKILL.md file via the Read tool.
2. Continue.

Purpose: refresh discipline rules in context so late-session tasks get the same rigor as early-session. Context pressure builds gradually; periodic re-read undoes rule compression. Cost: one Read tool call per 10 tasks. For a 20-task checklist (the cap), re-read fires at most twice.

### Reworded Iron Rule

The 2026-04-17 Iron Rule said "every checkbox must be ticked by verifying its condition" - interpretable as "verify in my head." Replaced with:

> Every slot value traces to a specific tool call. If you cannot point to the Task, Write, Edit, or Bash call that produced it, the slot is unfilled and the work is incomplete.
>
> - Every `SHA:` slot traces to an implementer subagent's report.
> - Every `Outcome:` slot traces to a review file on disk that a **dispatched reviewer subagent** wrote. The `review:` token names the file; the file's mtime is after the commit SHA timestamp; the file's YAML `commit-sha` matches.
> - Every `Resolution:` slot traces to either a fix-implementer subagent's commit, a FIXME in source, or a `<plan>-deferred.md` section.
>
> Mental review is not a review. A reviewer is a Task dispatch that returns and writes a file. If no Task dispatch happened, no review happened.

The per-task integrity gate enforces this mechanically after every task; final verification enforces it structurally at the end.

### Deleted from 2026-04-18

- Octopus Mode Detection section.
- Phase-Scoped Invocation (`--phase=N`) section.
- Octopus Main Loop, including: main loop pseudocode, Phase Subagent Prompt Template, Per-Phase Reconciliation, Session-Window Heuristic, Receipt Format, Handoff File references.
- Rationalization Table rows about phase-subagent receipts.
- Red Flag entries about Octopus status flipping, session cap, coordinator drift.
- Final Gate / Final Verification preambles that differentiated main vs phase-scoped runs.
- `All phases marked Octopus: done` verification bullet.

### Preserved unchanged

- State detection (fresh run / mid-flight / complete).
- Template Resolution (for implementer + reviewer prompts).
- Per-task loop A-I (implementer, reviews, fix loops).
- Reviewer Independence Override block.
- Review Artifact Files path conventions.
- Outcome Slot Format (`findings=N fixed=N deferred=N (review: <path>); <summary>`).
- Phase Gates (normal + `/deep-review` paths).
- Final Gate (runs after all phases complete).
- Final Verification sweep (all boxes ticked, all slots filled, deep-review invariant, etc.).
- Rationalization Table (non-octopus rows).
- Red Flags (non-octopus rows).

## Checklist Schema

Returns to 2026-04-17 format minus a couple of lines. No `Octopus:` token on phase headers. No `(coordinator: <model>)` annotation. No verification block addition.

Split-case additions (applied only when preflight splits):

- File title: `# Preflight Checklist: <feature> (File <X> of <K>)`
- Decisions block: `Split: <K> files (<comma-separated paths>)`
- At end of file (omitted on last file): `Next file: <path-to-next-checklist>`

All other checklist elements unchanged from 2026-04-17.

## Integrity-Check Script (reference implementation)

Location: `.claude/skills/fly/integrity-check.sh`

Summary of logic:

1. Encode current working directory to CC project-dir naming: every non-alphanumeric → `-`.
2. Find the project dir at `~/.claude/projects/<encoded-cwd>/`. Fall back to newest project dir containing a recently-modified JSONL.
3. Find the newest `<session-id>.jsonl` in that project dir.
4. Locate subagents dir at `<project-dir>/<session-id>/subagents/`.
5. Resolve task commit timestamp via `git log -1 --format=%ct <task-sha>`.
6. Determine expected review files for this task (spec+code, combined, or halt if none found).
7. For each expected review file: stat exists, mtime > task commit time, size > 500 bytes.
8. For each expected review file: grep subagent JSONLs for `"file_path":"<review-file>"` entries to find which subagent wrote it. Fail if no subagent transcript shows the write.
9. For each writing subagent: count `"type":"tool_use"` entries. Fail if < 3.
10. Output `PASS` on success, `HALT: <reason>` on first failure.

The full script is ~110 lines of bash. It is deterministic, uses only `find`, `ls`, `grep`, `stat`, `wc`, `git`, and shell builtins.

## Drift Defense Stack

Final stack, in order of defense:

1. **Per-task integrity gate** (script, after each task).
2. **End-of-phase reconciliation** (existing, checks phase slice in checklist).
3. **Periodic SKILL.md re-read** (every 10 tasks).
4. **Final verification sweep** (existing, end-of-file).

Dropped from earlier designs:
- **Null-result meta-check** (dispatched haiku verifier per findings=0). Redundant with integrity gate: real reviewer subagents running in fresh context rarely rubber-stamp after engaging with the diff, and the integrity gate's `>=3 tool calls + Write to review path + file size/content gate` already catches the cases meta-check covered. Dropped to reduce per-null cost, false-positive noise on legitimately-clean reviews, and orchestrator transcript clutter.
- **3-consecutive-nulls HALT**. Pattern-level fallback for the pre-integrity-gate era. Redundant with per-task integrity gate.
- **Periodic Iron Rule echo** (self-report, weaker than re-read + integrity gate).
- **Session task cap** (moved into preflight as the 20-task file cap; fly doesn't enforce independently).
- **Transcript grep of main's JSONL** (subsumed by subagent-transcript check).

## Out of Scope / Deferred

- **Nested subagent dispatch.** CC doesn't permit it for `general-purpose` subagents. If future CC versions expose a subagent type with Task tool access, in-process octopus could be reconsidered. Not this design.
- **In-process concurrent dispatch of independent phases.** Each checklist file runs in its own session; no concurrency.
- **Automated script-based session orchestration.** A bash/SDK script could iterate through split files and spawn CC sessions programmatically. Not this design - user runs fly manually per file, which preserves the ability to interact at file boundaries.
- **`opus-1m` as a dispatch parameter.** Blocked by Task tool enum. Remains valid as a session-launch model but not as a per-dispatch override.
- **Self-attestation ("did you dispatch?") as a drift check.** Rejected: self-report is the failure mode we're defending against.

## Compatibility

- **2026-04-17 design**: extends it. Single-orchestrator fly behavior for ≤20 task plans is identical to 2026-04-17. Only additions: integrity gate + re-read + reworded rule.
- **2026-04-18 design**: supersedes it. All octopus-mode machinery is removed. The rationale (context pressure, fabrication under load) still applies; the structural fix is now multi-file split + integrity gate instead of phase subagents.
- **Review-artifact mandate (2026-04-17 amendment)**: unchanged. Integrity gate builds on it.
- **HALT heuristics (2026-04-17 amendment)**: 3-consecutive-nulls HALT removed (redundant with integrity gate). Other suspicious-pattern triggers unchanged (missing review file, Outcome/file count mismatch).
- **`/deep-review` invocation via subagent + Skill tool**: unchanged. Still valid because deep-review doesn't itself nest Task dispatches.

## Implementation Notes

- Four consolidation scripts at `.claude/skills/fly/` drop orchestrator context burn by replacing many inline Bash/Edit tool calls with single invocations whose output is a structured one-line PASS/HALT/ERROR:
  - `integrity-check.sh <task-id> <plan-dir> <task-sha>` - per-task drift defense (subagent-transcript check + review-file gates).
  - `final-verify.sh <checklist-path>` - end-of-run verification sweep. Replaces ~15 grep/stat calls with one.
  - `phase-regression.sh <phase-base-sha> <phase-head-sha>` - phase gate regression check. Detects test command (cached in `.fly-test-cmd`), runs at base + HEAD via `git worktree add`, reports regressions. Replaces ~5 calls per phase.
  - `tick-steps.sh <checklist-path> <task-id> <step-nums-csv>` - bulk-tick plan-step checkboxes in one `sed` pass instead of N Edit calls.
- Skills updated: `.claude/skills/preflight/SKILL.md` (multi-file split logic), `.claude/skills/fly/SKILL.md` (integrity gate + re-read + reworded rule + script invocations for final-verify, phase-regression, tick-steps; all octopus content deleted).
- Test fixtures under `.claude/skills/preflight/tests/expected/` may contain stale `- Octopus: deferred` lines from the 2026-04-17 era; regenerate if running tests.

## Next Steps

1. Review and approve this spec.
2. Test on a medium-sized plan (20-40 tasks) to exercise the split logic end-to-end.
3. Observe integrity-gate HALTs in practice; tune `single_file_cap` if drift is observed before the cap.
4. Consider formalizing the integrity-check script's contract with a small test suite under `.claude/skills/fly/tests/integrity/`.
