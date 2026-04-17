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
