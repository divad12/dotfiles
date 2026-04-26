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

### Manual-test convertibility analysis

For each phase, examine the plan's "Phase end-state test" paragraph (and any other manual-verification steps the plan calls out). Apply this principle to every step:

> **Could a competent engineer write a deterministic automated test for this, given mocks/fakes/fixtures/date-injection/cache-busting/etc.?** If yes, write the test. Only truly unmockable steps remain manual.

Examples of mockable: time/date logic (inject `now`, fake timers), cache expiry, external API call counts (mock the client), DB row counts post-action, downstream side effects.

Examples of NOT mockable: real third-party API response shape drift, real perf under load, browser-side runtime where the test environment stubs the real thing (Web Workers in jsdom, IndexedDB quirks), visual/UX smoke.

For each phase:

1. Classify each verification step as **convertible** or **truly-manual**.
2. If ANY convertible steps exist, inject a synthetic task at the END of the phase (after the last plan-supplied task, before the phase end-state verification block):

   ```
   Synthetic task: "Write integration test for Phase <N> end-state verification"
   - Model: sonnet (DEFAULT) — upgrade to opus if any of the convertible steps require subtle setup (e.g., multi-process worker harness, complex mock graph).
   - Review: standard.
   - Files: implementer decides based on existing test conventions.
   - Steps:
     * Step 1: write failing test covering: <list each convertible step verbatim, with the mock/fake/fixture noted>
     * Step 2: verify test fails for the right reason
     * Step 3: implement (only if test fails because the production code is missing the behavior; usually the production code already exists and the test just confirms it - in which case skip to step 4)
     * Step 4: verify test passes
     * Step 5: commit
   ```

   This synthetic task gets treated EXACTLY like any plan task by fly: dispatched by an implementer subagent, reviewed by spec + code reviewers, etc. It's distinguished in the checklist with `[SYNTHETIC: integration-test]` prefix on the task title so reviewers know its provenance.

3. Truly-manual steps stay in the Phase end-state verification block under `Manual test:`. The verification tag becomes:
   - `tests-only` if ALL verification steps were convertible (no residual manual).
   - Original tag (`auto-verify`/`suggest-verify`/`manual-only`) if residual manual steps remain.

If a phase has NO verification steps in the plan, skip injection for that phase. If a phase has steps but ALL are truly-manual, skip injection (no test to write) and tag as `manual-only`.

### Deferred resolution synthetic task

Always inject a single `[SYNTHETIC: deferred-resolution]` task at the very end of the LAST checklist (after the Final Gate, before the Fly Verification block). This task wraps up any items that landed in `<plan>-deferred.md` during fly's run, so fly itself stays mechanical and doesn't burn context classifying/resolving deferred items.

The injected task is a no-op when deferred.md is absent or empty, so it's safe to always inject.

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Review: skip

Goal: process any items in `<plan-basename>-deferred.md` so the user only sees items that actually need their decision (with concrete recommendations).

If `<plan-basename>-deferred.md` is missing or contains zero `## §` entries: print "No deferred items." and exit (task is a no-op).

Otherwise, read every `## §N` entry. For each, classify into ONE bucket:

