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
single_file_cap = 20         # tasks per checklist file; plans exceeding this split into multiple files
codex_browser_enabled = true # inject [SYNTHETIC: codex-browser-verify] task per session if browser-verifiable work present
loc_inline_threshold = 30    # tasks with estimated LOC delta < this run inline (no subagent dispatch); folded into next task's review
loc_subagent_target = 100    # advisory: tasks well below this are merge candidates in consolidation pass
phase_threshold = 15         # plans with more tasks than this get auto-batched into phases if no explicit phase headers
```

## Bundled References

Format specs and large literal templates live next to this skill. Read them only when you reach the matching step:

- `references/checklist-format.md` - markdown shape of every checklist file (header, decisions, phase blocks, gates, verification block, next-file pointer)
- `references/per-session-plan-format.md` - shape of `plan-N.md` files in multi-session mode
- `references/terminal-summary.md` - end-of-run summary printed to user
- `references/session-breakdown-prompt.md` - interactive prompt for >20-task plans
- `references/synthetic-tasks/integration-test.md` - injected when convertibility analysis says yes
- `references/synthetic-tasks/codex-browser-verify.md` - injected per checklist when UI work present
- `references/synthetic-tasks/deferred-resolution.md` - injected at end of every checklist

## Triggers

- User invokes `/preflight <plan-path>` on any plan file.
- Not auto-chained from writing-plans - user reviews plan first, then explicitly invokes preflight.

## Input

Path to plan file. Preferred location: `docs/specs/YYYY-MM-DD-<feature>/plan.md`. Works on any markdown plan with task and phase sections.

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
```

If the plan file is NOT already inside a feature folder, preflight derives `docs/specs/YYYY-MM-DD-<feature>/` from the plan's filename, creates it, moves the plan in as `plan.md`, and moves any sibling `design.md` or `*-design.md` along with it. Prints `Relocated plan to <new-path>. Feature folder: <folder>.` and continues with the relocated path.

If the plan is already inside a feature folder, skip relocation.

## Output

**Single-session plans** (total tasks <= `single_file_cap`): write `<feature-folder>/checklist.md`. `plan.md` stays as-is; fly reads it directly for task content.

**Multi-session plans** (> `single_file_cap`): write `plan-1.md`...`plan-K.md` (per-session plan splits) and `checklist-1.md`...`checklist-K.md` (tracking). `plan.md` stays as the frozen audit trail.

**Both cases:** create `<feature-folder>/reviews/` directory; original plan untouched; print terminal summary (see `references/terminal-summary.md`).

Fly reads the checklist for tracking state and the corresponding plan file for task content. Together, the pair is self-contained for the session.

## Overwrite Behavior

If any target checklist file already exists, warn and ask for explicit overwrite confirmation - an existing checklist may contain in-progress `/fly` state.

If the user confirms overwrite, preserve any fills from the existing file(s) only if the plan hasn't changed (same task list). If the plan changed, produce fresh checklists and tell the user their previous progress is in the file(s) they're overwriting.

## Decisions Preflight Makes

Preflight reads the plan and produces decisions for every task/phase before any execution. These are static from `/fly`'s perspective - `/fly` does not make discretionary calls.

### Phase groupings

- Plan has `## Phase N:` headers: respect them.
- Plan has no phases and total tasks > `phase_threshold`: batch related tasks into phases by shared files, dependencies, or domain concern.
- Plan has fewer tasks than threshold: single phase.

### Task consolidation pass

**Principle:** plans from `/superpowers:writing-plans` tend to over-decompose. Every task = one full subagent dispatch (~50k context just to start). Consolidating tightly-coupled adjacent tasks cuts dispatch count without losing audit trail.

Walk the task list in plan order. Look for adjacent tasks (same phase, no tasks between them) that:

- Touch the same files, or are tightly coupled wire-up (e.g., "create hook" + "use hook in component"; "add migration" + "add indexes for migration").
- Together describe one coherent goal in one sentence (if you find yourself writing "do A and also B and also C" with conjunctions, that's a smell - probably don't merge).
- Don't have a review-isolation reason to stay separate (security-adjacent, schema migration, user-facing UX wire-up that benefits from focused review).

Merge greedily: if A+B should merge AND (A+B)+C should also merge, combine all three. Trust your judgment on when a merged group has lost coherence.

**Consolidated model:** highest tier among merged tasks.

**Show user the proposed merges:**

