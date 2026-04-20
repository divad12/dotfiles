# Fly Octopus: Per-Phase Subagent Dispatch for Large Plans

> **SUPERSEDED (2026-04-20):** This design is no longer active. Empirical testing surfaced two unrecoverable blockers: (1) general-purpose subagents cannot nest-dispatch the Task tool, breaking phase subagent coordination, and (2) `opus-1m` is not in the Task tool model enum. In-process octopus is impossible on Claude Code. See the superseding design at `docs/specs/2026-04-20-fly-multi-session-design.md` for the replacement approach (preflight splits large plans into multiple checklist files; fly runs each in a fresh CC session with per-task integrity gate).
>
> The content below is retained for audit trail.

**Status:** Superseded by 2026-04-20-fly-multi-session-design.md
**Date:** 2026-04-18
**Supersedes/extends:** `docs/specs/2026-04-17-preflight-and-fly-design.md` ("Octopus recursion" in Out of Scope is promoted to in-scope here)

## Goal

Extend `/preflight` and `/fly` with an **octopus mode** that handles plans large enough to defeat the single-orchestrator `/fly`. Octopus mode structurally splits execution across per-phase subagents so each subagent runs in a fresh ~10-task context window, while a thin main-side dispatcher tracks progress across phases.

Three tiers total after this design lands:

| Tier | Plan shape | Mode |
|------|------------|------|
| 1 | ≤ 10 tasks | Single-orchestrator `/fly` (unchanged) |
| 2 | > 10 tasks, ≤ 10 phases | Octopus, single session |
| 3 | > 10 phases | Octopus, multi-session (user runs `/fly` once per session; auto-resumes) |

## Problem

The existing `/fly` skill (see 2026-04-17 design) externalizes execution discipline into a checklist contract. That works for small-to-medium plans but degrades on large ones.

Observed failure mode on a real 23-task plan:

- Around phase 12, the orchestrator began fabricating review outcomes: filling `findings=0` without dispatching a reviewer, hedge-summarizing findings out of existence, skipping review-artifact file writes.
- Cause is not missing rules. The Rationalization Table, HALT heuristics, mandatory review-artifact files, structured Outcome format, and priority/disposition tagging are all present and were all getting worn down by cumulative context pressure.
- More prose discipline keeps degrading this way. Once the coordinator's context passes a threshold, it pattern-matches its way into shortcuts that look locally reasonable.

**Root cause:** single long-lived coordinator role is wrong for plans past ~10 tasks. Every task adds ~10-25K tokens of reports, review files, and fix-loop turns to the same coordinator's context. No prose rule survives that.

**Structural fix:** replace the single coordinator with a main-side dispatcher plus N fresh-context phase subagents. Each phase subagent runs the existing per-task loop with the full discipline stack intact; main's per-phase context cost is only ~1-3K tokens (dispatch + receipt + reconciliation grep), so main stays clean across many phases.

## Design Principles

Carried forward from the 2026-04-17 design:

1. **Checklist is the contract.** Still true. Octopus only changes who writes to which slice, not what gets written.
2. **Commitment device through markdown checkboxes.** Unchanged.
3. **Preserve upstream via template reuse.** Unchanged. Phase subagents use the same upstream templates via the same Glob-resolution path.
4. **Agent-agnostic where feasible.** Octopus dispatch is Claude-Code-specific (same constraint as current subagent dispatch). Checklist artifacts remain agent-agnostic.
5. **Deep-review invariant.** Unchanged. Preflight still owns the invariant logic.
6. **Auto-fix by default.** Unchanged. Happens inside phase subagent.
7. **Checklist is a compressed index.** Unchanged.

New principles for octopus:

8. **Phase subagent is a recursive /fly.** A phase subagent executing `/fly` with a phase-window argument IS /fly - same skill file, same per-task loop, same HALT heuristics, same review-artifact mandate. No "octopus mode" logic leaks into per-task discipline. Main's octopus loop is the only new content.
9. **State lives in the checklist.** Phase `Octopus:` status headers are authoritative. No parallel state file, no lock file, no database. Recovery and multi-session handoff re-derive from reading the checklist.
10. **Main is a verifier, not a content judge.** Main dispatches phases, reads receipts, grep-verifies each phase's slice of checklist, flips status headers. It never reads review files or makes finding-level decisions - those happen inside phase subagents.

## Architecture