- **Bucket A - auto-resolvable now.** Item is tractable and only landed in deferred.md because (a) fix-implementer BLOCKED earlier and a fresh attempt with a one-tier upgraded model may succeed, (b) reviewer mis-disposed a tractable nit (didn't fit any of the 3 defer criteria - user decision / phase-sized / extremely risky - but slipped through), or (c) item is a small refactor / extract-helper / typo / dead-code removal that doesn't actually need user input.
- **Bucket B - phase-sized follow-up.** Genuinely too large for inline fix this session, but doesn't need a user decision either - just needs its own future plan/session.
- **Bucket C - needs user decision.** Genuine UX, scope, business-logic, policy, or hard-to-reverse architectural choice that ONLY the user can make.

For each Bucket A item: dispatch implementer (sonnet default; opus if original BLOCK was sonnet) with prompt "Apply this deferred fix: <finding + suggested fix from deferred.md>. File: <path>. Run tests for affected file(s). Commit with message `fix: §N <short title> (deferred resolution)`." If implementer succeeds + tests pass: append `Status: RESOLVED in <SHA>` line to the §N entry in deferred.md. If implementer fails or tests fail: demote item to Bucket C.

For each Bucket B item: prepare a user-facing block (same surfacing as Bucket C - never silently filed). The user decides whether to do it inline now, spawn a separate task for it via the `mcp__ccd_session__spawn_task` tool (chip in CCD UI), or skip. Format:

  ### Follow-up §N: <one-line plain-English title>

  **What it is:** <2-3 sentences in user's terms - what the work would accomplish>

  **Why it's a follow-up:** <why this didn't fit inline - phase-sized estimate, scope rationale>

  **My recommendation:** <one of: "spawn" / "do now" / "skip">. <1-2 sentences why.>

  **Estimated scope:** <e.g., "~3 tasks, 1-2 hour session" or "single small refactor, ~30 min">

  **Where it lives:** `<file>:<line>` (or `§N` in `<plan-basename>-deferred.md` for full reviewer notes)

For each Bucket C item: prepare a user-facing block in plain language (no reviewer jargon). Format:

  ### Decision §N: <one-line plain-English title>

  **What it is:** <2-3 sentences in user's terms - translate file:line citations into "the X feature does Y when Z" framing>

  **Why it needs you:** <which of the 3 defer criteria + the specific judgment that requires user input>

  **My recommendation:** <Option <letter>>. <1-2 sentences why.>

  **Options:**
  - **A. <short title>:** <what it would mean + tradeoff>
  - **B. <short title>:** <what it would mean + tradeoff>
  - (C if applicable)

  **Where it lives:** `<file>:<line>` (or `§N` in `<plan-basename>-deferred.md` for full reviewer notes)

After all buckets processed, print this summary at the end of the task return value (this is what fly surfaces to user):

  Deferred resolution summary:
  - Auto-resolved: <X> items (<sha-list>)
  - Follow-ups (need your call on do-now / spawn / skip): <Y> items
  - Decisions needed (need your input on options): <Z> items

  <If Y > 0:> ## Follow-ups - your call
  <Bucket B blocks here>
  Reply per §N with one of: "do now", "spawn", or "skip".

  <If Z > 0:> ## Decisions needed
  <Bucket C blocks here>
  Reply with letter per §N (e.g., "§1: A, §2: B, §3: skip") to apply.

  <If Y == 0 AND Z == 0:> "No items need your input."

Watch the bucket distribution: if MOST items are Bucket A, note "reviewer was over-deferring; consider tuning". If MOST are Bucket C, the plan touched contested territory - don't artificially reduce Bucket C by reclassifying.

Note: the synthetic task subagent CANNOT call `mcp__ccd_session__spawn_task` itself (subagents lack access to CCD session tools). It returns Bucket B items as data; fly's main context is what offers/invokes the spawn tool when the user picks "spawn".

Plan steps:
- [ ] Step 1: read deferred.md (or no-op if missing/empty)
- [ ] Step 2: classify each §N into A/B/C
- [ ] Step 3: process Bucket A (dispatch implementer per item, update Status)
- [ ] Step 4: format Bucket B blocks (do NOT touch PROGRESS.md - user decides do-now/spawn/skip)
- [ ] Step 5: format Bucket C blocks
- [ ] Step 6: print summary; commit any deferred.md Status updates from Bucket A with message `chore: deferred resolution pass`
```

`Review: skip` because (a) Bucket A items are individually committed by their dispatched implementers (which already follow normal review-on-commit paths if configured), (b) Bucket B/C items don't change code (just docs + summary), and (c) Bucket C surfacing IS the review - the user is the reviewer.

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
10. **Manual-test convertibility analysis** - for each phase, classify each verification step as convertible (write integration test) or truly-manual (cannot be automated). Inject a synthetic integration-test task at end of phase if any steps are convertible. Recompute the phase verification tag based on residual manual steps. See "Manual-test convertibility analysis" above.
11. **Plan split preparation** - for multi-session plans (>single_file_cap tasks), prepare per-session plan files. Extract Shared Context material (goal, conventions, key references) from plan-level sections. For each session, determine which tasks and phases belong to it. The synthetic integration-test tasks (from step 10) count toward `single_file_cap` and are placed in the same session as the phase they cover. For single-session plans, no split needed (fly reads plan.md directly).
12. **Deferred resolution synthetic task** - always inject one `[SYNTHETIC: deferred-resolution]` task at the very end of the LAST checklist (after Final Gate, before Fly Verification block). See "Deferred resolution synthetic task" above. Counts toward `single_file_cap` for the last session only.

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

**Synthetic integration-test task** (injected by step 10 if any verification steps were convertible). Lives at the END of the phase's task list, AFTER all plan-supplied tasks and BEFORE the phase end-state verification block:

```markdown
### Task <N>.synthetic-test [SYNTHETIC: integration-test] | Model: sonnet | Review: standard

Goal: write integration test covering Phase <N> end-state verification (auto-generated from plan's manual test steps).

Convertible steps to cover:
- <step 1 verbatim from plan, with mock/fake/fixture noted>
- <step 2 verbatim from plan, with mock/fake/fixture noted>
- ...

Plan steps:
- [ ] Step 1: write failing integration test covering the steps above
- [ ] Step 2: run test, verify FAIL for the right reason
- [ ] Step 3: implement (only if production code missing - usually skip)
- [ ] Step 4: run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

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

Phase end-state verification block (before the phase gate, at the end of each phase's tasks - AFTER any synthetic integration-test task):

```markdown
### Phase <N> end-state verification
- Type: <auto-verify | suggest-verify | manual-only | tests-only>
- Automated coverage: synthetic integration test (Task <N>.synthetic-test) covers: <list of convertible steps> | none
- Residual manual test: <list of truly-manual steps that the integration test cannot cover, with brief rationale per item> | none (all steps automated)
- Automated: tests pass (handled by phase-regression.sh)
```

Verification type tagging rules (re-evaluated AFTER convertibility analysis):
- `tests-only`: ALL verification steps were convertible to integration tests (no residual manual). Most common outcome with the convertibility analysis.
- `auto-verify`: residual manual steps exist AND involve a simple browser render check (page loads, component exists).
- `suggest-verify`: residual manual steps exist AND need multi-step browser interaction.
- `manual-only`: residual manual steps involve live network, external APIs, real perf under load, or deployment ops that fundamentally cannot be mocked.

Preflight determines the tag from the residual-manual list. When in doubt, default to `suggest-verify`.

If the plan has no "Phase end-state test" paragraph for a phase, both lines read: `(none specified in plan)`.

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

### Deferred resolution task (LAST file only in split mode; always present in single-file mode)

Inserted AFTER the Final Gate block and BEFORE the Fly Verification block. Always injected. See "Deferred resolution synthetic task" in Decisions for the full task body. Brief skeleton:

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Review: skip

Goal: classify deferred items into auto-resolvable / phase-sized-followup / needs-user-decision; auto-fix or document the first two; surface only the third to the user with recommendations. (See preflight skill for full prompt.)

Plan steps:
- [ ] Step 1: read `<plan-basename>-deferred.md` (no-op if missing/empty)
- [ ] Step 2: classify each §N
- [ ] Step 3: process Bucket A (auto-resolve)
- [ ] Step 4: process Bucket B (track in PROGRESS.md)
- [ ] Step 5: format Bucket C for user
- [ ] Step 6: print summary; commit deferred.md updates - SHA: `<fill>`
```

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

Format requirements:
- File paths in the single-session case MUST be both an absolute path (for clarity) and a clickable markdown link using the relative path.
- The "Key decisions" section must mirror the `## Decisions` blocks in the checklist file(s).
- The `/fly` command(s) must use the exact relative path(s), copy-paste ready.
- Warnings:
  - `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.` - emit when rule (2) above forced a mid-phase split.
  - Omit the entire Warnings block if no warnings apply.