```
Plan has <N> tasks. Proposed consolidations (<M> merges):

- Tasks 2.1 + 2.2 + 2.3 → "Add VenueCache schema + indexes + migration" (LOC ~85)
- Tasks 4.1 + 4.2 → "Wire useWarmVenueCache hook + add to event page" (LOC ~50)
...

Final task count: <N> → <M>. Confirm? (y / n / edit per-merge)
```

On confirmation, write the consolidated task list with comma-separated provenance in the IDs (e.g., `### Task 2.1+2.2+2.3:`). On "n", use original list. On "edit", let user remove specific merges.

Run BEFORE per-task model assignment, review policy, and convertibility analysis - all downstream decisions operate on the post-consolidation list. Always run, regardless of plan size.

### LOC estimation + inline mode

**Why:** every subagent dispatch costs ~5-20k tokens just to boot (re-read CLAUDE.md, AGENTS.md, docs/ai/*, plan, target files) before doing work. For tiny tasks, that boot cost dwarfs the actual work. Inline mode skips dispatch entirely - the orchestrator does the Edit/Write directly using already-loaded context.

For each task (post-consolidation), estimate LOC delta:

- Count code in fenced ``` ``` ``` blocks the plan provides verbatim (usually transcribed near 1:1).
- Read prose steps for approximate scope: "add X validation" ≈ 10-20 LOC; "extract helper" ≈ 30-50 LOC; "create new component" ≈ 80-200 LOC; "wire prop through 3 layers" ≈ 30-60 LOC.
- Test files inflate LOC. Weight tests at ~0.5x for the threshold check, but include full count in the estimate.
- Estimate is rough (±50%). Advisory signal, not hard gate.

Then assign:
- LOC < `loc_inline_threshold` (default 30) → `Mode: inline`. Orchestrator does work directly; reviewer dispatch unchanged.
- LOC >= threshold → `Mode: subagent` (default).

**Tail-inline edge case:** if the last task in a phase is inline, fold its review into the PREVIOUS non-inline task's review. If the entire phase is inline (rare), upgrade the smallest inline task to subagent so the phase has at least one review anchor.

**Synthetic tasks** (integration-test, codex-browser-verify, deferred-resolution) always run as subagents - never inline.

**Surface LOC in consolidation output:** include estimated LOC per task and per merged group. Tasks well under `loc_subagent_target` (100) are stronger merge candidates.

### Per-task model assignment

- **sonnet** (DEFAULT) - most tasks. Multi-file changes, integration, pattern matching, endpoints, services. Also for tasks that seem simple but touch test infrastructure or shared utilities.
- **haiku** - ONLY for truly trivial single-file tasks with zero integration risk. When in doubt, sonnet. Haiku often gets things wrong on anything non-trivial, wasting a review cycle.
- **opus** - architecture decisions, broad codebase understanding, subtle correctness, high blast-radius.

The cost of a haiku mistake + re-dispatch + re-review exceeds the savings from using haiku in the first place.

### Review policy per task

- `combined` (DEFAULT) - ONE reviewer covering both spec + code concerns in a structured prompt. Halves per-task review dispatches without losing independence.
- `separate` - spec-reviewer + code-reviewer as two dispatches. Use only for high-risk tasks: opus implementer, security-adjacent, schema migration, broad blast-radius.
- `phase` - skip per-task review; the phase-end normal review picks this task up alongside any other `Review: phase` tasks. Use for genuinely trivial tasks where individual review is overkill but you don't want the work entirely unreviewed.

When in doubt, `combined`.

### Phase normal review (conditional)

If any task in a phase is annotated `Review: phase`, the phase gets a normal code-review at its end (after the regression check), covering the cumulative diff of all `Review: phase` tasks in that phase.

If no task in the phase has `Review: phase`, no phase-level review runs - skip directly to the next phase.

### Reviewer model per gate

Defaults: spec=haiku, code=sonnet, normal-phase=sonnet. Upgrade one tier when the task/phase is complex (multi-file, subtle correctness, broad scope, high blast-radius). If implementer is opus, code reviewer is at least opus. `/deep-review` owns its own model logic; preflight does not override.

### Phase end-of-phase regression check (no review gate)

Phases do NOT get their own `/deep-review` gate. Per-phase deep-review burns context redundantly when one session-end deep-review can cover the same diff at lower total cost. Phases still run a regression check (run tests, no subagent dispatch) to catch breakage early.

### Session deep-review gate (always)

Every checklist gets exactly ONE `/deep-review` at the end of the session, covering the cumulative diff for all that session's tasks.

Multi-session plans: each `checklist-N.md` has its own session-end deep-review covering THAT session's diff. They don't share or chain.

### Deep-review coverage invariant

**Every task's code must be in the session-end deep-review's scope.** Trivially satisfied: the session deep-review's scope is the cumulative diff of every task in the session. No task escapes coverage.

### Multi-file split logic

If `total_task_count <= single_file_cap`: single `checklist.md`. No plan split. Fly reads `plan.md` directly.

If `total_task_count > single_file_cap`: compute `K = ceil(total_task_count / single_file_cap)`. Emit K paired files: `plan-1.md`/`checklist-1.md` ... `plan-K.md`/`checklist-K.md`.

Splitting principles:
1. Respect plan phase boundaries; never split a phase across files if it fits within `single_file_cap`.
2. If a single phase exceeds `single_file_cap`, split at task boundaries and emit warning: `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.`
3. Each `checklist-N.md` has its OWN session-end deep-review gate covering only its own session's diff.
4. Per-session plan files are self-contained (goal, conventions, key references, verbatim task content).

### TDD audit

For each task, check whether the task has a `write failing test` + `verify test fails` step pair before any implementation step.

- Present: copy plan's step titles into checklist unchanged.
- Absent: inject two extra checkboxes into the checklist (NOT into the plan) at the top of the task's step list, prefixed with `[INJECTED]`:
  - `[INJECTED] Write failing test for <task description>`
  - `[INJECTED] Run test, verify FAIL`

The plan file is never modified. `/fly` instructs implementers to honor both plan steps and `[INJECTED]` checklist-only steps.

### Manual-test convertibility analysis

For each phase, sweep ALL manual verification work the plan calls out. Sources:
- "Phase end-state test" paragraphs.
- Plan tasks tagged `Model: manual` or that are clearly manual click-throughs (titles like "Manual browser verification", steps that say "navigate", "click", "verify visually"). writing-plans sometimes injects these as full tasks rather than as end-state paragraphs - sweep both shapes.

Apply this principle to every step:

> **Could a competent engineer write a deterministic automated test for this, given mocks/fakes/fixtures/date-injection/cache-busting/etc.?** If yes, write the test. Only truly unmockable steps (real third-party drift, real perf under load, visual fidelity vs mockup, anything codex's native browser also can't catch) remain manual.

For each phase:

1. Classify each verification step as **convertible** or **truly-manual**.
2. Decide whether to inject a synthetic integration test. Inject ONLY when the phase has multi-task glue worth asserting in jsdom-style tests. **Default: when in doubt, SKIP.** False-green synthetic tests look like coverage but aren't. Skip rules + full body: `references/synthetic-tasks/integration-test.md`.
3. Surface proposed injections to user before writing checklist (see the prompt in `references/synthetic-tasks/integration-test.md`).
4. For phases that survive: inject a synthetic task at END of phase (after last plan task, before phase end-state verification block). Distinguished with `[SYNTHETIC: integration-test]` prefix.
5. Truly-manual steps stay in the Phase end-state verification block under `Residual manual test:`. Verification tag is binary: `tests-only` if no residual; `has-residual` if some. The end-of-session codex-browser-verify synthetic task handles most residual; the deferred-resolution task ALWAYS composes a "Try it yourself" walkthrough when the diff has user-facing surface (REQUIRED for `has-residual`, OPTIONAL eyeballing for `tests-only`).
6. If a manual verification TASK in the plan is fully covered by the synthetic test (or by existing phase tests), drop the original task from the consolidated checklist. Note in Decisions block: "Task <N> (<title>) folded into <new synthetic task>."

If a phase has NO verification steps in the plan, skip injection.

### Codex-browser-verify synthetic task

Per-checklist UI-presence check. Inject ONLY when THIS checklist's session has actual browser-verifiable work (mounts UI, modifies UI flow, has a click/navigate/observe step). Backend-only / foundations / pure-infra sessions: omit the task entirely from the checklist - don't inject and then skip at runtime.

Multi-session split: per-checklist decision, not feature-level. Session 1 = backend foundations → no task. Session 2 = UI wire-up → task.

Skip entirely if `codex_browser_enabled = false`.

Full task body: `references/synthetic-tasks/codex-browser-verify.md`.

### Deferred resolution synthetic task

Always inject `[SYNTHETIC: deferred-resolution]` at the end of EVERY checklist (after the Session Gate, before Fly Verification). Multi-session: each `checklist-N.md` gets its own so each session clears its own backlog.

The injected task is a no-op when deferred.md is absent or empty, so it's safe to always inject.

Full task body (with prompt for the user-facing block format including the mandatory "User-facing impact:" line): `references/synthetic-tasks/deferred-resolution.md`.

### Configurable thresholds

All thresholds are tunable by editing constants at the top of this skill. Most projects don't need to touch them; the defaults match a 1M-context opus-tier session.

## Steps

### 1. Read the plan

Read the plan file at the given path. Identify:
- Phase sections (`^## Phase N:` or `^## Phase N `).
- Task sections (`^### Task N:` within phases, or top-level if no phases).
- Step checkboxes (`^- \[ \] (Step N: )?`).
- Step titles.

If no phase sections, collect tasks as a flat list - phase grouping happens in step 2.

### 2. Compute decisions

Apply the decision logic in "Decisions Preflight Makes" to the parsed plan, in this order:

1. **Phase grouping** - plan's phases if present; else batch if total tasks > threshold; else single phase.
2. **LOC estimation (pre-consolidation pass)** - feeds the consolidation pass.
3. **Task consolidation pass (interactive)** - judgment-based greedy merge with user confirmation. Always run.
4. **LOC re-estimation + inline mode** - after consolidation, tag each task `Mode: inline` or `Mode: subagent`. Synthetic tasks always `subagent`.
5. **Per-task model** - haiku/sonnet/opus.
6. **Review policy** - default `combined`. Mark genuinely trivial tasks `phase` to defer review to phase-end. Inline-mode tasks default to `combined` like subagent tasks (only implementer dispatch is skipped, reviewer dispatch still runs).
7. **Reviewer models per gate** - apply defaults with per-task upgrades.
8. **Phase end-of-phase regression check** - run-tests-only gate. No reviewer subagent.
9. **Session deep-review gate** - exactly one `/deep-review` at the end of every checklist.
10. **TDD audit** - mark tasks needing injection.
11. **Multi-file split** - if total task count > `single_file_cap`, compute K and allocate phases/tasks to files 1..K.
12. **Phase verification tagging** - tests-only or has-residual based on convertibility analysis.
13. **Manual-test convertibility analysis** - classify each verification step; inject synthetic integration-test task if any convertible (with user confirmation prompt).
14. **Plan split preparation** - for multi-session plans, prepare per-session plan files. Synthetic tasks count toward `single_file_cap`.
15. **Codex-browser-verify** - inject ONE per checklist ONLY if THIS session has UI work AND `codex_browser_enabled = true`. Per-checklist check, not feature-level. Omit from checklist entirely when not needed.
16. **Deferred resolution synthetic task** - inject one at the end of EVERY checklist.

### 2b. Propose session breakdown (interactive - plans with > single_file_cap tasks only)

For plans with more than `single_file_cap` (default 20) tasks, present the user with a session breakdown before writing any files. Prompt template: `references/session-breakdown-prompt.md`. Wait for the user's response, then proceed to write files matching the chosen split.

For plans with `single_file_cap` or fewer tasks, skip this step.

### 2c. Read design.md (if present)

If `design.md` exists in the feature folder:

1. Read it and extract the 2-3 sentence summary from the top (usually Goal or Overview).
2. For phases involving architectural decisions (new components, state machines, data flow), identify relevant design.md sections for targeted extraction into plan-N.md files (multi-session) or left in plan.md for fly to read (single-session).

Do NOT dump the full design.md into any output file. Only extract targeted context.

### 3. Check for existing output files

Compute output path(s):
- Single-session: `<feature-folder>/checklist.md`.
- Multi-session: `<feature-folder>/plan-1.md` ... `plan-K.md` and `<feature-folder>/checklist-1.md` ... `checklist-K.md`.

If any checklist output file exists with ticked checkboxes or filled `<fill>` slots, warn: "Checklist file(s) exist with in-progress state. Overwrite? (y/n)". On confirm-with-same-task-list, consider preserving prior fills - when in doubt, fresh-write and tell the user.

### 4. Write the output files

**Multi-session:** First write `plan-1.md` ... `plan-K.md` per `references/per-session-plan-format.md`. Then write `checklist-1.md` ... `checklist-K.md` per `references/checklist-format.md`.

**Single-session:** Write only `checklist.md` per `references/checklist-format.md`. No plan split.

### 5. Print terminal summary

Per `references/terminal-summary.md` (single-session and multi-session templates).
