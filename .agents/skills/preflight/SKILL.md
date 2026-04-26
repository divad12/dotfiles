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

### Task consolidation pass

**Principle:** plans from `/superpowers:writing-plans` tend to over-decompose. Every task = one full subagent dispatch (~50k context load just to start). Each fly run currently spends a lot of tokens and time on dispatch overhead for tasks that are tightly coupled and could share an implementer. Consolidating tightly-coupled adjacent tasks into one logical unit cuts dispatch count without losing audit trail.

Use your judgment. Walk the task list in plan order. Look for adjacent tasks (same phase, no tasks between them) that:

- Touch the same files, or are tightly coupled wire-up (e.g., "create hook" + "use hook in component"; "add migration" + "add indexes for migration"; "create route" + "wire route to client").
- Together describe one coherent goal in one sentence (if you find yourself writing "do A and also B and also C" with conjunctions, that's a smell - probably don't merge).
- Don't have a review-isolation reason to stay separate (security-adjacent, schema migration that benefits from focused review, user-facing UX wire-up that the reviewer needs to see in isolation).

Merge greedily: if A+B should merge AND (A+B)+C should also merge, combine all three. There's no hard cap; trust your judgment on when a merged group has lost coherence.

**Consolidated model:** highest tier among merged tasks.

**Show user the proposed merges:**

```
Plan has <N> tasks. Proposed consolidations (<M> merges):

- Tasks 2.1 + 2.2 + 2.3 → "Add VenueCache schema + indexes + migration"
- Tasks 4.1 + 4.2 → "Wire useWarmVenueCache hook + add to event page"
...

Final task count: <N> → <M>. Confirm? (y / n / edit per-merge)
```

On confirmation, write consolidated task list with comma-separated provenance in the IDs (e.g., `### Task 2.1+2.2+2.3:`) so the plan trail stays auditable. On "n", use original list. On "edit", let user remove specific merges.

Run BEFORE per-task model assignment, batched-with, and convertibility analysis - all downstream decisions operate on the post-consolidation list.

Always run, regardless of plan size. Even small plans benefit from saved dispatches.

### LOC estimation + inline mode

