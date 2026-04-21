---
name: preflight
description: "Use when preparing an implementation plan for disciplined execution, typically after /superpowers:writing-plans and before /fly. Triggers: 'preflight', 'checklist the plan', 'prep for execution', or when given a plan file path to process."
argument-hint: [path to plan file]
user-invocable: true
---

# Preflight

Transform a plan file into a checklist contract that `/fly` executes.

## Purpose

Transform a plan into a preflight checklist with all execution decisions encoded. The checklist becomes the contract `/fly` executes.

Runs before `/fly`. Does not modify the plan - writes one or more sibling checklist files and prints a terminal summary.

> **1M context assumption.** Preflight assumes all `/fly` sessions will run on Claude opus with a 1M-token context window. The per-file task cap (`single_file_cap = 20`) is sized for that budget. If you are running at standard 200K context, halve the cap (tune `single_file_cap` below, or manually split tighter). The terminal summary tells the user the exact `claude --model ...` string to launch each session with.

## Tunable Constants

```
single_file_cap = 20  # tasks per checklist file. Plans exceeding this are split
                      # into multiple files, each <= this cap.
```

Assumes 1M-context opus per session (see note above).

## Triggers

- User invokes `/preflight <plan-path>` on any plan file (fresh from `/superpowers:writing-plans`, or mid-flight on a pre-existing plan).
- Not auto-chained from writing-plans - user reviews plan first, then explicitly invokes preflight.

## Input

Path to plan file (typically `docs/specs/plans/YYYY-MM-DD-<feature>.md`). Works on any markdown plan with task and phase sections.

## Output

1. One or more sibling checklist files:
   - If total tasks <= `single_file_cap`: a single file `<plan-dir>/<plan-basename>-checklist.md`.
   - If total tasks > `single_file_cap`: `K = ceil(total_tasks / single_file_cap)` files named `<plan-dir>/<plan-basename>-checklist-1.md`, `-checklist-2.md`, ..., `-checklist-K.md`.
2. Original plan is untouched (audit trail).
3. Terminal summary printed at end (see "Terminal Summary" section below).

## Overwrite Behavior

If any target checklist file already exists, warn and ask for explicit overwrite confirmation before proceeding. An existing checklist may contain in-progress `/fly` state (ticked checkboxes, filled slots). Clobbering loses work.

If the user confirms overwrite, preserve any fills from the existing file(s) only if the plan hasn't changed (same task list). If the plan changed, produce fresh checklists and tell the user their previous progress is in the file(s) they're overwriting.

## Decisions Preflight Makes

Preflight reads the plan and produces decisions for every task/phase before any execution. These decisions are static from `/fly`'s perspective - `/fly` does not make discretionary calls.

### Phase groupings

- If the plan has explicit phase structure (e.g., `## Phase N:` headers), respect it.
- If the plan has no phases and total tasks exceed the phase threshold (default: 15), batch related tasks into phases by shared files, dependencies, or domain concern. Group tasks that change the same files or layer together.
- If the plan has fewer tasks than the phase threshold, treat as a single phase.

### Per-task model assignment

Assign one of `haiku` / `sonnet` / `opus` per task based on complexity signals in the task text:

- **haiku** - touches 1-2 files with a complete spec, low integration, simple logic (e.g., config, model definitions, serializer helpers).
- **sonnet** - multi-file changes, integration concerns, pattern matching (e.g., endpoints, services with dependencies, moderate logic).
- **opus** - architecture decisions, broad codebase understanding, subtle correctness concerns, high blast-radius changes.

Err on the cheap side unless signals clearly indicate otherwise; the user can override.

### Review policy per task

- `standard` - dispatches spec-reviewer + code-reviewer (default).
- `batched-with <neighbor-ids>` - groups genuinely trivial adjacent tasks into a single post-batch review. Rules:
  - Max batch size: 3 tasks.
  - Tasks must be adjacent in the plan's task order.
  - Each task must be individually trivial (haiku-model-eligible, 1-file scope).
  - The batch's review gate lives on the LAST task in the batch (reviewer can only assess once all batched work is committed).

### Reviewer model per gate (dynamically assigned)

Defaults with per-task upgrade:

