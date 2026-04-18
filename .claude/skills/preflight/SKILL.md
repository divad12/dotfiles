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

## Tunable Constants (edit here to tune octopus mode)

These constants control the mode-selection and phase-grouping logic. Change the values here to tune behavior; do not sprinkle copies elsewhere in this file.

```
single_orchestrator_cap = 10  # tasks (raw count). <= this → single-orchestrator mode; > this → octopus.
phase_weight_budget     = 20  # weight units per phase (CEILING, not target)
                              # weights: haiku task = 1, sonnet task = 2, opus task = 4
                              # +1 bonus for tasks mentioning refactor/migrate/rewrite
                              #    or spanning > 5 files in their own text
phase_session_cap       = 10  # phases per octopus session
                              # > this → octopus_multi_session (handoff file written)
```

**Three-tier mode selection** driven by these constants:

| Tier | Plan shape | `mode` string |
|------|------------|---------------|
| 1 | task_count ≤ `single_orchestrator_cap` | `single_orchestrator` |
| 2 | task_count > cap, phase_count ≤ `phase_session_cap` | `octopus_single_session` |
| 3 | task_count > cap, phase_count > `phase_session_cap` | `octopus_multi_session` |

Tiers 2 and 3 are collectively referred to as `mode_family = "octopus"`; tier 1 is `mode_family = "single_orchestrator"`.

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

### Mode detection (two-step)

Mode selection runs in two ordered steps because phase grouping logic differs between single-orchestrator and octopus. Order matters: `mode_family` must be decided BEFORE phase grouping, because octopus uses weighted grouping while single-orchestrator keeps existing grouping.

```
# Step 1: task_count decides whether octopus is in play.
if task_count <= single_orchestrator_cap:
    mode_family = "single_orchestrator"
    phase_groups = respect_plan_phases_if_explicit_else_single_phase()
else:
    mode_family = "octopus"
    phase_groups = group_by_weight_budget(phase_weight_budget)

# Step 2: phase_count splits octopus into single/multi-session.
if mode_family == "single_orchestrator":
    mode = "single_orchestrator"
elif len(phase_groups) <= phase_session_cap:
    mode = "octopus_single_session"
else:
    mode = "octopus_multi_session"
```

Coordinator-model assignment (below) runs only when `mode_family == "octopus"`.

### Phase groupings

- **Single-orchestrator mode** (existing behavior, unchanged):
  - If the plan has explicit phase structure (e.g., `## Phase N:` headers), respect it.
  - If the plan has no phases and total tasks exceed the phase threshold (default: 15), batch related tasks into phases by shared files, dependencies, or domain concern. Group tasks that change the same files or layer together.
  - If the plan has fewer tasks than the phase threshold, treat as a single phase.
- **Octopus mode** (weighted grouping under `phase_weight_budget = 20` ceiling):
  - **Weights per task** by assigned implementer model: `haiku = 1`, `sonnet = 2`, `opus = 4`.
  - **+1 weight bonus** for tasks whose text mentions `refactor`, `migrate`, or `rewrite` (case-insensitive), or that span more than 5 files in their own plan text.
  - **Explicit plan phases present:** respect them. If any user-specified phase exceeds weight 20, do NOT silently regroup. Emit a warning in the terminal summary (see `Phase <N> weight <W> above budget <20>; consider splitting.`). User can edit the plan and re-run preflight, or proceed anyway.
  - **No explicit plan phases:** greedily walk tasks in plan order and accumulate into a phase. When adding the next task would exceed 20 weight, close the current phase and start a new one. Prefer natural boundaries (shared files, dependencies) within the weight ceiling - if grouping by shared files is cleaner AND still fits under 20, do that.
  - Weighted grouping applies ONLY to octopus mode. Single-orchestrator mode never applies the weight budget.

### Coordinator model assignment (octopus modes only)

For each phase in octopus mode, preflight assigns a coordinator model for the phase subagent. This runs after phase grouping, and not at all in single-orchestrator mode.

