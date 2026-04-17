# Preflight + Fly: Disciplined Plan Execution

**Status:** Design
**Date:** 2026-04-17

## Goal

Add two custom skills to `.claude/skills/` that layer execution discipline on top of `superpowers:subagent-driven-development`, without modifying or forking the upstream skill.

- **`/preflight`** - transform an implementation plan into a *preflight checklist*: a markdown contract encoding per-task model assignments, phase groupings, review gates with reviewer models, TDD audit with injected steps when missing, explicit resolution checkboxes, and SHA slots.
- **`/fly`** - execute a preflight checklist by invoking `superpowers:subagent-driven-development` inline, auto-dispatching fix agents for review findings, filling slots as work progresses, and doing a final verification sweep.

Aviation theme: preflight the plan, fly the execution.

## Problem

When executing long implementation plans with `superpowers:subagent-driven-development`, the current coordinator ("Bob") exhibits these failure modes:

1. **TDD skipped.** Implementer prompt says "follow TDD if task says to" - contingent on plan text. Tasks without explicit failing-test steps silently omit TDD.
2. **Reviews skipped.** Under context pressure (even in fresh sessions with long task lists), Bob rationalizes "this task is trivial, no review needed" and dispatches the implementer without follow-up reviewer subagents.
3. **Review findings unresolved.** When reviews DO run, minor issues surface and sometimes never get fixed - they get glossed over or forgotten.
4. **Cognitive overload at 40-100+ tasks.** Even fresh session context doesn't prevent rationalized shortcuts on long task lists.
5. **Ad-hoc model selection.** Per-task model choice is made in the moment; defaults to one model regardless of task complexity.

**Root cause:** execution discipline lives in the coordinator's moment-to-moment reasoning, not in a durable artifact. Under pressure, discipline gets rationalized away.

**Cure:** externalize all execution decisions into a *preflight checklist* that is filled out during execution. The checklist is the contract; every box must be ticked, every slot filled, before work is considered done.

## Design Principles

1. **The checklist is the contract.** All execution decisions (models, phases, review gates, reviewer models, TDD steps, resolution mechanism) are encoded in the checklist before execution starts. `/fly` does not make discretionary calls - it ticks boxes and fills slots.
2. **Commitment device through markdown checkboxes.** Every step, review, and resolution is an unchecked checkbox. Final verification rejects the run if any checkbox is unticked or slot is unfilled. Inline fields are promoted to standalone checkboxes wherever commitment matters (e.g., review resolution).
3. **Preserve upstream via template reuse, not flow invocation.** `superpowers:writing-plans`, `superpowers:subagent-driven-development`, and `superpowers:test-driven-development` are not modified or forked. `/fly` owns its own per-task flow but **reads upstream prompt templates at runtime** via Glob resolution of the plugin cache (see Implementation Notes). Upstream prompt improvements flow through automatically on plugin upgrade. `/fly` does NOT "invoke subagent-driven-development inline" — that would nest flows confusingly when `/fly` already overrides most steps.
4. **Agent-agnostic.** Checklist is plain markdown. Skills work anywhere AGENTS.md is honored (Claude Code, Codex, Cursor).
5. **Deep-review invariant.** Every task's code must be in at least one deep-review scope before shipping. `/preflight` decides review gate structure to satisfy this.
6. **Auto-fix by default, defer only when necessary.** Review findings trigger automatic fix-implementer dispatch. Deferral only happens when fix-implementer reports BLOCKED (too large, architectural).
7. **Checklist is a compressed index, not a duplicate.** Plan is source of truth for WHAT (code, commands, paths). Checklist is source of truth for HOW it's tracked and gated. Step checkbox labels are auto-extracted from plan step titles - no manual duplication, no drift opportunity.

## Architecture