- **Spec review** - default `haiku`. Upgrade to `sonnet` when task has complex requirements or broad spec scope. Opus reserved for rare cases.
- **Code review** - default `sonnet`. Upgrade to `opus` when task involves subtle correctness, multi-file integration, architectural judgment, or high blast-radius.
- **Phase review (normal)** - default `sonnet`. Upgrade to `opus` for phases covering many files or cross-cutting concerns.
- **Deep-review (`/deep-review`)** - owns its own model logic; preflight does NOT override.

Upgrade rule of thumb: reviewer model sits one tier above the implementer model when the task is complex. If a task has `opus` implementer, its code review should be at least `opus`.

### Phase review gate

- `deep-review` (DEFAULT) - run `/deep-review` over the phase diff. Deep-review happens right after the phase completes while context is fresh and fixes are cheap. This is the default for all phases.
- `normal` - dispatch code-reviewer over the phase diff. Only for trivially small phases (see downgrade rule below).

**Downgrade rule:** a phase may use `normal` review instead of `/deep-review` only if ALL of:
  - Phase has <= 3 tasks.
  - All tasks in the phase are haiku-tier.
  - Phase scope is single-concern (1-2 files, no cross-cutting changes).

If any condition fails, the phase gets `/deep-review`. When in doubt, default to `/deep-review`.

### Final review gate

- `deep-review` - covers phases that only had normal review (i.e., phases that were downgraded by the rule above).
- `not needed` - skipped if every phase already has `/deep-review` coverage. This is the common case with the default-deep rule.

### Deep-review coverage invariant

**Every task's code must be in at least one deep-review scope before shipping.** With the default-deep rule, most plans satisfy this automatically (every phase is deep-reviewed, no final gate needed). Final gate is only required when a phase was downgraded to normal review.

### Multi-file split logic

If `total_task_count <= single_file_cap`:
- Write ONE checklist file: `<plan-dir>/<plan-basename>-checklist.md` (format below).

