---
name: preflight
description: "Use when preparing an implementation plan for disciplined execution, typically after /superpowers:writing-plans and before /fly. Triggers: 'preflight', 'checklist the plan', 'prep for execution', or when given a plan file path to process."
argument-hint: [path to plan file]
user-invocable: true
---

# Preflight

Transform a plan file into per-session plan files and tracking checklists that `/fly` executes.

## Purpose

Transform a plan into execution-ready artifacts: per-session plan files (self-contained task content) and lightweight tracking checklists (checkboxes, SHA/Outcome/Resolution slots, review gates). Fly reads both - the plan file for task content, the checklist for tracking state.

Runs before `/fly`. Does not modify the original plan - writes per-session plan files, tracking checklists, and prints a terminal summary.

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

Path to plan file. Preferred location: `docs/specs/YYYY-MM-DD-<feature>/plan.md`. Works on any markdown plan with task and phase sections, regardless of where it lives.

## Feature folder convention

All artifacts for a feature live in one folder: `docs/specs/YYYY-MM-DD-<feature>/`

```
docs/specs/2026-04-18-whatsapp-connector/
  design.md              (spec from brainstorming)
  plan.md                (plan from writing-plans - frozen audit trail)
  checklist.md           (preflight output, single-session plans)
  plan-1.md, plan-2.md   (per-session plan splits, multi-session plans)
  checklist-1.md, -2.md  (per-session tracking checklists, multi-session plans)
  deferred.md            (created by fly if findings deferred)
  reviews/               (review artifact files from fly)
    task-1.1-spec.md
    task-1.1-code.md
    phase-1-gate.md
    ...
```

## Auto-relocate on entry