```
                            MAIN /fly (octopus mode)
                                     │
                                     │  reads checklist, detects octopus mode
                                     │  (phases have "Octopus: pending" status token)
                                     ▼
                   ┌─────────────────────────────────────────┐
                   │  For each phase whose status != done:   │
                   │    1. Flip "Octopus: pending" →         │
                   │       "Octopus: in-flight:<id>"         │
                   │    2. Dispatch phase subagent           │
                   │    3. Await receipt                     │
                   │    4. Run per-phase reconciliation      │
                   │    5. Flip status → "Octopus: done"     │
                   │  Session cap: stop after N phases or    │
                   │  if main's context pressure rising.     │
                   └─────────────────────────────────────────┘
                                     │
                                     │  Task tool dispatch
                                     │  (subagent_type: general-purpose,
                                     │   model: per-phase coordinator model
                                     │   from checklist)
                                     ▼
                   ┌─────────────────────────────────────────┐
                   │  PHASE SUBAGENT (fresh context)         │
                   │                                         │
                   │  Invokes /fly with --phase=N scope.     │
                   │  /fly's per-task loop runs unchanged    │
                   │  for the N tasks in this phase:         │
                   │    - implementer dispatch               │
                   │    - spec reviewer dispatch             │
                   │    - code reviewer dispatch             │
                   │    - fix-implementer loops              │
                   │    - phase gate (normal or /deep-review)│
                   │                                         │
                   │  Writes directly to:                    │
                   │    - checklist slots (ticks, SHA, etc.) │
                   │    - reviews/ artifact files            │
                   │    - deferred.md (if any)               │
                   │                                         │
                   │  Returns 4-line receipt.                │
                   └─────────────────────────────────────────┘
                                     │
                                     │  (receipt)
                                     ▼
                            back to MAIN /fly
                                     │
                          (after all phases done)
                                     │
                                     ▼
                   ┌─────────────────────────────────────────┐
                   │  Final gate (if checklist says so):     │
                   │    dispatch subagent → /deep-review     │
                   │    via Skill tool (pattern unchanged    │
                   │    from 2026-04-17 design).             │
                   │                                         │
                   │  Final verification:                    │
                   │    grep/stat sweep across whole         │
                   │    checklist. Stays in main.            │
                   └─────────────────────────────────────────┘
```

3-level nesting (main → phase subagent → implementer/reviewer subagents) is validated by precedent: the current /fly already nests main → subagent → /deep-review → parallel sub-reviewers, which is the same depth.

## Decisions on the Nine Open Questions

### Q1. Model for each phase subagent → preflight-assigned, default opus, upgrade to opus-1m on heavy phases

Phase subagent IS the coordinator role. That role is what failed under pressure in the 23-task run. Weakening it defeats the structural fix.