```
   user writes plan via /superpowers:writing-plans
                      │
                      │  writing-plans offers its own handoff prompt (subagent-driven vs inline);
                      │  user ignores it and types /preflight instead (de-facto auto-chain via muscle memory)
                      ▼
   docs/specs/plans/YYYY-MM-DD-<feature>.md    (plan - untouched by our skills)
                      │
                      │  user invokes /preflight when ready (also works on any pre-existing plan)
                      ▼
              /preflight <plan-path>
                      │
                      ├─ read plan
                      ├─ decide: phases, per-task models, review gates, reviewer models
                      ├─ TDD audit (inject extra checkboxes for plans missing failing-test steps)
                      ├─ build checklist
                      └─ print terminal summary (key decisions + file link + fly command)
                      │
                      ▼
   docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md   (checklist - slots empty)
                      │
                      │  user invokes /fly (typically in a fresh session)
                      ▼
                /fly <checklist-path>
                      │
                      ├─ read BOTH plan (for content) AND checklist (for gates)
                      ├─ own per-task loop; dispatch subagents using upstream prompt templates:
                      │     implementer  (model from checklist + TDD override + [INJECTED] steps)
                      │        → spec-reviewer (model from checklist)
                      │        → auto-dispatch fix-implementer if findings (model matches task)
                      │        → code-reviewer (model from checklist)
                      │        → auto-dispatch fix-implementer if findings
                      ├─ fill SHA + Outcome + Resolution slots as work progresses
                      ├─ run phase gates and final gate per checklist
                      ├─ write deferred items to <feature>-deferred.md when fix fails
                      └─ final verification: all boxes ticked, all slots filled
                      │
                      ▼
       user runs /ship manually when ready - no auto-handoff
```

## `/preflight` Skill

### Purpose
Transform a plan into a preflight checklist with all execution decisions encoded.

### Triggers
- User invokes `/preflight <plan-path>` on any plan file (fresh from writing-plans, or mid-flight).
- Not auto-chained from writing-plans. User reviews plan first, invokes preflight when ready.

### Input
Path to plan file (typically `docs/specs/plans/YYYY-MM-DD-<feature>.md`).

### Output
- Sibling file: `docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md`
- Original plan untouched
- Terminal summary (see below)

### Overwrite Behavior
If checklist already exists, preflight warns and requires explicit overwrite confirmation. Prevents clobbering in-progress work.

### Decisions Preflight Makes

**Phase groupings:**
- If plan has explicit phase structure, respect it.
- If plan has no phases and total tasks exceed phase threshold (default: 15), batch related tasks into phases by shared files, dependencies, or concern.
- If plan has fewer tasks than phase threshold, treat as single phase.

**Per-task model assignment** (haiku / sonnet / opus):
- Complexity signals from task text:
  - Touches 1-2 files with complete spec, low integration → haiku
  - Multi-file changes, integration concerns, pattern matching → sonnet
  - Architecture, broad codebase understanding, subtle correctness → opus

**Review policy per task:**
- `standard`: dispatches spec-reviewer + code-reviewer per subagent-driven-development default.
- `batched-with <neighbors>`: groups of genuinely trivial adjacent tasks share a single post-batch review. Max batch size: 3 tasks. Batch review lives on the LAST task in the batch (can only review after all batched tasks are done).

**Reviewer model per gate (dynamically assigned by preflight):**
Preflight picks a reviewer model per gate based on the gate's complexity. Defaults and upgrade rules:

- **Spec review**: default haiku. Upgrade to sonnet if the task has complex requirements or broad spec scope (verification itself requires nuanced understanding). Opus reserved for rare cases.
- **Code review**: default sonnet. Upgrade to opus if the task involves subtle correctness, multi-file integration, architectural judgment, or high blast-radius changes.
- **Phase review (normal)**: default sonnet. Upgrade to opus for phases covering many files or touching cross-cutting concerns.
- **Deep-review (`/deep-review`)**: owns its own model logic; preflight does not override.

Upgrade signals mirror those for the task's implementer model, one tier higher (reviewer needs to catch what the implementer might have missed). If a task has opus implementer, its code review should at minimum be opus too.

User can still manually tweak any reviewer model in the checklist before invoking `/fly` — preflight's terminal summary surfaces the assignments so override is easy.

**Phase review gate:**
- `normal`: dispatch code-reviewer over phase diff.
- `deep-review`: run `/deep-review` over phase diff (for large or complex phases).

**Final review gate:**
- `deep-review`: covers phases that only had normal review.
- `not needed`: skipped if every phase had deep-review coverage already.

