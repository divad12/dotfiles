# Preflight + Fly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build two custom skills (`/preflight` and `/fly`) in `.claude/skills/` per [the design spec](../2026-04-17-preflight-and-fly-design.md), so that plan execution gains structural discipline (explicit commitment contract, dynamic model/review-gate assignment, auto-fix, final verification) without modifying upstream superpowers skills.

**Architecture:** Each skill is a single `SKILL.md` file in its own directory. `/preflight` is a markdown transformer (reads plan → writes checklist file + terminal summary). `/fly` is an execution orchestrator (reads checklist + plan → dispatches subagents using Glob-resolved upstream prompt templates → fills slots → verifies). Two supporting sample fixtures drive integration testing. No supporting code files, no separate templates in our skills dir (templates are resolved at runtime from the plugin cache).

**Tech Stack:** Markdown (skill definitions), bash (structural checks via grep), real plans from a sibling project for end-to-end integration testing.

---

## TDD Note

Skills in this repo are markdown instructions executed by an AI, not conventional code. Traditional unit-test TDD doesn't cleanly apply. This plan uses a pragmatic equivalent:

- **Structural tests** (scripted, via grep): confirm required sections/frontmatter exist in SKILL.md. These serve as regression guards but don't verify behavior.
- **Fixture-driven integration tests** (manual, run in a Claude session): run the skill on a sample plan/checklist and compare output to an expected fixture. This is the real validation.
- **End-to-end real-plan test** (manual, at the end): run both skills on an actual pending plan from a sibling project.

This is an explicit deviation from the global rule of strict test-first TDD. Rationale: skills ARE the tested artifact; their "tests" are prose instructions' effectiveness when an AI follows them, which isn't easily unit-testable. Structural + integration testing is the closest meaningful analogue.

---

## File Structure

Files created by this plan:

```
.claude/skills/preflight/
  SKILL.md                                     ← main skill definition
  tests/
    samples/sample-plan.md                     ← input fixture
    expected/sample-plan-checklist.md          ← expected output fixture
    structural-check.sh                        ← grep-based structural regression test

.claude/skills/fly/
  SKILL.md                                     ← main skill definition
  tests/
    samples/sample-checklist.md                ← input fixture (for dry-run validation)
    structural-check.sh                        ← grep-based structural regression test
```

Files modified:

```
SKILLS.md                                      ← add /preflight and /fly to invocation graph
```

Directory rationale: each skill owns its own `tests/` subdir to keep fixtures co-located with the skill they exercise. `samples/` is inputs, `expected/` is outputs, `structural-check.sh` is the grep-based regression guard.

---

## Phase 1: Scaffolding and Fixtures

### Task 1.1: Create skill directories and skeleton SKILL.md files

**Files:**
- Create: `.claude/skills/preflight/SKILL.md`
- Create: `.claude/skills/fly/SKILL.md`

- [ ] **Step 1: Write the failing structural test for preflight skeleton**

Create `.claude/skills/preflight/tests/structural-check.sh`:

```bash
#!/bin/bash
# Structural regression test for /preflight skill
set -e
SKILL=.claude/skills/preflight/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: preflight$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Preflight$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

echo "OK: preflight structural check passed"
```

Make executable: `chmod +x .claude/skills/preflight/tests/structural-check.sh`

- [ ] **Step 2: Run test to verify it fails**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: FAIL with `$SKILL missing`

- [ ] **Step 3: Create preflight skeleton**

Create `.claude/skills/preflight/SKILL.md`:

```markdown
---
name: preflight
description: "Use when preparing an implementation plan for disciplined execution, typically after /superpowers:writing-plans and before /fly. Triggers: 'preflight', 'checklist the plan', 'prep for execution', or when given a plan file path to process."
argument-hint: [path to plan file]
user-invocable: true
---

# Preflight

Transform a plan file into a checklist contract that `/fly` executes.

(Skill body to be filled in later tasks.)
```

**Description rationale:** Triggering conditions only — no summary of what the skill does internally. Per `superpowers:writing-skills` guidance: descriptions that summarize workflow cause Claude to follow the description instead of reading the skill body. Keeping it to "Use when..." + triggers preserves the skill content as load-bearing.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: `OK: preflight structural check passed`

- [ ] **Step 5: Repeat for /fly**

Create `.claude/skills/fly/tests/structural-check.sh`:

```bash
#!/bin/bash
# Structural regression test for /fly skill
set -e
SKILL=.claude/skills/fly/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: fly$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Fly$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

echo "OK: fly structural check passed"
```

Make executable: `chmod +x .claude/skills/fly/tests/structural-check.sh`

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: FAIL (file missing)

Create `.claude/skills/fly/SKILL.md`:

```markdown
---
name: fly
description: "Use when executing a preflight checklist. Triggers: 'fly', 'launch execution', 'run the checklist', or when given a preflight checklist file path."
argument-hint: [path to checklist file]
user-invocable: true
---

# Fly

Execute a preflight checklist. Walks tasks, dispatches subagents, fills slots, auto-fixes review findings, verifies completion.

(Skill body to be filled in later tasks.)
```