**Why:** every subagent dispatch costs ~5-20k tokens just to boot (re-read CLAUDE.md, AGENTS.md, docs/ai/*, plan, target files) before doing work. For tiny tasks, that boot cost dwarfs the actual work. Inline mode skips dispatch entirely - the orchestrator does the Edit/Write directly using already-loaded context.

For each task (post-consolidation), estimate LOC delta. Use judgment based on the plan task text:

- Count code in fenced ` ``` ` blocks the plan provides verbatim (these are usually transcribed near-1:1).
- Read prose steps for approximate scope: "add X validation" ≈ 10-20 LOC; "extract helper" ≈ 30-50 LOC; "create new component" ≈ 80-200 LOC; "wire prop through 3 layers" ≈ 30-60 LOC.
- Test files inflate LOC (mock boilerplate). When task includes both prod + test, weight tests at ~0.5x for the threshold check, but include full count in the estimate.
- Estimate is rough (±50%). Used as advisory signal, not hard gate.

Then assign:
- LOC < `loc_inline_threshold` (default 30) → `Mode: inline`. Orchestrator does work directly. Task's review folds into next non-inline task via `Review: batched-with <next-task-id>`.
- LOC >= threshold → `Mode: subagent` (default). Standard Task-dispatch flow.

**Tail-inline edge case:** if the last task in a phase is inline, fold its review into the PREVIOUS non-inline task's review (since there's no next task). If the entire phase is inline (rare), upgrade the smallest inline task to subagent so the phase has at least one review anchor.

**Synthetic tasks** (integration-test, codex-browser-verify, deferred-resolution) always run as subagents - never inline. They have orchestration logic that benefits from isolation.

**Surface LOC in consolidation output:** when proposing merges (see "Task consolidation pass"), include estimated LOC per task and per merged group. Tasks well under `loc_subagent_target` (100) are stronger merge candidates.

### Per-task model assignment

Assign one of `haiku` / `sonnet` / `opus` per task based on complexity signals in the task text:

- **sonnet** (DEFAULT) - most tasks. Multi-file changes, integration, pattern matching, endpoints, services. Also use for tasks that seem simple but touch test infrastructure or shared utilities.
- **haiku** - ONLY for truly trivial single-file tasks with zero integration risk (e.g., adding one config line, updating a version string, pure docs edits). When in doubt, use sonnet. Haiku often gets things wrong on anything non-trivial, wasting a review cycle.
- **opus** - architecture decisions, broad codebase understanding, subtle correctness concerns, high blast-radius changes.

Default to sonnet. The cost of a haiku mistake + re-dispatch + re-review exceeds the savings from using haiku in the first place.

### Review policy per task

- `combined` (DEFAULT) - dispatches ONE reviewer covering both spec + code concerns in a structured prompt. Halves per-task review dispatches without losing independence.
- `separate` - dispatches spec-reviewer + code-reviewer as two separate dispatches. Use only for high-risk tasks: opus implementer, security-adjacent, schema migration, broad blast-radius, or anything where the spec and code concerns are weighty enough that focused review per concern catches more.
- `batched-with <neighbor-ids>` - groups genuinely trivial adjacent tasks into a single post-batch combined review. Rules:
  - Max batch size: 3 tasks.
  - Tasks must be adjacent in the plan's task order.
  - Each task must be individually trivial (haiku-model-eligible, 1-file scope).
  - The batch's review gate lives on the LAST task in the batch.

When in doubt, use `combined`. Only escalate to `separate` when the task clearly meets a high-risk signal.

### Reviewer model per gate

Defaults: spec=haiku, code=sonnet, normal-phase=sonnet. Upgrade one tier when the task/phase is complex (multi-file, subtle correctness, broad scope, high blast-radius). If implementer is opus, code reviewer is at least opus. `/deep-review` owns its own model logic; preflight does not override.

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
- Compute `K = ceil(total_task_count / single_file_cap)`. Emit `K` paired files: `plan-1.md`/`checklist-1.md` ... `plan-K.md`/`checklist-K.md`.
- **Splitting principles:**
  1. Respect plan phase boundaries; never split a phase across files if it fits within `single_file_cap`.
  2. If a single phase exceeds `single_file_cap`, split at task boundaries and emit a warning: `Phase <N> (<T> tasks) exceeds single_file_cap <cap>; split at task boundaries across files <a>-<b>.`
  3. Per-phase `/deep-review` gates stay on their original phases (which stay together in one file). Final `/deep-review` gate + Fly Verification block live ONLY on checklist `K`.
  4. Per-session plan files are self-contained (goal, conventions, key references, verbatim task content). Together the plan-N + checklist-N pair is self-contained for the session.

(Header / decisions block / next-file pointer formats are spec'd in Checklist Format below.)

### TDD audit

For each task in the plan, check whether the task has a `write failing test` + `verify test fails` step pair before any implementation step.

- If present: copy the plan's step titles into the checklist unchanged.
- If absent: inject two extra checkboxes into the checklist (NOT into the plan) at the top of the task's step list, prefixed with `[INJECTED]`:
  - `[INJECTED] Write failing test for <task description>`
  - `[INJECTED] Run test, verify FAIL`

The plan file is never modified. The injection lives only in the checklist. `/fly` will instruct implementers to honor both plan steps and `[INJECTED]` checklist-only steps.

### Manual-test convertibility analysis

For each phase, sweep ALL manual verification work the plan calls out. Sources to check:
- "Phase end-state test" paragraphs.
- Any plan task tagged `Model: manual` or that's clearly a manual click-through (e.g., titles like "Manual browser verification", "Smoke test", steps that say "navigate", "click", "verify visually"). writing-plans sometimes injects these as full tasks rather than as end-state paragraphs - sweep both shapes.

Apply this principle to every step found:

> **Could a competent engineer write a deterministic automated test for this, given mocks/fakes/fixtures/date-injection/cache-busting/etc.?** If yes, write the test. Only truly unmockable steps (real third-party drift, real perf under load, visual fidelity vs mockup, anything codex's native browser also can't catch) remain manual.

For each phase:

1. Classify each verification step as **convertible** or **truly-manual**.
2. Skip the synthetic if the phase already has an end-to-end test of the wire-up. Unit tests of individual pieces don't count - synthetic exists to catch glue bugs.
3. Otherwise, inject a synthetic task at the END of the phase (after the last plan-supplied task, before the phase end-state verification block):

   ```
   Synthetic task: "Write integration test for Phase <N> end-state verification"
   - Model: sonnet (DEFAULT) — upgrade to opus if any of the convertible steps require subtle setup (e.g., multi-process worker harness, complex mock graph).
   - Review: combined.
   - Files: implementer decides based on existing test conventions.
   - Steps:
     * Step 1: write failing test covering: <list each convertible step verbatim, with the mock/fake/fixture noted>
     * Step 2: verify test fails for the right reason
     * Step 3: implement (only if test fails because the production code is missing the behavior; usually the production code already exists and the test just confirms it - in which case skip to step 4)
     * Step 4: verify test passes
     * Step 5: commit
   ```

   This synthetic task gets treated EXACTLY like any plan task by fly: dispatched by an implementer subagent, reviewed by spec + code reviewers, etc. It's distinguished in the checklist with `[SYNTHETIC: integration-test]` prefix on the task title so reviewers know its provenance.

4. Truly-manual steps stay in the Phase end-state verification block under `Residual manual test:`. Verification tag is binary (`tests-only` if no residual; `has-residual` if some). The end-of-session codex-browser-verify synthetic task (see below) handles most of the residual. The end-of-session deferred-resolution task ALWAYS composes a "Try it yourself" walkthrough when the diff has user-facing surface - REQUIRED steps for `has-residual` phases, OPTIONAL eyeballing steps for `tests-only` phases (visual polish, animations, copy that tests can't verify).

5. If a manual verification TASK in the plan (not a paragraph) is fully covered by the synthetic integration test (or by existing phase tests per step 2), **drop the original task** from the consolidated checklist. Note in Decisions block: "Task <N> (<title>) folded into <new synthetic task>." or "Task <N> covered by existing Task <M>; dropped." Don't leave the redundant task in the checklist for fly to figure out it should skip.

If a phase has NO verification steps in the plan, skip injection for that phase.

### Codex-browser-verify synthetic task

When this session has any phase whose verification involves browser interaction (clicking, navigating, observing UI behavior), inject ONE `[SYNTHETIC: codex-browser-verify]` task per checklist - placed near the end, just BEFORE the deferred-resolution synthetic task. Codex has native browser execution; this synthetic task dispatches codex to do the real-browser equivalent of what the integration test covers in jsdom plus any visual fidelity / runtime concerns jsdom can't catch.

Skip injection if no phase in this session has browser-verifiable work, or if the user's environment doesn't have codex available (set via tunable `codex_browser_enabled = true`; if false, residual manual stuff falls back to Try-it-yourself).

```markdown
### Task final.codex-browser-verify [SYNTHETIC: codex-browser-verify] | Model: codex (external) | Mode: subagent | LOC: ~0 | Review: skip

Goal: dispatch codex with native browser to click through this session's user flows and report critiques (not just PASS/FAIL). Orchestrator fixes the critiques.

For each phase in this session that has browser-verifiable work, codex should:
- Start (or use already-running) dev server.
- Navigate to the relevant page/route.
- Perform the user flow (click, fill, navigate).
- Compare against design intent (if a mockup reference exists in design.md or the plan, codex compares).
- Capture screenshot.
- Return a STRUCTURED LIST of critiques: each entry is `{file_or_area, what's_wrong, suggested_fix}`. PASS = empty critique list.

Codex prompt (orchestrator composes from this session's plan + diff):
"You have native browser. Dev server URL: <url>. For each flow below, click through and report any critiques. Critique format: numbered list, each with location + what's wrong + suggested fix. End with `No critiques.` if everything is fine. Flows: <list extracted per phase>"

Plan steps:
- [ ] Step 1: dispatch codex with browser-verify prompt
- [ ] Step 2: parse codex's critique list
- [ ] Step 3: for each critique, dispatch implementer (sonnet) to fix; commit
- [ ] Step 4: re-dispatch codex to verify fixes (loop until `No critiques.` or 2 rounds max - then surface remaining to user)
- [ ] Step 5: append final pass/critique summary to checklist
```

`Review: skip` because codex IS the reviewer and the orchestrator's fix-loop IS the resolution.

### Deferred resolution synthetic task

Always inject a `[SYNTHETIC: deferred-resolution]` task at the end of EVERY checklist (single-session: after the Final Gate, before Fly Verification; multi-session: end of each `checklist-N.md` so each session clears its own backlog before handing off). This task wraps up any items that landed in `<plan>-deferred.md` during this session's run, so fly itself stays mechanical and doesn't burn context classifying/resolving deferred items.

For multi-session plans: each session's deferred-resolution task processes ALL §N entries currently in `<plan>-deferred.md` (sessions append to the same file across runs; previously-resolved entries already have `Status: RESOLVED in <SHA>` lines and are skipped). The user gets per-session "needs your input" prompts and "Try it yourself" walkthroughs, not a giant pile at the end of session K.

The injected task is a no-op when deferred.md is absent or empty, so it's safe to always inject.

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Mode: subagent | LOC: ~0 | Review: combined

Goal: do as much of the deferred work as possible automatically; surface the rest clearly so the user can decide.

**Why review:** the fix-implementer commits this task lands run AFTER Final Gate / Phase Gates - they have no other reviewer coverage. One combined review at task end covers the cumulative diff (`git diff <task-start-sha>..HEAD`) for all auto-resolved §N fixes. If zero §N entries auto-resolved (all surfaced to user, none dispatched), the reviewer sees an empty diff and emits `No issues.`.

If `<plan-basename>-deferred.md` is missing or contains zero `## §` entries: print "No deferred items." and skip to the "Try it yourself" section below.

Otherwise, for each `## §N` entry, try to resolve it. If you can fix it without needing user input (BLOCKED-on-model item now tractable with upgraded model, reviewer mis-disposed a fixable nit, small refactor/typo/dead-code, anything else you have enough context to just do): dispatch an implementer (sonnet default; opus if original BLOCK was sonnet) with the finding + suggested fix + file path; run tests; commit with message `fix: §N <short title> (deferred resolution)`; append `Status: RESOLVED in <SHA>` to the §N entry in deferred.md.

If you CAN'T fix it (genuine UX/scope/policy decision, hard-to-reverse architectural choice, work that needs its own future session): surface to the user. Use plain language - translate file:line citations into "the X feature does Y when Z" framing. For each unresolved §N, write:

  ### §N: <plain-English title>

  **What it is:** <2-3 sentences in user's terms>
  **Why I didn't just do it:** <one short sentence - decision needed / too large for this session / risky>
  **My recommendation:** <what you'd do + 1 sentence why>
  **Options:** <list, OR "do now" / "spawn separate task" / "skip" if it's a follow-up rather than a decision-with-options>
  **Where:** `<file>:<line>` (full reviewer notes in `§N` of `<plan-basename>-deferred.md`)

After processing, return:

  Deferred resolution summary:
  - Auto-resolved: <X> items (<sha-list>)
  - Need your input: <Y> items (see below)

  <If Y > 0:> [list of §N blocks above]
  Reply per §N with your pick (e.g., "§1: A", "§2: spawn", "§3: skip") - I'll apply.

  <If Y == 0:> "No items need your input."

  ## Try it yourself
  <ALWAYS compose this section if the diff touches any user-facing surface (UI, CLI output, API response shape). Don't skip just because phases were `tests-only`. Read `Residual manual test` lines across phases + diff context (route paths, hook names, button labels, command examples).

  Two flavors based on phase tags:
  - **Required** - if any phase was `has-residual`, those steps are the load-bearing manual verification. Lead with them.
  - **Optional** - if all phases were `tests-only`, prefix the section with "Optional - integration tests cover the behavior; this is for eyeballing visual polish, copy, animations, and anything tests can't see."

  Aim for the clarity of a coworker's "here's what I'd click to verify this shipped" message, not a checklist. Always note what tests already cover so the user knows what they're adding by clicking through.>
  <Omit only if the diff has zero user-facing surface (e.g. pure refactor, infra-only change). In that case write: "No manual verification - diff is internal only.">

Note: subagents can't call `mcp__ccd_session__spawn_task` directly. If a §N's recommendation is "spawn", return it as data; fly's main context invokes the spawn tool when the user picks it.

Plan steps:
- [ ] Step 1: read deferred.md (no-op if missing/empty)
- [ ] Step 2: for each §N, try to resolve (dispatch + commit) OR format as user-facing block
- [ ] Step 3: compose "Try it yourself" walkthrough from residual manual items (if any)
- [ ] Step 4: print summary; commit any deferred.md Status updates with message `chore: deferred resolution pass`
```

`Review: skip` because resolved fixes are individually committed by their dispatched implementers, and unresolved items surface to the user (the user IS the reviewer).

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
2. **LOC estimation (pre-consolidation pass)** - estimate LOC delta per task per "LOC estimation + inline mode". Feeds the consolidation pass (small-LOC adjacent tasks are stronger merge candidates).
3. **Task consolidation pass (interactive)** - judgment-based greedy merge of over-decomposed adjacent tasks per "Task consolidation pass". Show user the proposed merges WITH per-task and per-merged-group LOC estimates; on confirmation, write the consolidated task list. Always run.
4. **LOC re-estimation + inline mode** - after consolidation, re-estimate LOC for merged groups; tag each task `Mode: inline` (LOC < `loc_inline_threshold`) or `Mode: subagent`. Synthetic tasks always `subagent`.
5. **Per-task model** - read each task's text and classify into haiku/sonnet/opus.
6. **Review policy** - default `combined`; mark adjacent trivial tasks as `batched-with <neighbors>` (max batch size 3). Inline-mode tasks get the same review policy as subagent-mode (default `combined`); only the implementer dispatch is skipped, the reviewer dispatch still runs.
7. **Reviewer models per gate** - apply defaults with per-task upgrades.
8. **Phase review gates** - default `/deep-review` for every phase. Downgrade to `normal` only for trivially small phases (<=3 haiku tasks, single-concern). See "Phase review gate" for the downgrade rule.
9. **Final review gate** - needed only if any phase was downgraded to normal (rare with default-deep). Skipped when all phases have `/deep-review` coverage (the common case).
10. **TDD audit** - for each task, check for failing-test steps; mark tasks needing injection.
11. **Multi-file split** - if total task count > `single_file_cap`, compute `K` and allocate phases/tasks to files 1..K per the splitting rules.
12. **Phase verification tagging** - tests-only or has-residual based on convertibility analysis (step 13).
13. **Manual-test convertibility analysis** - for each phase, classify each verification step as convertible (write integration test) or truly-manual. Inject synthetic integration-test task if any convertible. See "Manual-test convertibility analysis" above.
14. **Plan split preparation** - for multi-session plans (>single_file_cap tasks), prepare per-session plan files. Synthetic tasks count toward `single_file_cap`. For single-session plans, no split needed.
15. **Codex-browser-verify synthetic task** - if any phase in this session has browser-verifiable work AND `codex_browser_enabled = true`, inject ONE `[SYNTHETIC: codex-browser-verify]` task per checklist (placed near end, before deferred-resolution).
16. **Deferred resolution synthetic task** - inject one `[SYNTHETIC: deferred-resolution]` task at end of EVERY checklist (single-session: after Final Gate, before Fly Verification; multi-session: end of each checklist-N.md so each session clears its own backlog).

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
- LOC distribution: avg <N>, median <N>; inline <X>, subagent <Y>; smallest <id>=<N>, largest <id>=<N>
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
### Task <id> | Model: <haiku|sonnet|opus> | Mode: <inline | subagent> | LOC: ~<N> | Review: <combined | separate | batched-with <neighbor-ids>>

Plan steps:
- [ ] Step 1: <title extracted from plan>
- [ ] [INJECTED] <injected step title, if any>
- [ ] Step N: Commit - SHA: `<fill>`

Review gates:
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`

(For tasks with `Review: separate`, use the legacy two-block format: `Spec review` + `Spec review resolution` + `Code review` + `Code review resolution`.)

(For tasks with `Mode: inline`, KEEP the Review gates block exactly as for subagent mode. The orchestrator does the implement, but a reviewer subagent still reviews the diff. Only the implementer dispatch is skipped.)
```

No **Files:** block, no embedded task text, no code blocks. Fly reads task content from the plan file (plan.md for single-session, plan-N.md for multi-session).

**Synthetic integration-test task** (injected by step 11 if any verification steps were convertible). Placement: at the end of the phase's impl tasks, but BEFORE any "final cleanup" task that audits the phase's work (signals: last task, looks like cleanup/audit/summary commit/typecheck-lint-build smoke). Use your judgment on which task is the cleanup. Goal: cleanup audits the test file too, and the integration test runs against complete impl. If no cleanup task exists, append after the last impl task:

```markdown
### Task <N>.synthetic-test [SYNTHETIC: integration-test] | Model: sonnet | Mode: subagent | LOC: ~<N> | Review: combined

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
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`

(For tasks with `Review: separate`, use the legacy two-block format: `Spec review` + `Spec review resolution` + `Code review` + `Code review resolution`.)
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
- Type: <tests-only | has-residual>
- Automated coverage: synthetic integration test covers: <list of convertible steps> | none
- Residual manual test: <list of truly-manual steps with brief rationale per item> | none (all steps automated)
```

Tag is binary:
- `tests-only`: ALL verification steps were convertible (no residual manual). Most common outcome.
- `has-residual`: at least one truly-manual step remains. The end-of-run synthetic deferred-resolution task surfaces these to the user as the "Try it yourself" walkthrough.

If the plan has no "Phase end-state test" paragraph for a phase, both lines read `(none specified in plan)` and tag is `tests-only`.

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

### Deferred resolution task (every checklist file)

Inserted at the end of EVERY checklist (single-session: after Final Gate, before Fly Verification; multi-session: end of each checklist-N.md so each session clears its own backlog). Always injected. See "Deferred resolution synthetic task" in Decisions for the full task body. Brief skeleton:

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Review: combined

Goal: do as much of the deferred work as possible automatically; surface the rest clearly with recommendations. Also compose "Try it yourself" walkthrough for residual manual verification. (See preflight skill for full prompt.)

Plan steps:
- [ ] Step 1: read `<plan-basename>-deferred.md` (no-op if missing/empty)
- [ ] Step 2: for each §N, try to resolve OR format as user-facing block
- [ ] Step 3: compose "Try it yourself" walkthrough from residual manual items
- [ ] Step 4: print summary; commit deferred.md Status updates - SHA: `<fill>`

Review gates:
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`
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