**Deep-review coverage invariant:**
Every task's code must be in at least one deep-review scope before shipping. Preflight picks the combination of (per-phase deep-review + final deep-review) that satisfies this.

**Overwhelm rule:** if total tasks exceed overwhelm threshold (default: 40), a single final deep-review is too large a scope for reliable auto-fix. Preflight must assign per-phase deep-review to every phase; final gate skipped.

**TDD audit:**
- For each task, check that the plan has "write failing test" + "verify test fails" steps before any implementation steps.
- If missing, inject extra checkboxes into the checklist (NOT into the plan) with `[INJECTED]` prefix.
- `/fly` instructs implementer subagents to honor both plan steps and checklist-injected steps.

### Terminal Summary

After producing the checklist, `/preflight` prints:

```
Preflight checklist created.

File: docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md
(clickable link to file)

Key decisions:
- <N> tasks across <M> phases
- Deep-review coverage: <summary, e.g., "Phase 3 deep-review; final deep-review covers Phases 1-2">
- Per-task models: <e.g., "Phase 1 → haiku, Phases 2-3 → sonnet">
- Review batching: <e.g., "Tasks 1.2 + 1.3 batched (trivial)" or "none">
- TDD gaps injected: <e.g., "Tasks 1.3, 2.5" or "none">
- Octopus recursion: deferred

Ready to execute? In a fresh session, run:
  /fly docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md
```

Rationale:
1. **Key nuances** - user sees the gist without opening the file
2. **Clickable link** - one click to edit if tweaks needed
3. **Fresh-session fly command** - copy-paste ready to kick off execution without re-deriving the path

## `/fly` Skill

### Purpose
Execute a preflight checklist by invoking `superpowers:subagent-driven-development` inline, auto-dispatching fix agents, filling slots, and verifying at the end.

### Triggers
User invokes `/fly <checklist-path>` - typically in a fresh session for clean context.

### Input
- Path to preflight checklist.
- Implicit: original plan file referenced in the checklist's header.

### Flow

```
1. Read checklist. Read referenced plan.
2. Detect state:
   - All checkboxes empty, all slots `<fill>` → fresh run
   - Some checkboxes ticked, some slots filled → mid-flight pickup; resume from first unticked box
3. Announce: "Flying <checklist>. Mode: fresh run | resume from Task X.Y."
4. Walk the checklist's tasks in order, implementing /fly's own per-task loop.
   Dispatch subagents using prompt templates from superpowers:subagent-driven-development
   (implementer-prompt.md, spec-reviewer-prompt.md, code-quality-reviewer-prompt.md)
   — /fly references them by path; does not invoke subagent-driven-development as a skill.

   For each task:
     a. Dispatch implementer subagent using implementer-prompt.md template with:
        - Plan's task text (source of truth for code, commands)
        - Model from checklist
        - Explicit instruction appended: "Follow TDD regardless of task text."
        - Any [INJECTED] steps from checklist (TDD steps not in plan)
     b. As implementer reports completed steps, tick corresponding plan-step checkboxes.
     c. Fill commit SHA slot.
     d. Dispatch spec reviewer using spec-reviewer-prompt.md template (model per checklist). Fill Outcome slot.
     e. If findings:
        - Auto-dispatch fix-implementer with findings. Fix model = task's implementer model by default.
          If fix-implementer reports BLOCKED/NEEDS_CONTEXT, upgrade model and retry
          (same pattern subagent-driven-development documents).
        - Loop: re-dispatch spec-reviewer → fix-implementer if findings → re-review, until spec approves.
        - Fill Resolution slot: "Fixed in <SHA>"
        Otherwise Resolution: "None needed".
     f. Dispatch code reviewer using code-quality-reviewer-prompt.md template (model per checklist). Fill Outcome slot.
     g. If findings: same auto-fix loop with fix-implementer. Fill Resolution slot.
     h. For batched tasks: spec + code review happen once on the batch's last task; resolution covers all batched tasks.
5. After each phase, run phase gate per checklist (normal code-review or /deep-review). Fill slots. Auto-fix findings same as task-level.
6. After all phases, run final gate if specified.
7. Final verification meta-step:
   - All checkboxes ticked (plan steps + [INJECTED] + review gates + resolutions)
   - All SHA, Outcome, Resolution slots filled (non-`<fill>`, non-empty, not "ignored"/"skipped")
   - Deep-review invariant holds (every task's diff in ≥1 deep-review scope)
   - If `<feature>-deferred.md` exists, surface its contents to user
   - If any verification fails, halt and report specifically what is missing
8. Report done. DO NOT auto-invoke /ship or finishing-a-development-branch.
```