**Description rationale:** Triggering conditions only. Per writing-skills, `/fly` is especially vulnerable to description-as-shortcut: if the description summarized "dispatches subagents, auto-fixes, verifies", Claude might skip the full discipline mechanisms on the assumption they're captured in the description. Keeping it minimal forces Claude to read the body where the commitment contract lives.

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: `OK: fly structural check passed`

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/preflight/ .claude/skills/fly/
git commit -m "preflight+fly: skeleton SKILL.md + structural check scripts"
```

---

### Task 1.2: Create sample plan fixture

**Files:**
- Create: `.claude/skills/preflight/tests/samples/sample-plan.md`

- [ ] **Step 1: Create the sample plan**

This fixture is a small realistic plan that exercises preflight's key decisions: multi-task, with and without explicit TDD steps, varying complexity, a phase structure.

```markdown
# Sample Feature Implementation Plan

> Test fixture for /preflight — do not execute.

**Goal:** Add a CSV export endpoint to the reporting service.

**Architecture:** HTTP endpoint → query builder → CSV serializer → response stream.

**Tech Stack:** Python, FastAPI, pandas.

---

## Phase 1: Schema and Models

### Task 1: Add `exports` table migration

**Files:**
- Create: `db/migrations/005_exports.sql`
- Test: `tests/db/test_005_exports.py`

- [ ] Step 1: Write failing test for table existence
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Write migration SQL
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit

### Task 2: Add Pydantic `ExportRequest` model

**Files:**
- Create: `api/models/export.py`
- Test: `tests/api/test_export_model.py`

- [ ] Step 1: Define model class
- [ ] Step 2: Commit

### Task 3: Add `ExportRow` serializer helper

**Files:**
- Create: `api/serializers/export_row.py`

- [ ] Step 1: Implement serializer
- [ ] Step 2: Commit

## Phase 2: Query and Endpoint

### Task 4: Build query construction module

**Files:**
- Create: `api/services/export_query.py`
- Modify: `api/services/__init__.py`
- Test: `tests/api/services/test_export_query.py`

- [ ] Step 1: Write failing test for query builder
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement query builder
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit

### Task 5: Wire the endpoint with streaming CSV response

**Files:**
- Create: `api/routes/exports.py`
- Modify: `api/main.py` (register route)
- Test: `tests/api/routes/test_exports.py`

- [ ] Step 1: Write integration test hitting the endpoint
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement endpoint with StreamingResponse
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/preflight/tests/samples/sample-plan.md
git commit -m "preflight: sample plan fixture (5 tasks, 2 phases, mixed TDD coverage)"
```

**Notes for future tasks:**
- Task 2 and Task 3 lack explicit `write failing test` steps → preflight's TDD audit must flag and inject
- Tasks are small enough that Task 2 + Task 3 are batching candidates (trivial, adjacent, single-file each)
- Total is 5 tasks, 2 phases — below overwhelm threshold, so final deep-review is viable

---

### Task 1.3: Create expected checklist output fixture

**Files:**
- Create: `.claude/skills/preflight/tests/expected/sample-plan-checklist.md`

- [ ] **Step 1: Write the expected checklist**

This is the output `/preflight` should produce when run on `sample-plan.md`. It encodes every decision we expect preflight to make.

```markdown
# Preflight Checklist: Sample Feature

> **READ FIRST:** `.claude/skills/preflight/tests/samples/sample-plan.md` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on 2026-04-17. Execute with `/fly`.

## Decisions
- 5 tasks across 2 phases
- Deep-review coverage: final deep-review covers all phases (both phases use normal review; plan is under overwhelm threshold)
- Per-task models: Phase 1 → haiku (simple schema/model/helper), Phase 2 → sonnet (integration concerns)
- Review batching: Task 2 + Task 3 batched (trivial, adjacent, single-file each)
- TDD gaps injected: Task 2, Task 3 (plan lacks failing-test steps)
- Octopus: deferred

---

## Phase 1: Schema and Models | Phase gate: normal review (reviewer: sonnet)

### Task 1 (plan §Task 1) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test for table existence
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Write migration SQL
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 2 (plan §Task 2) | Model: haiku | Review: batched-with Task 3 | TDD steps injected

Plan steps:
- [ ] [INJECTED] Write failing test for ExportRequest model
- [ ] [INJECTED] Run test, verify FAIL
- [ ] Step 1 (from plan): Define model class
- [ ] Step 2 (from plan): Commit - SHA: `<fill>`

(No individual review gates - batch review below covers Task 2 + Task 3)

### Task 3 (plan §Task 3) | Model: haiku | Review: batched-with Task 2 | TDD steps injected

Plan steps:
- [ ] [INJECTED] Write failing test for ExportRow serializer
- [ ] [INJECTED] Run test, verify FAIL
- [ ] Step 1 (from plan): Implement serializer
- [ ] Step 2 (from plan): Commit - SHA: `<fill>`

Batch review gate (covers Task 2 + Task 3):
- [ ] Batch review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Batch review resolution - Action: `<fill>`

### Phase 1 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 1 diff - Outcome: `<fill>`
- [ ] Phase 1 gate resolution - Action: `<fill>`

---

## Phase 2: Query and Endpoint | Phase gate: normal review (reviewer: sonnet)

### Task 4 (plan §Task 4) | Model: sonnet | Review: standard

Plan steps:
- [ ] Step 1: Write failing test for query builder
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement query builder
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 5 (plan §Task 5) | Model: sonnet | Review: standard

Plan steps:
- [ ] Step 1: Write integration test hitting the endpoint
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement endpoint with StreamingResponse
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Phase 2 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 2 diff - Outcome: `<fill>`
- [ ] Phase 2 gate resolution - Action: `<fill>`

---

## Final Gate: /deep-review over all phases
- [ ] Outcome: `<fill>`
- [ ] Final gate resolution - Action: `<fill>`