```
default: opus (200K context)

upgrade to opus-1m (1M context) if ANY of:
  - phase weight >= 15
  - phase gate is /deep-review
  - expected review-gate dispatches > 5 (approx: task_count + 1 for phase gate)
  - plan mode is octopus_multi_session (heavier overall plan correlates with per-phase findings density)

downgrade to sonnet only if ALL of:
  - phase has no opus-tier task
  - phase gate is "normal" (not /deep-review)
  - phase has <= 3 tasks
  - no task mentions refactor/migrate/rewrite and no task spans > 5 files
  - NO upgrade signals above apply (upgrade always wins over downgrade)

never downgrade to haiku (haiku is fine for implementers; too weak for orchestration discipline)
```

Preflight emits the literal model string the user's environment supports. If `opus-1m` is unavailable in the user's Claude Code model registry, fall back to `opus` and surface a warning in the terminal summary: `opus-1m unavailable; heavy phases at standard context.`

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

1. **Mode detection (two-step)** - first set `mode_family` from `task_count` vs `single_orchestrator_cap`; then set `mode` from `phase_count` vs `phase_session_cap`. Order matters: mode_family drives phase grouping in the next step.
2. **Phase grouping** -
   - Single-orchestrator mode: use plan's phases if present; else batch into phases if total tasks > phase threshold; else single phase.
   - Octopus mode: respect explicit plan phases (warn if any exceeds `phase_weight_budget`); else greedy-group by weight under the 20-weight ceiling, preferring natural boundaries.
3. **Per-task model** - read each task's text and classify into haiku/sonnet/opus.
4. **Review policy** - default `standard`; mark adjacent trivial tasks as `batched-with <neighbors>` (max batch size 3).
5. **Reviewer models per gate** - apply defaults with per-task upgrades.
6. **Phase review gates** - choose `normal` or `deep-review` per phase based on phase size/complexity.
7. **Final review gate** - compute from invariant: needed unless every phase already has deep-review coverage, OR skipped if total tasks > overwhelm threshold (then every phase gets its own deep-review).
8. **Coordinator model per phase (octopus only)** - apply the opus / opus-1m / sonnet assignment rules from "Coordinator model assignment". Upgrade signals always win over downgrade signals.
9. **TDD audit** - for each task, check for failing-test steps; mark tasks needing injection.

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

### 4b. Write the multi-session handoff file (octopus_multi_session only)

If `mode == "octopus_multi_session"`, write a companion file: `<plan-dir>/<plan-basename>-handoff.md`. Path is derived from the plan (not the checklist): same directory as the plan, basename with `-handoff` appended before `.md`. Example: `docs/specs/plans/2026-04-17-export.md` → `docs/specs/plans/2026-04-17-export-handoff.md`.

Content template (fill in the bracketed values):

```markdown
# Multi-session handoff: <feature>

> Plan has <N> tasks across <M> phases. Too large for single-session octopus
> (phase_session_cap = 10). Execute in <K> sessions. Each session runs the
> same command on the same checklist; fly auto-resumes at the first phase
> whose `Octopus:` status header is not `done`.

## Session windows (recommended)

### Session 1: Phases 1-<end1>
Start a fresh Claude Code session. Run:
  /fly <relative-path-to-checklist>
Fly will process Phases 1-<end1> and halt when its session-window heuristic trips
(default: after 10 phases done in one session, OR when main's message count
exceeds a threshold).

### Session 2: Phases <start2>-<end2>
Prereq: Session 1 marked Phases 1-<end1> as `Octopus: done`.
Start a fresh Claude Code session. Same command.

### Session <K>: Phases <startK>-<M> + final gate + final verification
Prereq: Session <K-1> done.
Start a fresh Claude Code session. Same command.
This session also runs the Final Gate and Final Verification sweep.

## State

Authoritative: the `Octopus:` status headers in the checklist.
Advisory: this file. Session boundaries are suggestions; fly picks up wherever
it left off regardless of how you chunked the sessions.
```

