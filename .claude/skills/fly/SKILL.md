---
name: fly
description: "Use when executing a preflight checklist. Triggers: 'fly', 'launch execution', 'run the checklist', or when given a preflight checklist file path."
argument-hint: [path to checklist file]
user-invocable: true
---

# Fly

Execute a preflight checklist. Walks tasks, dispatches subagents, fills slots, auto-fixes review findings, verifies completion.

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

If `/fly` completes without every box ticked and every slot filled, the final verification will catch the gap and halt. Do not try to work around the verification - fix the missing work. The verification exists because commitment contracts only hold when they're enforced.

If you genuinely believe a step is wrong or impossible, surface the issue explicitly to the user. Do not silently skip.