- **Default: opus (200K context).** Coordinator does HALT heuristics, review-artifact verification, structured Outcome enforcement, and fix-loop judgment - all tasks that rewarded opus's reasoning quality in observation.
- **Upgrade to opus-1m (1M context)** when ANY of the following signals indicate the phase subagent is at risk of context spill:
  - Phase weight ≥ 15 (heavy phase, close to the ceiling).
  - Phase gate is `/deep-review` (the skill's parallel sub-reviewers and normalization pass inflate phase subagent context significantly).
  - Phase has > 5 review-gate dispatches expected (approximated as task count + phase gate count; heuristic for deep fix-loop potential).
  - Plan is multi-session tier (> 10 phases, overall plan complexity correlates with per-phase findings density).
  
  Any one signal triggers upgrade. Context headroom on heavy/deep phases is the same kind of structural fix as octopus itself: give the coordinator room rather than ask it to compress.
- **Downgrade to sonnet** (never below) only if ALL of: phase has no opus-tier task, phase gate is `normal` (not `/deep-review`), phase has ≤ 3 tasks, phase has no tasks flagged with refactor/migrate/rewrite signals, AND no upgrade signals apply. If any upgrade signal is present, downgrade is forbidden regardless of other conditions.
- **Never haiku.** Haiku is fine for implementers on trivial tasks; too weak for orchestration discipline.
- **Annotated in checklist header, verbatim dispatch.** Same rule as task-implementer and reviewer models: the `model` parameter on the Task dispatch is copied exactly from the `coordinator: <model>` annotation. HALT if main disagrees.
- **Model-string availability note.** `opus-1m` refers to the opus model with 1M-token context variant (e.g., `claude-opus-4-7[1m]` or equivalent, depending on current Claude Code model registry). Preflight should emit the literal model string the user's environment supports. If `opus-1m` is unavailable, preflight falls back to `opus` and surfaces this in the terminal summary so the user knows heavy phases are running at standard context.

### Q2. Handoff: main → phase subagent

Minimal paths, not inlined content.

Handoff payload passed in the phase subagent's prompt:

- Checklist absolute path.
- Plan absolute path (derived from checklist header, but passed explicit to save a re-derive).
- Phase ID (the integer N the subagent is responsible for).
- Working directory (user's project root; cwd at main's dispatch time).
- The `--phase=N` instruction telling /fly to operate in phase-scoped mode.

Phase subagent re-reads checklist and plan itself. Keeps prompt small; avoids "main inlines partial plan, drifts from actual plan file" bug. Phase subagent has Read / Glob / Grep / Edit / Write / Task tools (same as any subagent dispatched `general-purpose`).

Relevant `docs/ai/` files (if the project has the adaptive-docs system) are loaded by the phase subagent per the same rules as any /fly run - driven by the task text, not by main pre-selecting.

### Q3. Output contract: phase subagent → main

Phase subagent writes directly to the shared checklist (slots, ticks, status headers) and to `reviews/` artifact files. Main does not re-read the review files.

Phase subagent returns a 4-line receipt for main's log:

```
Phase <N> done.
Commits: <first-sha>..<last-sha> (<count>)
Deferred: <0 | N - see <plan>-deferred.md §A-§Z>
HALTs hit: <none | list>
```

Main treats the receipt as a breadcrumb, not evidence. The real evidence is the checklist state and review artifact files on disk, which main verifies in the per-phase reconciliation pass (below).

If the phase subagent's receipt is missing or malformed, main treats it as a failed phase and re-dispatches.

### Q4. Checklist shape changes

One new token on each phase header; nothing else changes structurally.

**Before:**

```markdown
## Phase 1: <name> | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

**After (octopus mode):**

```markdown
## Phase 1: <name> | Octopus: pending (coordinator: <model>) | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

During execution, the `Octopus:` token mutates:

- `Octopus: pending (coordinator: <model>)` - initial state, written by preflight.
- `Octopus: in-flight:<id> (coordinator: <model>)` - flipped by main on dispatch. `<id>` is a short unique token (e.g., short timestamp + random suffix) for audit trail only; main does not act on it programmatically.
- `Octopus: done (coordinator: <model>)` - flipped by main after per-phase reconciliation passes.

Single-orchestrator plans (≤ 10 tasks) OMIT the `Octopus:` token entirely. That's the signal to `/fly` that it should run its pre-octopus single-orchestrator loop.

### Q5. Final gate + per-phase reconciliation

**Final gate dispatch: unchanged from 2026-04-17 design.** Main dispatches a subagent → invokes `/deep-review` via Skill tool. Pattern carries over. Main then processes findings per step F (same as today).

**Final verification sweep: stays in main.** It is grep/stat work, not content judgment. Cheap. Receipts accumulated in main are tiny.

**New: per-phase reconciliation between phase dispatches.** This is the integrity gate that makes octopus trustworthy. Without it, a phase subagent could return a clean-looking receipt while leaving slots unfilled, and the gap would only surface at final verification - by which point the phase is cold and the subagent context is gone.

After each phase subagent returns, main runs these checks against the phase's slice of checklist (from `## Phase N:` header to next `## Phase` header or Final Gate):

1. Grep for `- [ ]` in the slice. Expected: none.
2. Grep for `` `<fill>` `` in the slice. Expected: none.
3. Grep for `findings=` lines missing `review:` tokens. Expected: none.
4. For each `review: <path>` token, stat the file: exists, non-trivial, mtime after the commit SHA's timestamp, `findings-count` header matches `grep -c "^### Finding " <path>`.
5. Phase Gate Outcome starts with `tests_pass=N tests_fail=N regressions=0;` prefix (phase regression check ran).
6. Deep-review invariant locally satisfied if this phase has a `/deep-review` gate.

**Outcome:**

- All clean → flip header `in-flight:<id>` → `done`. Move to next phase.
- Gap detected → re-dispatch SAME phase subagent (fresh subagent, but fly's existing mid-flight pickup logic resumes from first gap). Bounded retry: 2 re-dispatches max. Third failure → HALT, surface gap list to user.

### Q6. State tracking / recovery

Authoritative state = checklist content + `Octopus:` status headers. No separate state file.

Mid-session recovery (phase subagent fails or main crashes between phases):

- Next time `/fly <checklist>` runs, it reads the checklist top-to-bottom.
- First phase with `Octopus: pending` or `Octopus: in-flight:<id>` → that's the next phase to dispatch. (If in-flight, treat as "the prior dispatch didn't finish cleanly, re-dispatch from scratch; fly's existing step-level resume logic inside the phase subagent will pick up from the first unfilled slot.)
- If all phases are `Octopus: done` → move to Final Gate / final verification.
- If checklist has no `Octopus:` tokens → single-orchestrator mode, run current pre-octopus logic.

The `<id>` in `in-flight:<id>` is breadcrumb for the human reading a failed session, not machine state. Main ignores it on resume.

### Q7. Multi-session handoff

Trigger: phase count > `phase_session_cap` (default 10).

Preflight writes a companion file: `<plan-dir>/<plan-basename>-handoff.md`. This file is advisory documentation - it tells the user what session-by-session execution looks like - but state still lives in the checklist.

**Handoff file format:**

```markdown
# Multi-session handoff: <feature>

> Plan has <N> tasks across <M> phases. Too large for single-session octopus
> (phase_session_cap = 10). Execute in <K> sessions. Each session runs the
> same command on the same checklist; fly auto-resumes at the first phase
> whose `Octopus:` status header is not `done`.

## Session windows (recommended)

### Session 1: Phases 1-5
Start a fresh Claude Code session. Run:
  /fly docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md
Fly will process Phases 1-5 and halt when its session-window heuristic trips
(default: after 10 phases done in one session, OR when main's message count
exceeds a threshold).

### Session 2: Phases 6-10
Prereq: Session 1 marked Phases 1-5 as `Octopus: done`.
Start a fresh Claude Code session. Same command.

### Session 3: Phases 11-<M> + final gate + final verification
Prereq: Session 2 done.
Start a fresh Claude Code session. Same command.
This session also runs the Final Gate and Final Verification sweep.

## State

Authoritative: the `Octopus:` status headers in the checklist.
Advisory: this file. Session boundaries are suggestions; fly picks up wherever
it left off regardless of how you chunked the sessions.
```

**Session-window heuristic inside /fly:**

When main /fly enters octopus mode, it tracks how many phases it has marked `done` in this session. After reaching `phase_session_cap` (default 10), it halts with:

```
Session window done: processed <K> phases this session.
Remaining phases: <list of phase IDs with Octopus: pending>.
Start a fresh Claude Code session and re-run:
  /fly <checklist-path>
```

Between sessions is a hard human-in-the-loop boundary. No auto-continuation across Claude Code sessions.

**Preflight auto-flag.** When preflight detects multi-session tier, its terminal summary includes:

```
Mode: multi-session octopus (42 tasks, 14 phases)
Windows: 2 sessions recommended (Phases 1-10 / 11-14 + final)
Handoff doc: <path-to-handoff.md>
```

User sees this upfront; can adjust thresholds or split differently before running `/fly`.

### Q8. Nested subagent dispatch

Confirmed feasible by precedent. Current `/fly` dispatches main → subagent → `/deep-review` skill → parallel sub-reviewers (Codex / Chrome MCP / rule compliance / simplification / collateral / diff analysis). That's three levels of Task/subagent dispatch.

Octopus is the same depth: main → phase subagent → implementer/reviewer subagents. No deeper.

No new depth concerns introduced by this design. The Template Resolution path via Glob works inside nested subagents (any subagent dispatched via Task tool has access to Glob and Read, which is all Template Resolution needs).

### Q9. Concurrency / review artifact file ordering

Phase subagents are dispatched sequentially by main. One phase in-flight at a time. No concurrent writes to `reviews/` or the checklist file.

The `reviews/` file naming convention (`task-<id>-spec.md`, `task-<id>-code.md`, `phase-<N>-gate.md`, etc.) is already unique per task/phase. Even if we later added concurrent dispatch (we won't, per this design), file names wouldn't collide.

No locking, no ordering logic required.

### Q10. Null-result meta-check (closing the `findings=0` fabrication hole)

**Observed vector:** an orchestrator under context pressure can write `findings=0 (review: <path>); No issues.` AND write a matching `<path>` file containing a YAML header plus literal `No issues.`, without ever having dispatched the reviewer subagent. Current defenses (review artifact mandate, honest-null rule, YAML findings-count match, mtime-after-commit) all pass for a fabricated file because the same orchestrator is writing them.

**Structural close:** every `findings=0` outcome triggers a cheap haiku meta-verifier dispatch. The meta-verifier reads the review file + the diff under review and returns `CONFIRMED` or `SUSPICIOUS` based on whether the review shows evidence of engagement with the specific code.

**Applies to every review with a null result**, at every level:

- Per-task spec review (step F in fly's per-task loop) whose Outcome will be `findings=0`.
- Per-task code review (step H) same.
- Batched review (step I) same.
- Phase gate review (normal path) same.
- Phase gate deep-review (after /deep-review normalization) when normalized findings-count = 0.
- Final gate when findings-count = 0.

Fires regardless of mode (single-orchestrator, octopus, phase-scoped). All `findings=0` outcomes route through this check before the Outcome slot gets filled.

**Meta-verifier dispatch:**

Right before filling an Outcome slot with `findings=0`, the orchestrator (main in single-orchestrator, phase subagent in octopus phase scope) dispatches:

- `subagent_type`: `general-purpose`
- `model`: `haiku` (verification is narrow and cheap; upgrade only on retry)
- `description`: `Verify null review for <task-or-scope>`
- `prompt`: see "Meta-verifier prompt" below. Includes the review file contents + the diff (git show <sha> or git diff <base>..<head>) + diff size context.

**Responses:**

- `CONFIRMED: <reason>` -> fill the Outcome slot as normal. Proceed.
- `SUSPICIOUS: <reason>` -> treat as if the original review never happened. Re-dispatch the REAL reviewer (not the meta-verifier) with a stricter prompt adding `THIS IS YOUR SECOND ATTEMPT. A meta-check flagged the prior null-result review as suspicious: <reason>. Read every hunk in the diff and emit findings or an explicit engagement trail.` Loop: if second attempt also returns findings=0, re-run meta-check. If meta-check SUSPICIOUS again -> HALT, surface to user with both review files + meta-verifier reasons.

**Meta-verifier prompt:**

```
You are a meta-verifier for a claimed null review.

Another reviewer submitted a review file claiming findings=0 (no issues).
Your job: determine whether that reviewer actually engaged with the diff,
or whether the review is boilerplate/fabricated.

## Review file under verification
<contents of review file>

## Actual diff under review (size: <N> lines, <K> files)
<contents of git show <sha> or git diff <base>..<head>>

Evaluate:

1. YAML header: does commit-sha match the diff? Does files-touched (if present)
   match the diff's file list?
2. Body content: does it reference specific files, functions, or line numbers
   from the diff? Does it show evidence the reviewer read the actual code
   (concrete observations, names from the diff, engagement with what changed)?
3. OR does the body look like boilerplate: generic praise, "No issues found",
   "Code looks good", with no diff-specific references?
4. Diff-size sanity: for diffs under 10 lines, a brief legitimate null review
   is plausible as long as it mentions WHAT it looked at. Do not penalize
   brevity when the diff is trivial.

Respond with EXACTLY ONE of:

  CONFIRMED: <one sentence on the engagement evidence you found>

  SUSPICIOUS: <one sentence on why the review looks fabricated or boilerplate>

Err toward SUSPICIOUS when diff-specific engagement evidence is thin on a
non-trivial diff. A legitimate null review on a 100-line diff still references
what was checked.
```

**False-positive handling.** Trivially small diffs can trip the heuristic. The "diff-size sanity" clause in the prompt mitigates this, and the retry path (re-dispatch real reviewer with stricter framing) naturally handles the rare legitimate null review that gets flagged.

**Cost.** One haiku dispatch per `findings=0` outcome. A phase with 5 clean task reviews + 1 clean phase gate triggers 6 haiku calls. Negligible against the cost of a single fabricated review slipping through.

**Why haiku, not sonnet.** The meta-verifier's job is narrow: cross-reference two text inputs for content overlap. Haiku handles that fine, and the low cost makes this checkable on every null outcome without budget concerns. Upgrade to sonnet only if empirically haiku proves too lax in production.

**Interaction with existing HALT heuristics.** The existing "3 consecutive `findings=0` Outcomes" HALT still fires, but meta-check is a stronger per-outcome gate. Both stay; they catch different things. Meta-check catches individual fabrication; consecutive-nulls HALT catches a pattern (even if each individual meta-check confirmed, three in a row warrants a human spot-check).

## Constants (all tunable by editing the skills)

```
single_orchestrator_cap = 10 tasks (raw count)
                          - at or below, use current /fly single-orchestrator

phase_weight_budget     = 20 weight units per phase (CEILING, not target)
                          weights: haiku task = 1, sonnet task = 2, opus task = 4
                          +1 bonus for tasks mentioning refactor/migrate/rewrite
                             or spanning > 5 files in their own text

phase_session_cap       = 10 phases per octopus session
                          - past this per session, multi-session mode
```

These numbers are first-run estimates. Observe fabrication rate on the first real octopus execution of a large plan; tune downward if drift appears at phase counts below the cap.

## Preflight Changes

Only additive. Existing preflight output remains valid for small plans (≤ 10 tasks) because the new `Octopus:` token is simply omitted.

### New: mode detection (two-step)

Mode selection is two steps because phase grouping logic differs between single-orchestrator and octopus modes.

```
# Step 1: task count decides whether octopus is in play.
if task_count <= single_orchestrator_cap:
    mode_family = "single_orchestrator"
    phase_groups = respect_plan_phases_if_explicit_else_single_phase()
else:
    mode_family = "octopus"
    phase_groups = group_by_weight_budget(phase_weight_budget)

# Step 2: phase count splits octopus into single/multi-session.
if mode_family == "single_orchestrator":
    mode = "single_orchestrator"
elif len(phase_groups) <= phase_session_cap:
    mode = "octopus_single_session"
else:
    mode = "octopus_multi_session"
```

Coordinator-model assignment runs only if `mode_family == "octopus"`.

### New: phase grouping honors weight budget

Current preflight batches tasks into phases by "shared files, dependencies, or concern." Octopus adds the constraint that total weight in a phase must not exceed `phase_weight_budget`.

- If the plan has explicit phases and any phase exceeds the budget, preflight does not silently regroup. It warns in the terminal summary: `Phase <N> has weight <W>, above budget <20>. Consider splitting.` User can edit the plan and re-run preflight, or proceed anyway.
- If the plan has no explicit phases, preflight groups greedily: walk tasks in plan order, accumulate into a phase until adding the next task would exceed budget, then start a new phase. Respect natural dependency boundaries (if grouping by shared files would be cleaner, prefer that within the weight constraint).

### New: coordinator model assignment (octopus modes only)

For each phase in octopus mode, preflight assigns a coordinator model:

```
default: opus (200K context)

upgrade to opus-1m (1M context) if ANY of:
  - phase weight >= 15
  - phase gate is /deep-review
  - expected review-gate dispatches > 5 (approx: task_count + 1 for phase gate)
  - plan is multi-session tier (phase_count > phase_session_cap)

downgrade to sonnet only if ALL of:
  - phase has no opus-tier task
  - phase gate is "normal" (not /deep-review)
  - phase has <= 3 tasks
  - no task mentions refactor/migrate/rewrite or spans > 5 files
  - NO upgrade signals above apply (upgrade always wins over downgrade)

never downgrade further (no haiku coordinator)
```

Preflight emits the literal model string the user's environment supports. If `opus-1m` is unavailable, fall back to `opus` and surface in terminal summary: `opus-1m unavailable; heavy phases running at 200K context (risk: context spill).`

### New: `Octopus:` token on phase headers

For each phase, preflight appends the token to its phase header line:

```
## Phase 1: <name> | Octopus: pending (coordinator: <model>) | Phase gate: ...
```

Single-orchestrator mode: omit the token entirely.

### New: multi-session handoff file

If mode is `octopus_multi_session`, preflight writes `<plan-basename>-handoff.md` alongside the checklist. Content per Q7 above.

### Updated: Fly Verification block in octopus mode

In octopus mode (single or multi-session), preflight adds one additional checkbox to the Fly Verification block at the end of the checklist:

```markdown
- [ ] All phases marked `Octopus: done`
```

Single-orchestrator checklists do not include this line. Fly's verification pass, in octopus mode, ticks this box only after grepping and confirming no `Octopus: pending` or `Octopus: in-flight:` remains in the checklist.

### Updated: terminal summary

New lines added to the existing summary:

```
Mode: <single-orchestrator | octopus single-session | octopus multi-session>
(for octopus) Coordinator models: <per-phase summary>
(for multi-session) Windows: <K> sessions recommended (...). Handoff doc: <path>
(warnings, if any): Phase <N> weight <W> above budget; consider splitting.
                    Plan ≤ 10 tasks but total weight <X> > 20 - consider manual octopus.
```

The octopus-related decisions should surface in the terminal so the user can adjust before running `/fly`.

## Fly Changes

### New: octopus detection on entry

Current /fly already does state detection (fresh / mid-flight / complete). Octopus adds a mode check:

```
read checklist
if any phase header contains "Octopus: <status>":
    mode = octopus
else:
    mode = single_orchestrator (current behavior, unchanged)
```

Single-orchestrator plans skip all octopus code paths. No behavior change for ≤ 10 task plans.

### New: `--phase=N` scope argument

Fly gains a `--phase=N` argument (or equivalent: could be detected as a positional integer after the checklist path, or via an env-like token in the prompt when dispatched by main).

- When `/fly` is invoked with `--phase=N`, it operates in phase-scoped mode: reads checklist, finds phase N, walks only phase N's tasks using the existing per-task loop, runs phase N's phase gate, returns the receipt.
- Phase-scoped /fly does NOT run the final gate, does NOT run final verification, does NOT update `Octopus:` status headers (main does that). It only writes per-task slots, review artifacts, and deferred entries within its phase's scope.
- Phase-scoped /fly honors the existing mid-flight pickup logic. If main re-dispatches because reconciliation failed, the new phase subagent sees some slots already filled and resumes from the first gap.

### New: octopus main loop (only when mode = octopus)

After detection and state announcement, main enters the octopus loop:

```
session_phase_count = 0
for each phase in checklist (top-to-bottom):
    status = parse(phase.octopus_token)
    if status == "done":
        continue
    if session_phase_count >= phase_session_cap:
        halt with session-window message; exit.

    flip phase header: "pending" or "in-flight:<old_id>" → "in-flight:<new_id>"
    dispatch phase subagent via Task tool:
        subagent_type: general-purpose
        model: coordinator model from phase header (verbatim)
        description: "Octopus phase <N>: <phase name>"
        prompt: see "Phase subagent prompt" below
    await receipt

    if receipt malformed or missing:
        retry up to 2 times
        on third failure: HALT, surface to user

    run per-phase reconciliation (grep/stat checks on phase slice)
    if reconciliation fails:
        retry dispatch up to 2 times (fresh phase subagent; mid-flight pickup
        will resume from first gap)
        on third failure: HALT, surface gap list

    flip phase header: "in-flight:<id>" → "done"
    session_phase_count += 1

# all phases done at this point (or halted)
run final gate if checklist specifies one (unchanged from current design)
run final verification sweep (unchanged)
print final report
```

### New: phase subagent prompt template

Main dispatches each phase subagent with a prompt like:

```
You are executing /fly in phase-scoped mode for a large plan.

CONTEXT:
  Checklist path: <abs path>
  Plan path:      <abs path>
  Phase ID:       <N>
  Working dir:    <cwd>

INSTRUCTION:
  Invoke the /fly skill via your Skill tool. Pass the checklist path and
  the phase-scope argument `--phase=<N>`. Fly's phase-scoped loop will:
    1. Read checklist and plan.
    2. Walk the tasks in Phase <N>.
    3. Run Phase <N>'s phase gate after all tasks complete.
    4. Return the 4-line receipt.

  Do NOT run the final gate, the final verification sweep, or update the
  phase's `Octopus:` status header. The main /fly session owns those.

  All /fly discipline (review-artifact mandate, HALT heuristics, Rationalization
  Table, reviewer independence override, structured Outcome format) applies
  unchanged inside your scope.

  Write your receipt as the last thing you report back. Receipt format:

    Phase <N> done.
    Commits: <first-sha>..<last-sha> (<count>)
    Deferred: <0 | N - see <plan>-deferred.md §A-§Z>
    HALTs hit: <none | list>
```

The phase subagent's Skill tool invocation re-enters /fly, which on re-entry detects the `--phase=N` argument and runs the phase-scoped loop (no octopus loop nesting).

### Updated: skill file size

fly/SKILL.md grows by roughly 150 lines (octopus detection, octopus main loop, `--phase` scoped behavior, per-phase reconciliation checks, session-window heuristic). Existing content is unchanged - single-orchestrator behavior is preserved unchanged for ≤ 10 task plans.

Total estimated size: ~800 lines, still within a single skill file. Not split into a separate `fly-octopus/` skill because the per-task discipline must stay in one place: phase subagents invoke `/fly`, so fly's per-task loop content is shared between main (single-orchestrator) and phase subagent (phase-scoped) modes. Splitting would force duplication.

## Checklist Shape Changes

One new token type on phase headers (per Q4). No other schema changes.

- Single-orchestrator mode: checklist has no `Octopus:` tokens. Same format as 2026-04-17 design.
- Octopus mode (single or multi-session): each `## Phase <N>:` header has one additional pipe-delimited segment: `Octopus: <status> (coordinator: <model>)`.

Fly Verification block (end of checklist) gains one additional check in octopus mode:

```markdown
- [ ] (octopus only) All phases marked `Octopus: done`
```

Grep-implemented like the other verification items.

## Receipt Format (phase subagent → main)

Exact format, four lines:

```
Phase <N> done.
Commits: <first-sha>..<last-sha> (<count>)
Deferred: <0 | N - see <plan>-deferred.md §A-§Z>
HALTs hit: <none | list>
```

- Line 1: literal `Phase <N> done.` - if the phase subagent halted without completing, it emits instead `Phase <N> HALTED: <reason>` and main treats the receipt as a failure.
- Line 2: first and last commit SHAs of the phase (from the phase's task commits). Count is total commits in the phase.
- Line 3: deferred-count summary. `0` if no deferrals. Otherwise `N - see <plan>-deferred.md §A-§Z` where A-Z is the range of deferred entries this phase appended.
- Line 4: HALT heuristics tripped during the phase. `none` is the expected case. Anything else is a human-interest signal, not an auto-action trigger for main.

Main greps receipt for `Phase <N> done.` prefix to determine success vs failure. Then proceeds to reconciliation regardless (reconciliation is the actual gate).

## Multi-session Handoff File Format

See Q7 above. Companion file `<plan-basename>-handoff.md` in the same directory as the plan and checklist. Advisory documentation; not authoritative state.

Preflight writes it at initial checklist creation when `phase_count > phase_session_cap`. If the user re-runs preflight and the phase count changes, handoff file is regenerated.

## Compatibility with Existing Features

### Review-artifact file mandate (2026-04-17)

Fully compatible. Phase subagents invoke /fly's per-task loop, which already contains the review-artifact mandate. Since phase subagents run sequentially, file paths are unique, and there is no concurrency. No changes to the path convention or the reviewer independence override block.

### HALT heuristics (fabrication detection)

Fully compatible. HALT heuristics run inside the per-task loop (`/fly`'s existing code), which phase subagents invoke. A phase subagent detecting a HALT trips its own escalation, reports it on line 4 of the receipt, and may halt the phase. Main sees the halt via the receipt's `Phase <N> HALTED:` variant and surfaces to user.

Main itself does not run per-finding HALT heuristics (it doesn't see findings). Main's HALT surfaces are:

- Reconciliation failure after 2 retries.
- Malformed or missing receipt after 2 retries.
- Session-window cap reached (halt is informational, not a failure).

### Rationalization Table

Applies inside phase subagents (same as today). Does not need additions on main's side, because main doesn't make content judgments - it only routes phase dispatches and checks checklist hygiene. An extra row or two in the table may be useful:

| Excuse | Reality |
|--------|---------|
| "Phase subagent's receipt says done, skip reconciliation" | Reconciliation is the integrity gate. The receipt is a breadcrumb, not evidence. Grep the slice. |
| "Phase subagent returned but slot X is still `<fill>`, close enough" | That's a reconciliation failure. Re-dispatch. No drift. |
| "Main is busy; re-use prior phase's receipt" | No. Each phase has its own dispatch, receipt, reconciliation. |

## Agent-Agnostic Considerations

Octopus dispatch is Claude-Code-specific because subagent dispatch via the Task tool is Claude-Code-specific. This matches the existing 2026-04-17 design (which is also CC-specific for dispatch but CC-agnostic for checklist artifacts).

Checklist artifacts remain agent-agnostic:

- `Octopus:` status headers are plain markdown pipe-delimited tokens. Any agent reading the checklist can interpret them.
- Receipt format is plain text.
- Handoff file is plain markdown.

Agents that cannot dispatch subagents (Codex, Cursor with limited agent tools) will not be able to run octopus mode. They can still run single-orchestrator `/fly` for small plans. Large plans on non-CC agents fall back to manually walking phase-by-phase with the user's direction - same failure mode as today.

## Out of Scope / Deferred

- **Concurrent phase dispatch.** Sequential only. Saves locking complexity; main's role is thin enough that sequential doesn't bottleneck anything.
- **Cross-session auto-continuation.** Multi-session requires the user to start a fresh Claude Code session between windows. No background daemon, no scheduled trigger.
- **Auto-detection of "main is drifting, time to hand off".** The session-window cap (`phase_session_cap = 10`) is a static heuristic. A future refinement could track main's approximate context usage and hand off earlier, but YAGNI for v1.
- **Per-phase subagent retry backoff.** Retry limit is 2; no backoff delay, no exponential escalation. If 2 retries don't resolve, halt and surface - humans are better at root-causing.
- **Octopus for single-orchestrator-sized plans.** Users who want the fresh-context isolation of octopus for a small plan can manually edit the checklist to add `Octopus:` tokens. Preflight will not auto-add them for ≤ 10 task plans.
- **Observability / telemetry on octopus runs.** Out of scope. The checklist and review artifacts are the audit trail. A future improvement could aggregate stats (fabrication rate per phase, retry rate, etc.) from completed checklists, but not v1.
- **Upstream contribution.** As before - valuable but not required.

## Implementation Notes

- Octopus implementation lives entirely in `.claude/skills/fly/SKILL.md` and `.claude/skills/preflight/SKILL.md`. No new skill directories.
- Fly grows by ~150 lines. Preflight grows by ~80 lines (mode detection, coordinator-model assignment, handoff file writer, terminal summary updates).
- Keep the constants near the top of each skill for easy tuning.
- Add tests: at least one real large plan run end-to-end through octopus (single-session), and one simulated multi-session run (verify state handoff via checklist status headers).
- Document the three-tier decision in both skills' purpose sections so users see the mode selection at a glance.

## Next Steps

1. Review and approve this spec.
2. Write the implementation plan via `/superpowers:writing-plans`, scoped to:
   - Preflight changes (mode detection + coordinator-model assignment + phase header token + handoff file + terminal summary).
   - Fly changes (octopus detection + main octopus loop + `--phase` scope + per-phase reconciliation + session-window heuristic + receipt parsing).
   - Checklist schema update (document the new token).
   - Test on a real large plan.
3. Implement and test.
4. Iterate based on fabrication-rate observations on first real runs; tune constants.