Window count `K = ceil(M / phase_session_cap)`. Session boundaries split phases at multiples of `phase_session_cap`. Skip this step entirely for `single_orchestrator` and `octopus_single_session` modes.

If the handoff file already exists, overwrite it (it is a regenerated artifact; state lives in the checklist, not here).

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
- Mode: <single_orchestrator | octopus_single_session | octopus_multi_session>
- Coordinator models (octopus only): <per-phase summary, compressed when repetitive>
```

In single-orchestrator mode, omit the `Coordinator models` line entirely. The `Mode:` line always appears.

### Phase blocks

**Single-orchestrator mode** (existing format, unchanged):

```markdown
## Phase <N>: <phase name> | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

**Octopus mode** (adds the `Octopus:` token as the SECOND pipe-delimited segment, between the phase name and the phase gate):

```markdown
## Phase <N>: <phase name> | Octopus: pending (coordinator: <model>) | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

The `Octopus:` segment is inserted between `Phase <N>: <name>` (first segment) and `Phase gate: ...` (third segment). Preflight always writes `Octopus: pending (coordinator: <model>)` at creation time. `/fly` mutates the status during execution (`pending` → `in-flight:<id>` → `done`). `<model>` is the literal coordinator model string assigned by the rules in "Coordinator model assignment" above.

Single-orchestrator checklists MUST omit the `Octopus:` token entirely. Its absence is the signal to `/fly` that it should run its single-orchestrator loop.

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

**Octopus mode addition.** In octopus mode (single or multi-session), append ONE additional checkbox line to the Fly Verification block, after the existing lines:

```markdown
- [ ] All phases marked `Octopus: done`
```

Single-orchestrator checklists MUST NOT include this line. Fly's final verification, in octopus mode, ticks this box only after grepping and confirming no `Octopus: pending` or `Octopus: in-flight:` tokens remain in the checklist.

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
- Mode: <single-orchestrator | octopus single-session | octopus multi-session>
- Coordinator models: <per-phase summary, octopus modes only; compress when repetitive, e.g., "Phases 1-5 -> opus; Phase 6 -> opus-1m">
- Windows: <K> sessions recommended (<boundaries>). Handoff doc: <relative-path-to-handoff.md>  # multi-session only

Warnings (if any):
- Phase <N> weight <W> above budget <20>; consider splitting.
- Plan <=10 tasks but total weight <X> > 20; consider manual octopus.
- opus-1m unavailable; heavy phases at standard context.

Ready to execute? In a fresh session, run:
  /fly <relative-path-to-checklist>
```

Format requirements:
- The file path MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path (so the user can click to open).
- The "Key decisions" section must mirror the `## Decisions` block in the checklist file (user gets the gist without opening the file).
- The `/fly` command must use the exact relative path, copy-paste ready.
- Octopus-specific lines:
  - `Mode:` line always appears (value reflects the selected tier; use human-readable variants `single-orchestrator`, `octopus single-session`, `octopus multi-session` for display even though internal mode strings use underscores).
  - `Coordinator models:` line appears only when `mode_family == "octopus"`. Summarize per phase; compress when consecutive phases share a coordinator (e.g., `Phases 1-5 -> opus; Phase 6 -> opus-1m`).
  - `Windows:` line appears only when `mode == "octopus_multi_session"`. `<K> = ceil(phase_count / phase_session_cap)`. `<relative-path-to-handoff.md>` is the path written by step 4b.
- Warnings:
  - `Phase <N> weight <W> above budget <20>; consider splitting.` - emit one per overspent user-specified phase (octopus mode, explicit plan phases only).
  - `Plan <=10 tasks but total weight <X> > 20; consider manual octopus.` - emit when `mode_family == "single_orchestrator"` but summed task weights would exceed one octopus phase budget, hinting that the user might want to manually escalate.
  - `opus-1m unavailable; heavy phases at standard context.` - emit when any phase was assigned `opus-1m` but the environment's model registry does not provide it, so preflight fell back to `opus`.
  - Omit the entire Warnings block if no warnings apply.