---

## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/preflight/tests/expected/sample-plan-checklist.md
git commit -m "preflight: expected checklist output fixture matching sample-plan.md"
```

---

## Phase 2: Build `/preflight`

### Task 2.1: Write preflight's overview, triggers, and I/O section

**Files:**
- Modify: `.claude/skills/preflight/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/preflight/tests/structural-check.sh` (before the final echo):

```bash
grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## Output$" "$SKILL" || { echo "FAIL: Output section"; exit 1; }
grep -q "^## Overwrite Behavior$" "$SKILL" || { echo "FAIL: Overwrite Behavior section"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: FAIL with `Purpose section`

- [ ] **Step 3: Add sections to SKILL.md**

Replace the `(Skill body to be filled in later tasks.)` placeholder in `.claude/skills/preflight/SKILL.md` with:

```markdown
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
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: `OK: preflight structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/preflight/
git commit -m "preflight: overview, triggers, I/O, overwrite behavior"
```

---

### Task 2.2: Write preflight's decision logic

**Files:**
- Modify: `.claude/skills/preflight/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/preflight/tests/structural-check.sh`:

```bash
grep -q "^## Decisions Preflight Makes$" "$SKILL" || { echo "FAIL: Decisions section"; exit 1; }
grep -q "Phase groupings" "$SKILL" || { echo "FAIL: Phase groupings subsection"; exit 1; }
grep -q "Per-task model assignment" "$SKILL" || { echo "FAIL: Model assignment subsection"; exit 1; }
grep -q "Review policy per task" "$SKILL" || { echo "FAIL: Review policy subsection"; exit 1; }
grep -q "Reviewer model per gate" "$SKILL" || { echo "FAIL: Reviewer model subsection"; exit 1; }
grep -q "Deep-review coverage invariant" "$SKILL" || { echo "FAIL: Deep-review invariant"; exit 1; }
grep -q "TDD audit" "$SKILL" || { echo "FAIL: TDD audit subsection"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: FAIL with `Decisions section`

- [ ] **Step 3: Add Decisions section**

Append to `.claude/skills/preflight/SKILL.md`:

```markdown
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
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: `OK: preflight structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/preflight/
git commit -m "preflight: decision logic (phases, models, gates, TDD audit, invariant)"
```

---

### Task 2.3: Write preflight's steps (checklist generation flow) and terminal summary

**Files:**
- Modify: `.claude/skills/preflight/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/preflight/tests/structural-check.sh`:

```bash
grep -q "^## Steps$" "$SKILL" || { echo "FAIL: Steps section"; exit 1; }
grep -q "^## Terminal Summary$" "$SKILL" || { echo "FAIL: Terminal Summary section"; exit 1; }
grep -q "^## Checklist Format$" "$SKILL" || { echo "FAIL: Checklist Format section"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: FAIL with `Steps section`

- [ ] **Step 3: Add Steps, Checklist Format, and Terminal Summary sections**

Append to `.claude/skills/preflight/SKILL.md`:

```markdown
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
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/preflight/tests/structural-check.sh`
Expected: `OK: preflight structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/preflight/
git commit -m "preflight: steps, checklist format, terminal summary"
```

---

### Task 2.4: Integration test — run preflight on sample fixture, verify matches expected

**Files:** no new files — runs existing fixtures and skill.

- [ ] **Step 1: Run preflight on the sample fixture in a fresh Claude Code session**

Open a new Claude Code session in the dotfiles repo (clean context). Run:

```
/preflight .claude/skills/preflight/tests/samples/sample-plan.md
```

Expected: skill produces `.claude/skills/preflight/tests/samples/sample-plan-checklist.md` and prints a terminal summary.

- [ ] **Step 2: Diff actual output against expected fixture**

Run:

```bash
diff .claude/skills/preflight/tests/samples/sample-plan-checklist.md \
     .claude/skills/preflight/tests/expected/sample-plan-checklist.md
```

Expected: empty output (files match), OR only cosmetic differences that don't change meaning (whitespace, date fields, exact wording of Outcome placeholders).

**Tolerance:** minor wording differences in section headers or Decisions block are acceptable as long as the structural format matches. The test is whether the checklist is semantically equivalent, not byte-identical.

If the diff is large:
- Identify which decision the skill got wrong (e.g., wrong batching, missed TDD injection, wrong model assignment).
- Go back to Task 2.2 or 2.3 and adjust the decision logic wording.
- Re-run preflight and re-diff.

- [ ] **Step 3: Clean up generated test output**

```bash
rm .claude/skills/preflight/tests/samples/sample-plan-checklist.md
```

(We committed the expected version separately; the generated one is disposable.)

- [ ] **Step 4: Record the integration test as a manual procedure**

Append to `.claude/skills/preflight/tests/structural-check.sh`:

```bash

# Integration test: run /preflight on sample-plan.md in a fresh Claude session
# and diff output against tests/expected/sample-plan-checklist.md.
# This test is MANUAL - cannot be automated without a live AI session.
# Procedure:
#   1. Fresh Claude Code session
#   2. /preflight .claude/skills/preflight/tests/samples/sample-plan.md
#   3. diff .claude/skills/preflight/tests/samples/sample-plan-checklist.md \
#           .claude/skills/preflight/tests/expected/sample-plan-checklist.md
#   4. Tolerate minor wording differences; fail on structural/decision mismatch.
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/preflight/
git commit -m "preflight: integration test procedure documented; sample output matches expected"
```

---

## Phase 3: Build `/fly`

### Task 3.1: Write fly's overview, triggers, I/O section

**Files:**
- Modify: `.claude/skills/fly/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/fly/tests/structural-check.sh` (before final echo):

```bash
grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## State Detection$" "$SKILL" || { echo "FAIL: State Detection section"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: FAIL with `Purpose section`

- [ ] **Step 3: Add Purpose, Triggers, Input, State Detection sections**

Replace the `(Skill body to be filled in later tasks.)` placeholder in `.claude/skills/fly/SKILL.md` with:

```markdown
## Purpose

Execute a preflight checklist by:
1. Dispatching implementer subagents using upstream prompt templates (read at runtime from the superpowers plugin cache).
2. Running spec and code reviewers; auto-dispatching fix-implementers on findings.
3. Filling SHA, Outcome, and Resolution slots in the checklist as work progresses.
4. Running phase-level and final review gates per the checklist.
5. Final verification sweep: all boxes ticked, all slots filled, deep-review invariant satisfied.

`/fly` does NOT invoke `superpowers:subagent-driven-development` as a skill. It owns its per-task loop and uses that skill's prompt templates by reading them at runtime.

## Triggers

User invokes `/fly <checklist-path>` - typically in a fresh Claude Code session for clean context.

## Input

- **Primary:** path to a preflight checklist file (produced by `/preflight`).
- **Implicit:** the original plan file referenced in the checklist's `READ FIRST` header. `/fly` reads both - the plan for task content (code, commands, file paths) and the checklist for gates and decisions.

## State Detection

On entry, read the checklist file and classify its state:

- **Fresh run** - all checkboxes are unticked (`- [ ]`) and all slots contain `<fill>`.
- **Mid-flight pickup** - some checkboxes are ticked (`- [x]`) or some slots are non-`<fill>`. Resume from the first unticked checkbox or unfilled slot.
- **Already complete** - every checkbox ticked, every slot filled, verification block ticked. Print "Already complete. Nothing to do." and exit.

Announce the detected mode at start:
- Fresh run: "Flying <checklist>. Mode: fresh run."
- Mid-flight: "Flying <checklist>. Mode: resuming from Task <X.Y>."
- Complete: "Already complete. Nothing to do."
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: `OK: fly structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/fly/
git commit -m "fly: overview, triggers, I/O, state detection"
```

---

### Task 3.2: Write fly's template resolution and per-task loop

**Files:**
- Modify: `.claude/skills/fly/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/fly/tests/structural-check.sh`:

```bash
grep -q "^## Template Resolution$" "$SKILL" || { echo "FAIL: Template Resolution section"; exit 1; }
grep -q "^## Per-Task Loop$" "$SKILL" || { echo "FAIL: Per-Task Loop section"; exit 1; }
grep -q "claude-plugins-official/superpowers/\*/skills/subagent-driven-development" "$SKILL" || { echo "FAIL: Glob pattern missing"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: FAIL with `Template Resolution section`

- [ ] **Step 3: Add Template Resolution and Per-Task Loop sections**

Append to `.claude/skills/fly/SKILL.md`:

```markdown
## Template Resolution

`/fly` dispatches subagents using prompt templates from the superpowers plugin cache. The cache directory contains versioned subdirectories (e.g., `5.0.5`, `5.0.7`), so direct paths are brittle.

Resolve each template at dispatch time:

1. Use the Glob tool with pattern:
   `~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/<template>.md`
2. Glob returns paths sorted by modification time (newest first). Take the first match.
3. Use the Read tool on that path to get the template content.

Templates `/fly` resolves this way:
- `implementer-prompt.md` - used when dispatching implementer subagents
- `spec-reviewer-prompt.md` - used when dispatching spec reviewer
- `code-quality-reviewer-prompt.md` - used when dispatching code reviewer

If Glob returns no match, the plugin cache doesn't contain the templates (upstream rename, new plugin version, cache cleared). Halt and tell the user: "Upstream templates not found at <pattern>. Check plugin install or update the Glob pattern."

## Per-Task Loop

Walk the checklist's tasks in order. For each task:

### A. Dispatch implementer

1. Resolve `implementer-prompt.md` via Glob + Read (see Template Resolution).
2. Substitute placeholders in the template:
   - `[FULL TEXT of task from plan - paste it here, don't make subagent read file]` → the task's text from the plan (read the plan file, find the section matching the checklist's `plan §<id>` reference, copy the task's full text).
   - `[Scene-setting: where this fits, dependencies, architectural context]` → a short paragraph describing the task's context (read the plan's overall goal and phase description; summarize).
   - `[directory]` → the current working directory (user's project root).
3. Append this explicit override text to the prompt:

   ```
   ## Checklist Overrides

   The following overrides take precedence over anything in the task text above:

   1. **TDD is mandatory.** Write a failing test first, watch it fail, then implement. If the task text doesn't mention TDD, do it anyway.

   2. **Extra steps from preflight audit** (execute these before the plan's own steps):
      <list of [INJECTED] step titles from the checklist for this task>
   ```

   If the task has no injected steps, still include the section but say "None."

4. Dispatch via Task tool with:
   - `subagent_type`: `general-purpose`
   - `model`: the model specified in the checklist's `Model:` annotation for this task (haiku/sonnet/opus)
   - `description`: `Implement <task id>: <task name>`
   - `prompt`: the substituted template

5. Wait for the implementer's report.

### B. Handle implementer status

- **DONE** or **DONE_WITH_CONCERNS**: proceed. If DONE_WITH_CONCERNS, read the concerns - fix them before review if they're about correctness; note and proceed if they're observations.
- **NEEDS_CONTEXT**: provide missing context (ask the user if needed) and re-dispatch.
- **BLOCKED**: assess per subagent-driven-development's escalation guidance - provide more context, upgrade model, or break down task.

### C. Tick plan-step checkboxes

As the implementer reports completed steps, edit the checklist file to tick the corresponding checkboxes:
- Change `- [ ] Step 1: ...` to `- [x] Step 1: ...`

### D. Fill commit SHA slot

Read the implementer's report for the commit SHA. Edit the checklist to replace the task's `SHA: \`<fill>\`` with `SHA: \`<actual-sha>\``.

### E. Dispatch spec reviewer

1. Resolve `spec-reviewer-prompt.md` via Glob + Read.
2. Substitute placeholders:
   - `[FULL TEXT of task requirements]` → the task's text from the plan.
   - `[From implementer's report]` → the implementer's "what I implemented" summary.
3. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: the reviewer model specified in the checklist for this task's spec review
   - `description`: `Spec review <task id>`
   - `prompt`: the substituted template
4. Wait for report. Fill the `Spec review` Outcome slot in the checklist with a 1-2 sentence summary.

### F. Handle spec findings

- **No findings / approved:** fill `Spec review resolution - Action: \`None needed\``. Tick the resolution checkbox. Proceed to code review.
- **Findings present:** auto-dispatch fix-implementer:
  1. Craft a prompt summarizing the findings and asking for fixes.
  2. Dispatch with model = task's implementer model (from checklist).
  3. Wait for fix report. If BLOCKED or NEEDS_CONTEXT, upgrade model one tier and retry; if still BLOCKED, write to deferred file (see "Deferred File Handling").
  4. Re-dispatch spec reviewer. Loop until spec approves.
  5. Fill resolution: `Fixed in <last-fix-commit-sha>`.

### G. Dispatch code reviewer

Same as E, but resolve `code-quality-reviewer-prompt.md` and fill the `Code review` slot.

### H. Handle code findings

Same as F, but fill the `Code review resolution` slot.

### I. Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>`:
- Skip steps E-H for tasks that are NOT the last task in the batch (their review gates don't exist in the checklist).
- For the LAST task in the batch, after completing its steps A-D, run spec + code review on ALL batched tasks' combined diff. Fill the `Batch review` and `Batch review resolution` slots on the last task.
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: `OK: fly structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/fly/
git commit -m "fly: template resolution + per-task loop with auto-fix"
```

---

### Task 3.3: Write fly's phase gates, final gate, deferred file, and verification

**Files:**
- Modify: `.claude/skills/fly/SKILL.md`

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/fly/tests/structural-check.sh`:

```bash
grep -q "^## Phase Gates$" "$SKILL" || { echo "FAIL: Phase Gates section"; exit 1; }
grep -q "^## Final Gate$" "$SKILL" || { echo "FAIL: Final Gate section"; exit 1; }
grep -q "^## Deferred File Handling$" "$SKILL" || { echo "FAIL: Deferred File Handling section"; exit 1; }
grep -q "^## Final Verification$" "$SKILL" || { echo "FAIL: Final Verification section"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: FAIL with `Phase Gates section`

- [ ] **Step 3: Add Phase Gates, Final Gate, Deferred File Handling, Final Verification sections**

Append to `.claude/skills/fly/SKILL.md`:

```markdown
## Phase Gates

After all tasks in a phase complete (all per-task slots filled), run the phase's review gate per its checklist annotation.

- **Normal review** (`Phase N Gate (reviewer: <model>)` with `Normal code-review on Phase N diff`):
  1. Compute the phase diff: `git diff <phase-N-first-commit-sha>^..<phase-N-last-commit-sha>`.
  2. Dispatch code reviewer via `code-quality-reviewer-prompt.md` template, with the phase diff as the subject.
  3. Fill Outcome slot with summary.
  4. If findings: same auto-fix loop as per-task reviews. Fill Resolution.

- **Deep-review** (`Phase N Gate (reviewer: ...)` with `/deep-review on Phase N diff`):
  1. Invoke `/deep-review` scoped to the phase diff (note: `/deep-review` reads the current git state; you may need to checkpoint or use `git stash`/`git diff` explicitly to scope it).
  2. Fill Outcome slot with `/deep-review`'s summary (e.g., "12 auto-fixed, 2 deferred to -deferred.md §N").
  3. `/deep-review` has its own auto-fix. Resolution reflects what it did.

## Final Gate

After all phases complete, check the checklist's final gate:

- If `## Final Gate: /deep-review over <scope>` exists:
  1. Invoke `/deep-review` scoped per the annotation.
  2. Fill Outcome + Resolution slots.

- If `**Final gate not needed - all phases have deep-review coverage.**` exists: skip; nothing to do.

## Deferred File Handling

Create/append to `<plan-basename>-deferred.md` in the same directory as the checklist when:
- A fix-implementer reports BLOCKED even at an upgraded model.
- A `/deep-review` invocation produces items it couldn't auto-fix (recorded in its output).

Format of the deferred file:

```markdown
# Deferred Items: <feature>

> Items found during `/fly` execution that couldn't be auto-fixed. Review and address manually.

## §1: <brief context, e.g., "Task 1.1 code review">

**Finding:** <description from reviewer>

**Why deferred:** <reason, e.g., "fix-implementer reported BLOCKED: architectural change required">

**Suggested fix:** <from reviewer's output>
```

When writing a deferred item, assign it the next available `§N`. Then update the corresponding Resolution slot in the checklist: `Action: Deferred to <plan-basename>-deferred.md §N`.

If the deferred file doesn't exist yet, create it with the header first, then append the first `§1` entry.

## Final Verification

After all tasks, phase gates, and final gate are processed, run the verification block at the bottom of the checklist. Tick each item by actually verifying:

- **All plan-step and [INJECTED] checkboxes ticked:** grep the checklist for `- \[ \]` occurrences before the verification block. Should find none. If any found, halt: "Task <X> step <N> not ticked - did the implementer actually complete it?"

- **All SHA slots filled:** grep for `SHA: \`<fill>\``. Should find none.

- **All Outcome slots filled (non-`<fill>`):** grep for `Outcome: \`<fill>\``. Should find none.

- **All Resolution slots filled (non-empty, not "ignored"/"skipped"):** grep for `Action: \`<fill>\`` or `Action: \`ignored\`` or `Action: \`skipped\``. Should find none.

- **Deep-review invariant satisfied:** confirm that every task's commit SHA is in the scope of at least one deep-review Outcome that's non-`<fill>` (i.e., actually ran). If a task's commits aren't covered by any deep-review scope, halt: "Task <X> not covered by a deep-review - invariant violated."

- **If `<plan-basename>-deferred.md` exists, surface contents to user:** read the file and include its full contents in the final report. Explicitly tell the user "deferred items need manual review before shipping."

Tick each verification checkbox only after confirming the condition.

## Completion

After final verification passes:
1. Print final report: tasks completed, commits made, deferred items (if any), time taken.
2. **DO NOT auto-invoke `/ship` or `/superpowers:finishing-a-development-branch`.** Explicit user command only.
3. Suggest next step: "Ready to ship? Run `/ship` when you've reviewed any deferred items."
```

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: `OK: fly structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/fly/
git commit -m "fly: phase gates, final gate, deferred file, final verification"
```

---

### Task 3.4: Write fly's Rationalization Table and Red Flags sections

**Files:**
- Modify: `.claude/skills/fly/SKILL.md`

**Why this task exists:** `/fly` is a *discipline-enforcing* skill — its entire reason for existing is to counter coordinator rationalizations under context pressure. Per `superpowers:writing-skills`, discipline skills need explicit rationalization tables and red-flag lists because agents are smart and will find loopholes. This task adds that hardening.

- [ ] **Step 1: Extend structural check**

Append to `.claude/skills/fly/tests/structural-check.sh`:

```bash
grep -q "^## Rationalization Table$" "$SKILL" || { echo "FAIL: Rationalization Table section"; exit 1; }
grep -q "^## Red Flags - STOP$" "$SKILL" || { echo "FAIL: Red Flags section"; exit 1; }
grep -q "^## The Iron Rule$" "$SKILL" || { echo "FAIL: The Iron Rule section"; exit 1; }
grep -qi "checklist is the contract" "$SKILL" || { echo "FAIL: commitment contract language"; exit 1; }
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: FAIL with `Rationalization Table section`

- [ ] **Step 3: Add the three sections to SKILL.md**

Append to `.claude/skills/fly/SKILL.md`:

````markdown
## Rationalization Table

`/fly` exists because LLM coordinators rationalize shortcuts under context pressure. Before skipping any step, check this table:

| Excuse | Reality |
|--------|---------|
| "This task is trivial, no review needed" | The checklist has review gate checkboxes for every task. Skipping violates the contract. |
| "I already did the spec review conceptually" | The Outcome slot requires a written summary. Mental review doesn't fill the slot. |
| "Finding is minor, skip it" | Resolution slot MUST be filled. Valid Actions: Fixed / FIXME / Deferred. Not "ignored", not "skipped", not empty. |
| "Fix-implementer reported BLOCKED, move on" | Upgrade model one tier and retry FIRST. If still BLOCKED, write to `-deferred.md`. Never silent skip. |
| "Context pressure, let me batch some tasks myself" | Batching is preflight's decision, encoded in the checklist. Do NOT invent new batches at execution time. |
| "Running the review feels redundant, code looks fine" | "Looks fine" is not a review. Dispatch the reviewer subagent. Fill the slot. |
| "The plan doesn't have TDD steps, so I'll skip TDD" | Either the checklist has `[INJECTED]` TDD steps, OR the implementer dispatch has a TDD override instruction. Do TDD. |
| "I'll fix all review findings at the end in one batch" | Each review's Resolution must be filled before moving to the next gate. No accumulating findings across gates. |
| "Verification block is just a formality" | Verification catches tasks you forgot. Tick each box only after actually verifying its condition (grep for unticked boxes, check SHA slots aren't `<fill>`, etc.). |
| "Deep-review on this phase is slow, let me skip" | Preflight decided which phases get deep-review to satisfy the invariant. Skipping breaks the invariant. |

## Red Flags - STOP

If you catch yourself thinking any of these, STOP and re-read the Rationalization Table:

- "Just this one review can be skipped"
- "The finding is so minor it's not worth fixing"
- "I'll come back to this slot later"
- "This is close enough to complete"
- "Let me batch these myself since preflight didn't"
- "Reviewer said 'mostly fine', that counts as approved"
- "I'll fill in the SHA slot later from memory"
- "Ticking the verification box is fine, I'm sure it's done"
- "The implementer said DONE, no need to verify each step checkbox"

**All of these mean: you are about to violate the checklist contract. Do the work.**

## The Iron Rule

**The checklist is the contract. Every checkbox must be ticked by verifying its condition. Every slot must be filled with actual content. No exceptions, no rationalizations.**

If `/fly` completes without every box ticked and every slot filled, the final verification will catch the gap and halt. Do not try to work around the verification — fix the missing work. The verification exists because commitment contracts only hold when they're enforced.

If you genuinely believe a step is wrong or impossible, surface the issue explicitly to the user. Do not silently skip.
````

- [ ] **Step 4: Run test, verify PASS**

Run: `bash .claude/skills/fly/tests/structural-check.sh`
Expected: `OK: fly structural check passed`

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/fly/
git commit -m "fly: rationalization table + red flags + iron rule (discipline hardening)"
```

---

### Task 3.5: Create sample checklist fixture for dry-run testing

**Files:**
- Create: `.claude/skills/fly/tests/samples/sample-checklist.md`

- [ ] **Step 1: Create the sample checklist**

A minimal checklist that `/fly` can dry-run against without actually executing tasks. Used to verify `/fly` correctly detects state, resolves templates, and identifies what it would dispatch.

```markdown
# Preflight Checklist: Dry-Run Sample

> **READ FIRST:** `.claude/skills/fly/tests/samples/sample-plan-stub.md` - stubbed plan (tasks have no implementation code).
> Built by `/preflight` on 2026-04-17. Execute with `/fly`.

## Decisions
- 2 tasks across 1 phase
- Deep-review coverage: final deep-review covers the single phase
- Per-task models: Phase 1 → haiku
- Review batching: none
- TDD gaps injected: none
- Octopus: deferred

---

## Phase 1: Setup | Phase gate: normal review (reviewer: sonnet)

### Task 1 (plan §Task 1) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test (stub - dry-run)
- [ ] Step 2: Run test, verify FAIL (stub)
- [ ] Step 3: Implement (stub)
- [ ] Step 4: Run test, verify PASS (stub)
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 2 (plan §Task 2) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test (stub)
- [ ] Step 2: Run test, verify FAIL (stub)
- [ ] Step 3: Implement (stub)
- [ ] Step 4: Run test, verify PASS (stub)
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Phase 1 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 1 diff - Outcome: `<fill>`
- [ ] Phase 1 gate resolution - Action: `<fill>`

---

## Final Gate: /deep-review over all phases
- [ ] Outcome: `<fill>`
- [ ] Final gate resolution - Action: `<fill>`

---

## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

- [ ] **Step 2: Create a stub plan file referenced by the checklist**

`.claude/skills/fly/tests/samples/sample-plan-stub.md`:

```markdown
# Sample Plan Stub

> Test fixture for /fly dry-run. Tasks are stubs - do not execute.

## Phase 1: Setup

### Task 1: Stubbed task for dry-run
- [ ] Step 1: Write failing test (stub - dry-run)
- [ ] Step 5: Commit

### Task 2: Another stubbed task
- [ ] Step 1: Write failing test (stub)
- [ ] Step 5: Commit
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/fly/tests/samples/
git commit -m "fly: sample checklist + stub plan fixtures for dry-run validation"
```

---

### Task 3.6: Integration test — dry-run /fly on sample checklist

**Files:** no new files - manual test procedure.

- [ ] **Step 1: Run /fly in dry-run mode**

Open a new Claude Code session in the dotfiles repo. Run:

```
/fly .claude/skills/fly/tests/samples/sample-checklist.md
```

Immediately after `/fly` announces its mode, STOP execution (interrupt the Claude session with Escape or Ctrl+C). We're verifying state detection and initial template resolution, not actually running tasks against stubs.

Expected behavior:
1. Announces: `Flying .claude/skills/fly/tests/samples/sample-checklist.md. Mode: fresh run.`
2. Resolves templates via Glob; reports paths found (e.g., `Resolved implementer-prompt.md → .../superpowers/5.0.7/skills/subagent-driven-development/implementer-prompt.md`).
3. Reads the referenced plan stub.
4. Begins dispatching Task 1's implementer (at which point you stop it).

- [ ] **Step 2: Verify template Glob resolution works**

Manually run:

```bash
ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/implementer-prompt.md
```

Expected: at least one path printed.

If the Glob pattern fails in `/fly`, inspect the plugin cache structure and adjust the Glob pattern in `.claude/skills/fly/SKILL.md`.

- [ ] **Step 3: Verify mid-flight pickup detection**

Edit the sample checklist to tick the first step of Task 1 and fill Task 1's SHA slot:

```markdown
- [x] Step 1: Write failing test (stub - dry-run)
...
- [x] Step 5: Commit - SHA: `abc1234`
```

Re-run `/fly` on the modified checklist. Interrupt immediately after it announces mode.

Expected: `Mode: resuming from Task 1.` (or more specifically, from the first unticked step).

Revert the edits:

```bash
git checkout .claude/skills/fly/tests/samples/sample-checklist.md
```

- [ ] **Step 4: Record the integration test as manual procedure**

Append to `.claude/skills/fly/tests/structural-check.sh`:

```bash

# Integration test: dry-run /fly on sample checklist.
# MANUAL - requires live Claude Code session with plugin installed.
# Procedure:
#   1. Fresh Claude session: /fly .claude/skills/fly/tests/samples/sample-checklist.md
#   2. Interrupt after "Mode: fresh run" announcement; verify template resolution logs.
#   3. Edit sample-checklist.md to tick first step + fill Task 1 SHA.
#   4. Re-run /fly; verify "Mode: resuming from Task 1".
#   5. git checkout to restore fixture.
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/fly/
git commit -m "fly: dry-run integration test procedure documented"
```

---

## Phase 4: Integration

### Task 4.1: Update SKILLS.md with /preflight and /fly

**Files:**
- Modify: `SKILLS.md`

- [ ] **Step 1: Read current SKILLS.md structure**

Read `SKILLS.md` to understand:
- Where the layout table is (skill list).
- Where the current direction section is.
- Where the skill invocation graph (mermaid) is.

- [ ] **Step 2: Add entries to the Layout section**

In the Layout section, under `skills/`, add after `superpowers/`:

```
    ├── preflight/        # Transform plan → checklist contract (models, gates, TDD audit)
    ├── fly/              # Execute checklist; dispatch subagents via upstream templates
```

- [ ] **Step 3: Update the Current Direction section**

The current direction section describes the superpowers-based orchestration flow. Update it to include preflight/fly:

```markdown
**Active workflow (what I'm using now):**

1. `superpowers:brainstorming` - explore intent, requirements, design before implementation
2. `superpowers:writing-plans` - turn the brainstorm into a plan with review checkpoints
3. `/preflight` - transform the plan into a checklist with dynamic model/gate/TDD decisions
4. `/fly` - execute the checklist with auto-fix, phase gates, and final verification

`/preflight` and `/fly` are custom dotfiles skills that layer discipline on top of
`superpowers:subagent-driven-development` via template reuse (not flow invocation).
Commitment device: the checklist with its checkboxes and SHA slots.
```

- [ ] **Step 4: Update the mermaid skill invocation graph**

In the `superpowers` subgraph, replace the existing chain with:

```mermaid
  subgraph superpowers[Superpowers plugin flow]
    brainstorming --> writing-plans
    writing-plans -.user types.-> preflight
    preflight --> fly
    fly -.template reuse.-> subagent-driven-development
  end
```

Add preflight and fly nodes:

```mermaid
  style preflight fill:#2d4a5a,color:#fff
  style fly fill:#2d4a5a,color:#fff
```

- [ ] **Step 5: Commit**

```bash
git add SKILLS.md
git commit -m "SKILLS.md: add /preflight and /fly to skills layout + invocation graph"
```

---

### Task 4.2: End-to-end real-plan test

**Files:** no new files - end-to-end manual test against a real pending plan.

- [ ] **Step 1: Identify a real plan to test against**

The user mentioned a pending Journology plan with ~45 tasks. Use that plan if available. Otherwise, any plan from `~/<project>/docs/specs/plans/` with at least 6 tasks works.

Set `PLAN_PATH` to the chosen plan's absolute path.

- [ ] **Step 2: Run /preflight and spot-check the output**

In a fresh Claude Code session, run:

```
/preflight <PLAN_PATH>
```

Check:
- Terminal summary printed with expected fields (task count, phases, models, batching, TDD injections, fly command).
- Checklist file created at `<plan-dir>/<plan-basename>-checklist.md`.
- Open the checklist; verify:
  - Every task from the plan appears with a `(plan §<id>)` reference.
  - Model assignments look reasonable (no opus for obvious haiku tasks, no haiku for obvious opus tasks).
  - TDD audit correctly flagged tasks missing failing-test steps.
  - If plan > 40 tasks: every phase has its own deep-review gate and final gate says "not needed".
  - If plan ≤ 40 tasks: final gate is `/deep-review` covering phases that lack deep-review.

- [ ] **Step 3: Run /fly on the checklist (interactive, watch first few tasks)**

In the same or a new fresh session, run:

```
/fly <checklist-path>
```

Observe for the first 2-3 tasks:
- Correctly announces mode.
- Resolves templates via Glob.
- Dispatches implementer with checklist-specified model.
- Injects TDD override text into implementer prompt (verify by inspecting dispatched prompt).
- After implementer completes: ticks plan-step checkboxes, fills commit SHA.
- Dispatches spec reviewer with checklist-specified reviewer model.
- If findings: auto-dispatches fix-implementer.
- Fills Outcome and Resolution slots.

If anything misbehaves, halt and fix the SKILL.md.

- [ ] **Step 4: Let /fly run to completion (optional for first pass)**

If the plan is small enough (< 15 tasks) and time allows, let `/fly` run to completion.

At the end, verify:
- Final Verification block fully ticked.
- If any items deferred: `<plan-basename>-deferred.md` exists with deferred items; contents surfaced to you.
- No auto-invocation of `/ship`.

- [ ] **Step 5: Document observations and iterate**

Note any drift, bugs, or tuning opportunities:
- Thresholds wrong? (Phase threshold 15, overwhelm threshold 40)
- Model assignment logic misfires? (Add heuristics in `Decisions Preflight Makes`)
- TDD audit misses cases? (Adjust the detection rule)
- Template Glob breaks? (Update pattern)

Iterate on the SKILL.md files as needed, re-run affected tasks.

- [ ] **Step 6: Commit any adjustments from real-plan testing**

```bash
git add .claude/skills/preflight/ .claude/skills/fly/
git commit -m "preflight+fly: tuning from end-to-end real-plan test"
```