If the plan file is NOT already inside a feature folder (e.g., it's at `docs/specs/plans/2026-04-18-feature.md` from an older convention), preflight:

1. Derives the feature folder: `docs/specs/YYYY-MM-DD-<feature>/` from the plan's filename.
2. Creates the folder if it doesn't exist.
3. Moves the plan file into it as `plan.md`.
4. If a sibling `design.md` or `*-design.md` exists in the old location with a matching date-feature prefix, moves it too as `design.md`.
5. Prints: `Relocated plan to <new-path>. Feature folder: <folder>.`
6. Continues with the relocated path.

If the plan is already at `<feature-folder>/plan.md` (or any path inside a feature folder), skip relocation.

## Output

**Single-session plans** (total tasks <= `single_file_cap`):
1. `<feature-folder>/checklist.md` (tracking only - checkboxes, SHA/Outcome/Resolution slots, review gates).
2. `<feature-folder>/plan.md` stays as-is. Fly reads it directly for task content.

**Multi-session plans** (total tasks > `single_file_cap`):
1. `<feature-folder>/plan-1.md`, `plan-2.md`, ..., `plan-K.md` (per-session plan splits - self-contained task content for each session).
2. `<feature-folder>/checklist-1.md`, `checklist-2.md`, ..., `checklist-K.md` (tracking only).
3. `<feature-folder>/plan.md` stays as-is (frozen audit trail).

**Both cases:**
- Creates `<feature-folder>/reviews/` directory (fly writes review artifacts here).
- Original plan is untouched.
- Terminal summary printed at end (see "Terminal Summary" section below).

Fly reads the checklist for tracking state and the corresponding plan file for task content. Together, the pair is self-contained for the session.

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

- **sonnet** (DEFAULT) - most tasks. Multi-file changes, integration, pattern matching, endpoints, services. Also use for tasks that seem simple but touch test infrastructure or shared utilities.
- **haiku** - ONLY for truly trivial single-file tasks with zero integration risk (e.g., adding one config line, updating a version string, pure docs edits). When in doubt, use sonnet. Haiku often gets things wrong on anything non-trivial, wasting a review cycle.
- **opus** - architecture decisions, broad codebase understanding, subtle correctness concerns, high blast-radius changes.

Default to sonnet. The cost of a haiku mistake + re-dispatch + re-review exceeds the savings from using haiku in the first place.

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
- Write ONE checklist file: `<feature-folder>/checklist.md` (tracking only, format below).
- No plan split needed. Fly reads `plan.md` directly for task content.

If `total_task_count > single_file_cap`:
- Compute `K = ceil(total_task_count / single_file_cap)`.
- Split into `K` plan files: `<feature-folder>/plan-1.md` ... `plan-K.md` (per-session plan content).
- Split into `K` checklist files: `<feature-folder>/checklist-1.md` ... `checklist-K.md` (tracking only).
- Splitting rules:
  1. **Respect plan phase boundaries where possible.** Never split a phase across two files if the whole phase fits within `single_file_cap`.
  2. **Phase larger than the cap.** If a single phase exceeds `single_file_cap` on its own, split it at task boundaries (sequential order). Emit a warning in the terminal summary: `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.`
  3. **Paired files.** Each session has a plan file (task content) and a checklist file (tracking). Fly reads both. `/fly` runs each pair in a full pass (per-task loop plus phase gates for that session's phases).
  4. **Deep-review coverage invariant preserved.**
     - Per-phase `/deep-review` gates in the original plan stay on their original phases, which stay together in one file.
     - The **final `/deep-review` gate** lives ONLY on the LAST checklist (file `K`). It covers whatever phases the invariant says it must cover (same computation as single-file mode).
     - The **Fly Verification block** (final verification sweep) lives ONLY on checklist `K`. Checklists `1` through `K-1` do NOT include a final gate or final verification.
  5. **Header + decisions block.** Each checklist starts with the same header format, but the title is suffixed with `(File X of K)`. The decisions block summarizes decisions for that file's scope but also notes the full split (see Checklist Format below).
  6. **Next-file pointer.** Each checklist (except the last) ends with a line:
     ```
     Next file: <relative-path-to-next-checklist>
     ```
     Omit this line on checklist `K`.
  7. **Per-session plan files are self-contained.** Each plan-N.md has all the context needed for its session (goal, conventions, key references, verbatim task content). The checklist references the plan file in its header. Together, the plan-N + checklist-N pair is self-contained for the session.

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
9. **Phase verification tagging** - for each phase, classify as `auto-verify`, `suggest-verify`, `manual-only`, or `tests-only` based on task content. Extract "Phase end-state test" paragraphs from the plan if present.
10. **Plan split preparation** - for multi-session plans (>single_file_cap tasks), prepare per-session plan files. Extract Shared Context material (goal, conventions, key references) from plan-level sections. For each session, determine which tasks and phases belong to it. For single-session plans, no split needed (fly reads plan.md directly).

### 2b. Propose session breakdown (interactive - plans with >20 tasks only)

For plans with total tasks exceeding `single_file_cap` (default 20), present the user with a session breakdown before writing any files. For plans with 20 or fewer tasks, skip this step entirely (single session, no split needed).

Present the following to the user:

```
Plan has <N> tasks across <M> phases:

| Phase | Tasks | Focus |
|---|---|---|
| 0 | 8 | <phase name/goal> |
| 1 | 10 | <phase name/goal> |
...

Default split (cap = 20 tasks/session) -> <K> sessions:
| Session | Phases | Tasks |
|---|---|---|
| 1 | 0-1 | 18 |
| 2 | 2-3 | 20 |
...

<Alternative split> -> <J> sessions:
| Session | Phases | Tasks | Why split here |
|---|---|---|---|
| 1 | 0 | 8 | Clean boundary before UI work |
| 2 | 1-2 | 15 | Related backend + API |
...

Tradeoffs:
| Axis | <K> sessions | <J> sessions |
|---|---|---|
| Per-session blast radius | ... | ... |
| Context budget per session | ... | ... |
| Ship-ability of each PR | ... | ... |

Recommend <one> because: <1-2 sentences>.

Pick: default (<K>), recommended (<J>), or specify your own grouping?
```

The alternative split should be computed by analyzing phase boundaries, domain concerns, and natural ship-points (where a PR would make sense). It may have more or fewer sessions than the default.

Wait for the user's response. Then proceed to write files matching the chosen split.

### 2c. Read design.md (if present)

If `design.md` exists in the feature folder alongside the plan:

1. Read it and extract the 2-3 sentence summary from the top (usually the Goal or Overview section).
2. For phases that involve architectural decisions (new components, state machines, data flow), identify the relevant design.md section for targeted extraction into plan-N.md files (multi-session) or left in plan.md for fly to read (single-session).

Do NOT dump the full design.md into any output file. Only extract targeted context that helps implementers understand WHY, not just WHAT.

If no design.md exists, skip this step.

### 3. Check for existing output files

Compute output path(s):

- Single-session case: `<feature-folder>/checklist.md`.
- Multi-session case: `<feature-folder>/plan-1.md` ... `plan-K.md` and `<feature-folder>/checklist-1.md` ... `checklist-K.md`.

Examples:
- `docs/specs/2026-04-17-export/plan.md` (15 tasks) -> `docs/specs/2026-04-17-export/checklist.md`
- `docs/specs/2026-04-17-export/plan.md` (45 tasks) -> `plan-1.md`, `plan-2.md`, `plan-3.md` + `checklist-1.md`, `checklist-2.md`, `checklist-3.md`

If any checklist output file exists:
- Read it. If any checkboxes are ticked or any `<fill>` slots are filled, warn: "Checklist file(s) exist with in-progress state. Overwrite? (y/n)"
- Wait for user confirmation before continuing.
- On overwrite with a plan that still has the same task list, consider preserving prior fills - but if in doubt, fresh-write and tell the user.

### 4. Write the output files

**Multi-session case:** First write the per-session plan files (`plan-1.md` ... `plan-K.md`) using the format in "Per-Session Plan File Format" below. Then write the tracking checklists (`checklist-1.md` ... `checklist-K.md`) using the format in "Checklist Format" below.

**Single-session case:** Write only the tracking checklist (`checklist.md`) using the format in "Checklist Format" below. No plan split needed.

Write each file to its computed output path.

### 5. Print terminal summary

Print the summary (see "Terminal Summary" below) to the user.

## Per-Session Plan File Format (multi-session only)

Each `plan-N.md` is a self-contained plan file for one fly session. Only produced when total tasks > `single_file_cap`.

```markdown
# <Feature name> - Session N: <phase names>

## What we're building (overall)
<2-3 sentences from plan's Goal paragraph. If design.md exists, blend in its summary.>

## This session's scope
<1-2 sentences describing what this session's phases accomplish>

## Conventions
<extracted from plan's Conventions section if present: TDD rules, mock patterns, test env, run commands, commit cadence>

## Key references
<extracted imports, shared types, file structure summaries relevant to this session's phases>

## Tasks

### Task N.M: <task title>
<full task content verbatim from plan: files, steps, code blocks, everything>

### Task N.M+1: ...
...
```

Rules for populating per-session plan files:
- "What we're building" and "Conventions" are duplicated in each plan-N.md. Around 10 lines each. Trivial cost, makes each file self-contained.
- "This session's scope" varies per file.
- "Key references" extracted per-phase (only imports/types relevant to this session).
- Task content is verbatim from plan.md - no paraphrasing.
- If design.md exists, incorporate a brief architectural context note in the "What we're building" section.
- "Conventions" is present only if the plan has a Conventions, Setup, or similar section. Omit entirely if the plan has no such content.
- "Key references" is present only if the plan references specific imports, shared types, or file structure that implementers need. Omit if none are relevant to this session's phases.

## Checklist Format

The checklist is a tracking-only markdown file. Every task and review gate is a checkbox; every SHA and outcome is a `<fill>` slot that `/fly` replaces during execution. Task content (files, steps, code blocks) lives in the plan file, not the checklist.

### Header

Single-session case:

```markdown
# Preflight Checklist: <feature>

> **READ FIRST:** `plan.md` (this session's plan content).
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

Multi-session case (each file 1..K):

```markdown
# Preflight Checklist: <feature> (File X of K)

> **READ FIRST:** `plan-X.md` (this session's plan content).
> Full plan at `plan.md` for audit.
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
- Phase verification tags: <per-phase summary, e.g., "Phase 0: tests-only, Phase 1: suggest-verify">
- Split: single file | <K> files (<file-paths>)
```

In split mode, the `Split:` line lists the sibling checklist file paths (e.g., `3 files (checklist-1.md, checklist-2.md, checklist-3.md)`). Each file carries this same line so a reader of any one file sees the full split.

### Phase blocks

```markdown
## Phase <N>: <phase name> | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

Tasks are tracking-only (no embedded plan content):

```markdown
### Task <id> | Model: <haiku|sonnet|opus> | Review: <standard | batched-with <neighbor-ids>>

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

No **Files:** block, no embedded task text, no code blocks. Fly reads task content from the plan file (plan.md for single-session, plan-N.md for multi-session).

For batched tasks, individual tasks omit their own review gates; the LAST task in the batch carries a shared batch review gate:

```markdown
Batch review gate (covers Task <a>, Task <b>, Task <c>):
- [ ] Batch review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Batch review resolution - Action: `<fill>`
```

Phase end-state verification block (before the phase gate, at the end of each phase's tasks):

```markdown
### Phase <N> end-state verification
- Type: <auto-verify | suggest-verify | manual-only | tests-only>
- Manual test: <extracted from plan's "Phase end-state test" paragraph, if present>
- Automated: tests pass (handled by phase-regression.sh)
```

Verification type tagging rules:
- `auto-verify`: phase has UI changes AND verification is a simple render check (page loads, component exists).
- `suggest-verify`: phase has UI changes AND verification needs multi-step interaction.
- `manual-only`: phase involves live network, external APIs, or deployment ops.
- `tests-only`: phase is server-only with no UI changes (tests + regression check cover it).

Preflight determines the tag from the phase's task text content (grep for UI component names, API routes, deployment steps, etc.). When in doubt, default to `suggest-verify`.

If the plan has no "Phase end-state test" paragraph for a phase, the "Manual test" line reads: `(none specified in plan - implement based on phase scope)`.

Phase gate at the end of each phase block (after the end-state verification):

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

After writing the output files, print to the user.

### Single-session case

```
Preflight checklist created. Fly reads plan.md + checklist.md together.

File: <absolute-path-to-checklist>
[<relative-path-to-checklist>](<relative-path-to-checklist>)

Key decisions:
- <N> tasks across <M> phases
- Deep-review coverage: <summary, e.g., "Final deep-review covers all phases">
- Per-task models: <summary, e.g., "Phase 1 -> haiku, Phase 2 -> sonnet">
- Review batching: <e.g., "Task 2 + Task 3 batched" or "none">
- TDD gaps injected: <e.g., "Task 2, Task 3" or "none">
- Phase verification tags: <summary, e.g., "Phase 0: tests-only, Phase 1: suggest-verify">
- Split: single file

Warnings (if any):
- <warning lines>

Assuming 1M context. Launch CC with:
  claude --model claude-opus-4-7[1m]
(substitute equivalent 1M-context model string if different in your environment)

Ready to execute? In a fresh session, run:
  /fly <relative-path-to-checklist>
```

### Multi-session case

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
- Review batching: <summary or "none">
- TDD gaps injected: <summary or "none">
- Phase verification tags: <summary, e.g., "Phase 0: tests-only, Phase 1: suggest-verify, Phase 2: auto-verify">
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

Format requirements:
- File paths in the single-session case MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path.
- The "Key decisions" section must mirror the `## Decisions` blocks in the checklist file(s).
- The `/fly` command(s) must use the exact relative path(s), copy-paste ready.
- Warnings:
  - `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.` - emit when rule (2) above forced a mid-phase split.
  - Omit the entire Warnings block if no warnings apply.