### Auto-fix Default
- After every review with findings, `/fly` immediately dispatches a fix-implementer subagent with the findings.
- **Fix-implementer model selection:** default-matches the task's implementer model. If fix-implementer reports BLOCKED or NEEDS_CONTEXT, `/fly` upgrades the model and retries (following subagent-driven-development's documented pattern).
- Loop: re-review → fix again → re-review, until reviewer approves.
- Only defers to `<feature>-deferred.md` if fix-implementer reports BLOCKED even at upgraded model (truly too large, architectural, out of scope).
- `/deep-review` has its own auto-fix mechanism; `/fly` records what it did in the Resolution slot (e.g., "12 auto-fixed, 2 deferred to -deferred.md §3").

### Does NOT manage TodoWrite
- The checklist IS the durable commitment artifact. No conflicting TodoWrite preload.
- If `/fly` uses TodoWrite for ephemeral session state (e.g., high-level phase markers for its own tracking), that's internal to `/fly` — separate from the checklist contract.

### Mid-flight Pickup
- `/fly` detects partial fill (some boxes ticked, some slots filled) and resumes from the first unticked step.
- Handles paused-session case naturally.

## Checklist Schema

### Location
`docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md`

Same directory as plan, `-checklist` suffix.

### Structure

```markdown
# Preflight Checklist: <feature>

> **READ FIRST:** `docs/specs/plans/YYYY-MM-DD-<feature>.md` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.

## Decisions
- <Total tasks> across <phases>
- Deep-review coverage: <summary>
- Per-task models: <summary>
- Review batching: <summary or "none">
- TDD gaps injected: <summary or "none">
- Octopus: deferred

---

## Phase 1: <name> | Phase gate: <normal review | deep-review> (reviewer: <model>)

### Task 1.1 (plan §<N>) | Model: <haiku|sonnet|opus> | Review: standard

Plan steps:
- [ ] Step 1: <title extracted from plan>
- [ ] Step 2: <title>
- [ ] [INJECTED] <title for preflight-injected steps, if any>
- [ ] Step N: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 1.2 (plan §<N>) | Model: haiku | Review: batched-with 1.3
Plan steps:
- [ ] Step 1: ...
- [ ] Step N: Commit - SHA: `<fill>`
(No individual review gates - batch review below covers 1.2 + 1.3)

### Task 1.3 (plan §<N>) | Model: haiku | Review: batched-with 1.2 | TDD steps injected
Plan steps:
- [ ] [INJECTED] Write failing test
- [ ] [INJECTED] Run test, verify FAIL
- [ ] Step 1 (from plan): ...
- [ ] Step N: Commit - SHA: `<fill>`

Batch review gate (covers 1.2 + 1.3):
- [ ] Batch review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Batch review resolution - Action: `<fill>`

### Phase 1 Gate (reviewer: <model>)
- [ ] <Normal code-review on Phase 1 diff | /deep-review on Phase 1 diff> - Outcome: `<fill>`
- [ ] Phase 1 gate resolution - Action: `<fill>`

---

[ ... more phases ... ]

---

## Final Gate: <deep-review over Phases X-Y>
- [ ] Outcome: `<fill>`
- [ ] Final gate resolution - Action: `<fill>`

OR (when every phase already deep-reviewed):

**Final gate not needed - all phases have deep-review coverage.**

---

## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

### Slot Formats
- `<fill>` = empty-slot marker. Non-`<fill>` = filled.
- `SHA:` slot = 7-40 char git commit hash.
- `Outcome:` slot = short free-form text (1-2 sentences), e.g. "Approved" or "Found 3 minor issues".
- `Action:` slot = resolution text. One of:
  - `None needed`
  - `Fixed in <SHA>`
  - `FIXME at <file:line>`
  - `Deferred to -deferred.md §<N>`

### Batching Notation
- Batched tasks annotated `Review: batched-with <neighbors>`.
- Individual batched tasks have only step checkboxes, no individual review gates.
- Shared batch review lives on the LAST task in the batch.
- Max batch size: 3.

### Injection Notation
- TDD steps added by preflight (not in plan) prefixed with `[INJECTED]`.
- `/fly` instructs implementers to honor both plan steps and `[INJECTED]` checklist-only steps.

## Deferred File

### Location
`docs/specs/plans/YYYY-MM-DD-<feature>-deferred.md`

Sibling to plan + checklist.

### Existence
- File exists only if at least one deferral occurred during `/fly`.
- No file = nothing deferred (user doesn't read an empty section).

### Format

```markdown
# Deferred Items: <feature>

