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

Runs before `/fly`. Does not modify the plan - writes a sibling checklist file and prints a terminal summary.

## Triggers

- User invokes `/preflight <plan-path>` on any plan file (fresh from `/superpowers:writing-plans`, or mid-flight on a pre-existing plan).
- Not auto-chained from writing-plans - user reviews plan first, then explicitly invokes preflight.

## Input

Path to plan file (typically `docs/specs/plans/YYYY-MM-DD-<feature>.md`). Works on any markdown plan with task and phase sections.

## Output

1. Sibling file: `docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md` (same directory as input plan, with `-checklist` suffix appended to basename).
2. Original plan is untouched (audit trail).
3. Terminal summary printed at end (see "Terminal Summary" section below).

## Overwrite Behavior

If the checklist file already exists, warn and ask for explicit overwrite confirmation before proceeding. An existing checklist may contain in-progress `/fly` state (ticked checkboxes, filled slots). Clobbering loses work.

If the user confirms overwrite, preserve any fills from the existing file only if the plan hasn't changed (same task list). If the plan changed, produce a fresh checklist and tell the user their previous progress is in the file they're overwriting.

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

- `normal` - dispatch code-reviewer over the phase diff.
- `deep-review` - run `/deep-review` over the phase diff (for large or complex phases).

### Final review gate

- `deep-review` - covers phases that only had normal review.
- `not needed` - skipped if every phase already had deep-review coverage.

### Deep-review coverage invariant

**Every task's code must be in at least one deep-review scope before shipping.** Preflight picks the combination of (per-phase deep-review + final deep-review) that satisfies this.

**Overwhelm rule:** if total tasks exceed the overwhelm threshold (default: 40), a single final deep-review over all phases is too large a scope for reliable auto-fix. In that case, assign per-phase deep-review to every phase and skip the final gate.

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
- Overwhelm threshold (when a single final deep-review is too large): 40 tasks
- Max batch size: 3 tasks

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
5. **Phase review gates** - choose `normal` or `deep-review` per phase based on phase size/complexity.
6. **Final review gate** - compute from invariant: needed unless every phase already has deep-review coverage, OR skipped if total tasks > overwhelm threshold (then every phase gets its own deep-review).
7. **TDD audit** - for each task, check for failing-test steps; mark tasks needing injection.

### 3. Check for existing checklist

Compute output path: same directory as plan, with `-checklist` appended to basename (before `.md` extension).

Examples:
- `docs/specs/plans/2026-04-17-export.md` → `docs/specs/plans/2026-04-17-export-checklist.md`

If the output file exists:
- Read it. If any checkboxes are ticked or any `<fill>` slots are filled, warn: "Checklist exists with in-progress state. Overwrite? (y/n)"
- Wait for user confirmation before continuing.
- On overwrite with a plan that still has the same task list, consider preserving prior fills - but if in doubt, fresh-write and tell the user.

### 4. Write the checklist

Produce the checklist using the format in "Checklist Format" below. Write to the output path.

### 5. Print terminal summary

Print the summary (see "Terminal Summary" below) to the user.

## Checklist Format

The checklist is a markdown file with a specific structure. Every task and review gate is a checkbox; every SHA and outcome is a `<fill>` slot that `/fly` replaces during execution.

### Header

```markdown
# Preflight Checklist: <feature>

> **READ FIRST:** `<plan-path>` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

`<feature>` is the plan file's basename without date prefix or `.md` extension. E.g., `2026-04-17-export.md` → `Export`.

### Decisions block

```markdown
## Decisions
- <N> tasks across <M> phases
- Deep-review coverage: <summary>
- Per-task models: <per-phase or per-task summary>
- Review batching: <list of batched task groups> | none
- TDD gaps injected: <list of task IDs> | none
- Octopus: deferred
```

### Phase blocks

```markdown
## Phase <N>: <phase name> | Phase gate: <normal review | deep-review> (reviewer: <model>)

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

### Final gate block

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

### Verification block (always last)

```markdown
## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

## Terminal Summary

After writing the checklist file, print to the user:

```
Preflight checklist created.

File: <absolute-path-to-checklist>
[<relative-path-to-checklist>](<relative-path-to-checklist>)

Key decisions:
- <N> tasks across <M> phases
- Deep-review coverage: <summary, e.g., "Final deep-review covers all phases">
- Per-task models: <summary, e.g., "Phase 1 → haiku, Phase 2 → sonnet">
- Review batching: <e.g., "Task 2 + Task 3 batched" or "none">
- TDD gaps injected: <e.g., "Task 2, Task 3" or "none">
- Octopus recursion: deferred

Ready to execute? In a fresh session, run:
  /fly <relative-path-to-checklist>
```

Format requirements:
- The file path MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path (so the user can click to open).
- The "Key decisions" section must mirror the `## Decisions` block in the checklist file (user gets the gist without opening the file).
- The `/fly` command must use the exact relative path, copy-paste ready.