If `total_task_count > single_file_cap`:
- Compute `K = ceil(total_task_count / single_file_cap)`.
- Split into `K` files named `<plan-dir>/<plan-basename>-checklist-1.md` ... `-checklist-K.md`.
- Splitting rules:
  1. **Respect plan phase boundaries where possible.** Never split a phase across two files if the whole phase fits within `single_file_cap`.
  2. **Phase larger than the cap.** If a single phase exceeds `single_file_cap` on its own, split it at task boundaries (sequential order). Emit a warning in the terminal summary: `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.`
  3. **Standalone files.** Each file contains a complete set of tasks + phase gates for the phases it covers. `/fly` runs each file in a full pass (per-task loop plus phase gates for that file's phases).
  4. **Deep-review coverage invariant preserved.**
     - Per-phase `/deep-review` gates in the original plan stay on their original phases, which stay together in one file.
     - The **final `/deep-review` gate** lives ONLY on the LAST file (file `K`). It covers whatever phases the invariant says it must cover (same computation as single-file mode).
     - The **Fly Verification block** (final verification sweep) lives ONLY on file `K`. Files `1` through `K-1` do NOT include a final gate or final verification.
  5. **Header + decisions block.** Each file starts with the same header format, but the title is suffixed with `(File X of K)`. The decisions block summarizes decisions for that file's scope but also notes the full split (see Checklist Format below).
  6. **Next-file pointer.** Each file (except the last) ends with a line:
     ```
     Next file: <relative-path-to-next-checklist>
     ```
     Omit this line on file `K`.
  7. **READ FIRST.** Every file's `READ FIRST` reference points to the SAME single plan file (plan is the shared source of truth).

### TDD audit

For each task in the plan, check whether the task has a `write failing test` + `verify test fails` step pair before any implementation step.

- If present: copy the plan's step titles into the checklist unchanged.
- If absent: inject two extra checkboxes into the checklist (NOT into the plan) at the top of the task's step list, prefixed with `[INJECTED]`:
  - `[INJECTED] Write failing test for <task description>`
  - `[INJECTED] Run test, verify FAIL`

The plan file is never modified. The injection lives only in the checklist. `/fly` will instruct implementers to honor both plan steps and `[INJECTED]` checklist-only steps.

### Configurable thresholds

All thresholds are tunable by editing constants in this skill:

- Phase threshold (when to force phase batching): 15 tasks
- Max batch size: 3 tasks
- Per-file task cap: `single_file_cap = 20` (see Tunable Constants)

## Steps

### 1. Read the plan

Read the plan file at the given path. Identify:
- Phase sections (lines matching `^## Phase N:` or `^## Phase N `).
- Task sections (lines matching `^### Task N:` within phases, or top-level if no phases).
- Step checkboxes within each task (lines matching `^- \[ \] (Step N: )?`).
- Step titles (the text after `Step N: ` or after `- [ ] ` if no step numbering).

If the plan doesn't have phase sections, collect all tasks as a flat list - phase grouping happens in step 2.

### 2. Compute decisions

Apply the decision logic in "Decisions Preflight Makes" to the parsed plan:

1. **Phase grouping** - use plan's phases if present; else batch into phases if total tasks > phase threshold; else single phase.
2. **Per-task model** - read each task's text and classify into haiku/sonnet/opus.
3. **Review policy** - default `standard`; mark adjacent trivial tasks as `batched-with <neighbors>` (max batch size 3).
4. **Reviewer models per gate** - apply defaults with per-task upgrades.
5. **Phase review gates** - default `/deep-review` for every phase. Downgrade to `normal` only for trivially small phases (<=3 haiku tasks, single-concern). See "Phase review gate" for the downgrade rule.
6. **Final review gate** - needed only if any phase was downgraded to normal (rare with default-deep). Skipped when all phases have `/deep-review` coverage (the common case).
7. **TDD audit** - for each task, check for failing-test steps; mark tasks needing injection.
8. **Multi-file split** - if total task count > `single_file_cap`, compute `K` and allocate phases/tasks to files 1..K per the splitting rules.

### 3. Check for existing checklist(s)

Compute output path(s):

- Single-file case: `<plan-dir>/<plan-basename>-checklist.md`.
- Split case: `<plan-dir>/<plan-basename>-checklist-1.md` ... `-checklist-K.md`.

Examples:
- `docs/specs/plans/2026-04-17-export.md` (15 tasks) -> `docs/specs/plans/2026-04-17-export-checklist.md`
- `docs/specs/plans/2026-04-17-export.md` (45 tasks) -> `-checklist-1.md`, `-checklist-2.md`, `-checklist-3.md`

If any output file exists:
- Read it. If any checkboxes are ticked or any `<fill>` slots are filled, warn: "Checklist file(s) exist with in-progress state. Overwrite? (y/n)"
- Wait for user confirmation before continuing.
- On overwrite with a plan that still has the same task list, consider preserving prior fills - but if in doubt, fresh-write and tell the user.

### 4. Write the checklist file(s)

Produce the checklist(s) using the format in "Checklist Format" below. Write each to its computed output path.

### 5. Print terminal summary

Print the summary (see "Terminal Summary" below) to the user.

## Checklist Format

The checklist is a markdown file with a specific structure. Every task and review gate is a checkbox; every SHA and outcome is a `<fill>` slot that `/fly` replaces during execution.

### Header

Single-file case:

```markdown
# Preflight Checklist: <feature>

> **READ FIRST:** `<plan-path>` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

Split case (each file 1..K):

```markdown
# Preflight Checklist: <feature> (File X of K)

> **READ FIRST:** `<plan-path>` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

`<feature>` is the plan file's basename without date prefix or `.md` extension. E.g., `2026-04-17-export.md` -> `Export`.

### Decisions block

```markdown
## Decisions
- <N> tasks across <M> phases
- Deep-review coverage: <summary>
- Per-task models: <per-phase or per-task summary>
- Review batching: <list of batched task groups> | none
- TDD gaps injected: <list of task IDs> | none
- Split: single file | <K> files (<file-paths>)
```

In split mode, the `Split:` line lists the sibling checklist file paths (e.g., `3 files (2026-04-17-export-checklist-1.md, -checklist-2.md, -checklist-3.md)`). Each file carries this same line so a reader of any one file sees the full split.

### Phase blocks

```markdown
## Phase <N>: <phase name> | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

```markdown
### Task <id> (plan §<plan-reference>) | Model: <haiku|sonnet|opus> | Review: <standard | batched-with <neighbor-ids>>

Plan steps:
- [ ] Step 1: <title extracted from plan>
- [ ] [INJECTED] <injected step title, if any>
- [ ] Step N: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`
```

For batched tasks, individual tasks omit their own review gates; the LAST task in the batch carries a shared batch review gate:

```markdown
Batch review gate (covers Task <a>, Task <b>, Task <c>):
- [ ] Batch review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Batch review resolution - Action: `<fill>`
```

Phase gate at the end of each phase block:

```markdown
### Phase <N> Gate (reviewer: <model>)
- [ ] <Normal code-review on Phase N diff | /deep-review on Phase N diff> - Outcome: `<fill>`
- [ ] Phase <N> gate resolution - Action: `<fill>`
```

### Final gate block (LAST file only in split mode; always present in single-file mode unless not needed)

If needed:

```markdown
## Final Gate: /deep-review over <scope description>
- [ ] Outcome: `<fill>`
- [ ] Final gate resolution - Action: `<fill>`
```

If every phase already has deep-review:

```markdown
**Final gate not needed - all phases have deep-review coverage.**
```

In split mode, files 1..K-1 do NOT contain a Final Gate block or the "not needed" sentinel. They end with the next-file pointer instead.

### Verification block (LAST file only in split mode; always present in single-file mode)

```markdown
## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

In split mode, files 1..K-1 do NOT contain a Fly Verification block. Only file `K` does.

### Next-file pointer (split mode, files 1..K-1 only)

At the very end of each non-last file, append a single line:

```markdown
Next file: <relative-path-to-next-checklist>
```

Omit this line on file `K`.

## Terminal Summary

After writing the checklist file(s), print to the user.

### Single-file case

```
Preflight checklist created.

File: <absolute-path-to-checklist>
[<relative-path-to-checklist>](<relative-path-to-checklist>)

Key decisions:
- <N> tasks across <M> phases
- Deep-review coverage: <summary, e.g., "Final deep-review covers all phases">
- Per-task models: <summary, e.g., "Phase 1 -> haiku, Phase 2 -> sonnet">
- Review batching: <e.g., "Task 2 + Task 3 batched" or "none">
- TDD gaps injected: <e.g., "Task 2, Task 3" or "none">
- Split: single file

Warnings (if any):
- <warning lines>

Assuming 1M context. Launch CC with:
  claude --model claude-opus-4-7[1m]
(substitute equivalent 1M-context model string if different in your environment)

Ready to execute? In a fresh session, run:
  /fly <relative-path-to-checklist>
```

### Split case

```
Preflight checklist created.

Plan has <N> tasks. Splitting into <K> checklist files:
  <relative-path-to-checklist-1.md>   (<tasks> tasks, Phases <start>-<end>)
  <relative-path-to-checklist-2.md>   (<tasks> tasks, Phases <start>-<end>)
  ...
  <relative-path-to-checklist-K.md>   (<tasks> tasks, Phases <start>-<end>, includes final gate + final verification)

Key decisions (plan-wide):
- <N> tasks across <M> phases
- Deep-review coverage: <summary>
- Per-task models: <summary>
- Review batching: <summary or "none">
- TDD gaps injected: <summary or "none">
- Split: <K> files

Warnings (if any):
- <warning lines>

Assuming 1M context for all sessions. Launch CC with:
  claude --model claude-opus-4-7[1m]
(substitute equivalent 1M-context model string if different in your environment)

Run each file in a FRESH CC session, in order:
  /fly <relative-path-to-checklist-1.md>
  (then fresh session)
  /fly <relative-path-to-checklist-2.md>
  ...
  (then fresh session)
  /fly <relative-path-to-checklist-K.md>
```

Format requirements:
- File paths in the single-file case MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path.
- The "Key decisions" section must mirror the `## Decisions` blocks in the checklist file(s).
- The `/fly` command(s) must use the exact relative path(s), copy-paste ready.
- Warnings:
  - `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.` - emit when rule (2) above forced a mid-phase split.
  - Omit the entire Warnings block if no warnings apply.