> Items found during `/fly` that couldn't be auto-fixed. Review and address manually.

## §1: Task 1.1 code review
**Finding:** <description from reviewer>
**Why deferred:** fix-implementer reported BLOCKED: <reason>
**Suggested fix:** <from reviewer's output>

## §2: /deep-review on Phase 3 diff
...
```

### Reference from Checklist
Resolution slots in checklist reference deferred items by section number:
`Action: Deferred to -deferred.md §1`

## Out of Scope / Deferred

- **Octopus recursion.** Deferred. If commitment device alone doesn't handle 40-100+ task plans (drift observed), add phase-level subagent dispatch to `/fly`: loop over phases dispatching subagent-driven-development per phase instead of walking all tasks in one pass. Mechanical to add later.
- **Custom subagent type for the coordinator.** Rejected for now in favor of commitment-device approach (agent-agnostic + human-in-the-loop preferred). Available as fallback if commitment device proves insufficient.
- **Auto-chaining from writing-plans to preflight.** Not done in code (would require forking writing-plans, which has its own execution-handoff prompt). In practice the chain is muscle-memory: after writing-plans finishes, user ignores its prompt and types `/preflight` directly. Preflight's terminal summary becomes the de-facto plan review gate for lazy reviewers.
- **Auto-handoff to /ship or finishing-a-development-branch.** Explicit user invocation only.
- **Upstream contribution to superpowers plugin.** Valuable but not required now.

## Implementation Notes

- Skill files: `.claude/skills/preflight/SKILL.md`, `.claude/skills/fly/SKILL.md`.
- Register slash commands in standard frontmatter (`user-invocable: true`).
- Update `SKILLS.md` diagram to reflect new skills' place in the superpowers pipeline.
- Test on a real plan (e.g., a pending Journology plan with many tasks) before claiming done.

### Resolving Upstream Prompt Templates at Runtime

The superpowers plugin cache at `~/.claude/plugins/cache/claude-plugins-official/superpowers/` contains versioned directories (e.g., `5.0.5/`, `5.0.7/`). Direct hard-coded paths are brittle because version changes on plugin upgrade.

`/fly` resolves templates at dispatch time using Glob, picking the newest version:

```
Glob: ~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/implementer-prompt.md
→ sort by modification time (Glob already does this), take first
→ Read that file for template content
```

Templates to resolve this way:
- `subagent-driven-development/implementer-prompt.md`
- `subagent-driven-development/spec-reviewer-prompt.md`
- `subagent-driven-development/code-quality-reviewer-prompt.md`

This gives `/fly`:
- Auto-update on plugin upgrade (no manual sync)
- Visible failure if templates are renamed/moved upstream (Glob returns no match → `/fly` errors loudly, user investigates)
- No duplication, no fork

Trade-off: Claude-Code-specific (plugin cache is a CC concept). Acceptable because subagent dispatch via Task tool is itself CC-specific. The *plan and checklist* artifacts remain agent-agnostic.

## Next Steps

1. Review and approve this spec.
2. Write the implementation plan via `/superpowers:writing-plans` with bite-sized tasks for building both skills.
3. Implement and test against a real plan.
4. Iterate based on drift observations: tune thresholds, add octopus if needed.
