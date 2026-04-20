---
name: fly
description: "Use when executing a preflight checklist. Triggers: 'fly', 'launch execution', 'run the checklist', or when given a preflight checklist file path."
argument-hint: [path to checklist file]
user-invocable: true
---

# Fly

Execute a preflight checklist. Walks tasks, dispatches subagents, fills slots, auto-fixes review findings, verifies completion.

> **Docs naming note:** where this skill says `AGENTS.md`, read `AGENTS.md` or `CLAUDE.md`, whichever the project has. Same for user-global `~/.claude/AGENTS.md` vs `~/.claude/CLAUDE.md`. Each agent handles the fallback conventionally.

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

## Multi-File Checklist Support

`/fly` executes exactly ONE checklist file per invocation. That file is complete and self-contained: its own tasks, its own phase gates, and (if present) its own final gate.

When a plan is large enough that preflight splits it, preflight emits multiple checklist files alongside the plan, typically named like:

- `<plan>-checklist-1.md`
- `<plan>-checklist-2.md`
- `<plan>-checklist-3.md`

In that case, the user runs `/fly <checklist-N>` once per file, in order, each in a fresh Claude Code session. Each invocation is a complete run over its own file. Fly does not cross-reference other checklist files, does not attempt to read sibling checklists, and does not coordinate state between them. The checklist file you were handed is the universe for this invocation.

## Template Resolution

Template Resolution applies ONLY to per-task and phase-level dispatches of implementer, spec-reviewer, and code-quality-reviewer subagents. It does NOT apply to deep-review gate dispatches - those invoke the `/deep-review` skill via the Skill tool, without templates. See "Phase Gates - Deep-review" and "Final Gate" for that pattern; do not apply Template Resolution there.

For in-scope dispatches (per-task + normal phase review + batched review):

`/fly` dispatches those subagents using prompt templates from the superpowers plugin cache. The cache directory contains versioned subdirectories (e.g., `5.0.5`, `5.0.7`), so direct paths are brittle.

Resolve each template at dispatch time:

1. Use the Glob tool with pattern:
   `~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/<template>.md`
2. Glob returns paths sorted by modification time (newest first). Take the first match.
3. Use the Read tool on that path to get the template content.

Templates `/fly` resolves this way:
- `implementer-prompt.md` - used when dispatching implementer subagents (step A)
- `spec-reviewer-prompt.md` - used when dispatching spec reviewer (step E)
- `code-quality-reviewer-prompt.md` - used when dispatching code reviewer (step G) and normal phase review

NOT resolved via this mechanism:
- `/deep-review` gates - invoked via Skill tool inside a dispatched subagent (see Phase Gates). No template, no paraphrase.
- Fix-implementer dispatches - reuse the implementer template, just substituting different placeholders.

If Glob returns no match for an in-scope template, the plugin cache doesn't contain it (upstream rename, new plugin version, cache cleared). Halt and tell the user: "Upstream templates not found at <pattern>. Check plugin install or update the Glob pattern."

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
   - `model`: the EXACT model string from the checklist's `Model:` annotation for this task. No drift in either direction. If the checklist says `Model: sonnet`, the Task call gets `model: "sonnet"` - not opus (upgrade), not haiku (downgrade), not a different opus variant. The checklist IS the contract, and audit-trail integrity requires the dispatch to match.
   - `description`: `Implement <task id>: <task name>`
   - `prompt`: the substituted template

   **If you believe the checklist's model assignment is wrong for this task**, HALT. Tell the user: "Task <id> checklist says Model: <X>, but the task appears to need <Y> because <reason>. Edit the checklist and re-run?" Then stop. Do NOT silently drift - upgrading "to be safe" or downgrading "because this looks easy" both break the commitment contract and make the audit trail lie.

   Same rule applies to REVIEWER model dispatch in steps E/G and all phase/final gate dispatches: the `model` parameter is copied verbatim from the checklist annotation. No orchestrator discretion on review-gate models.

   **Exception: fix-implementer dispatches** (step F, H, and phase-gate fix loops) are NOT governed by a checklist annotation. The fixer defaults to the task's implementer model but may upgrade on its own judgment when a finding is architecturally gnarly or when the default-model fix BLOCKED. That's discretionary, not contract-gated, because there's no checklist entry to violate.

5. Wait for the implementer's report.

### B. Handle implementer status

- **DONE** or **DONE_WITH_CONCERNS**: proceed. If DONE_WITH_CONCERNS, read the concerns - fix them before review if they're about correctness; note and proceed if they're observations.
- **NEEDS_CONTEXT**: provide missing context (ask the user if needed) and re-dispatch.
- **BLOCKED**: assess per subagent-driven-development's escalation guidance - provide more context, upgrade model, or break down task.

### C. Tick plan-step checkboxes

Once the implementer reports all completed steps, tick them in one
batched bash invocation instead of N individual Edit calls:

    bash <path-to-tick-steps.sh> <checklist-path> <task-id> <comma-separated-step-numbers>

Example: if the implementer completed steps 1, 2, 3, 4 of Task 3.2:

    bash ~/.claude/skills/fly/tick-steps.sh docs/specs/plans/2026-04-18-feature-checklist.md 3.2 1,2,3,4

Script output: `OK <N checkboxes ticked>` on success, `ERROR <reason>`
on failure. On ERROR, do NOT proceed to step D; halt and surface.

Rationale: N Edit calls per task (one per step) bloat orchestrator
context unnecessarily when the operation is mechanical find-and-replace.
The script handles all steps in one `sed` pass.

### D. Fill commit SHA slot

Read the implementer's report for the commit SHA. Edit the checklist to replace the task's `SHA: \`<fill>\`` with `SHA: \`<actual-sha>\``.

### E. Dispatch spec reviewer

1. Resolve `spec-reviewer-prompt.md` via Glob + Read.
2. Choose the review file path per "Review Artifact Files": `<plan-dir>/reviews/task-<id>-spec.md`. Create `reviews/` if missing.
3. Substitute placeholders:
   - `[FULL TEXT of task requirements]` → the task's text from the plan.
   - `[From implementer's report]` → the implementer's summary, placed under the heading `## Implementer-Reported Summary (untrusted)`.
4. Append a `## Actual Diff` section containing the output of `git show <task-sha>`.
5. Append the Reviewer Independence Override block verbatim, with `<review-file-path>` replaced by the absolute path chosen in step 2.
6. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: the reviewer model specified in the checklist for this task's spec review
   - `description`: `Spec review <task id>`
   - `prompt`: the substituted + augmented template
7. Wait for report. Verify the review file exists at the assigned path. If missing, re-dispatch with stricter language; if it fails again, halt.
8. Read the review file. Its `### Finding N:` sections are the source of truth - NOT the reviewer's text response summary.
9. Fill the `Spec review` Outcome slot using the structured format (must include the `review:` reference).

### F. Handle spec findings

Parse the reviewer's output. Every admissible finding has a unique number, a priority, a disposition, and a file:line citation. Classify by disposition:

- **Inadmissible** - missing number, priority, disposition, or citation. Count for `inadmissible=N` in the Outcome. Do NOT act on them; the reviewer failed its contract.
- **`[fix]`** - auto-fix via fix-implementer (see below). This is the default disposition; most findings land here regardless of priority.
- **`[defer]`** - write to deferred.md. Only valid if the reviewer cited one of the three defer criteria (user decision / phase-sized / extremely risky). If the reviewer tagged `[defer]` without a valid reason, reject: halt and re-dispatch the reviewer asking it to reconsider disposition.

**Accounting invariant:**

    admissible_findings = fixed + deferred

Every admissible finding lands in one bucket. No "skipped" / "ignored" / "wontfix".

**Fix loop (all `[fix]` findings, highest priority first):**

1. Craft a fix prompt listing each `[fix]` finding by its number, priority, citation, and suggested fix. Order by priority (critical → major → minor → cosmetic). The fixer's report must reference which finding numbers were addressed.
2. Dispatch fix-implementer. Default model: the task's implementer model from the checklist. The fixer may upgrade if a specific finding is architecturally gnarly or if the default-model fix BLOCKs - this is discretionary, not contract-gated (the checklist annotates task work, not fix work).
3. Wait for fix report. If any `[fix]` number is missing from the report, treat that finding as BLOCKED.
4. For BLOCKED findings: retry once with upgraded model. If still BLOCKED, evaluate whether the finding actually meets a defer criterion - if yes, move it to deferred.md with the BLOCKED reason. If no (e.g., it's a tractable fix the model just couldn't see), halt and surface to the user.
5. Re-dispatch spec reviewer (full cycle: Reviewer Independence Override, fresh diff). Loop until no `[fix]` admissible findings remain.

**Deferred-write (only `[defer]` findings + any `[fix]` that legitimately blocked):**

Each deferred finding gets its own `§N` entry with priority in the heading and the specific defer reason (which of the 3 criteria). If you find yourself writing many defer entries in a single review, that's a signal - either the reviewer is mis-disposing (re-dispatch), or the scope of this task genuinely needs the user's attention (halt, surface).

**Fill the Outcome slot** using the structured format:

    findings=N fixed=N deferred=N; <summary>

Optional: `inadmissible=N`. Invariant: `findings == fixed + deferred`.

**Fill the Resolution slot:**

- No findings at all: `None needed`.
- All fixed, none deferred: `Fixed in <last-fix-commit-sha>`.
- Some deferred: `Fixed in <sha>; N deferred to -deferred.md §A-§Z` (or just the defer reference if nothing was fixed inline).

### G. Dispatch code reviewer

Same as E, but:
- Resolve `code-quality-reviewer-prompt.md` instead of spec-reviewer.
- Review file path: `<plan-dir>/reviews/task-<id>-code.md`.
- Fill the `Code review` Outcome and Resolution slots.

### H. Handle code findings

Same as F, but fill the `Code review resolution` slot.

### I. Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>`:
- Skip steps E-H for tasks that are NOT the last task in the batch.
- For the LAST task in the batch, run spec + code review on the combined diff (`git diff <first-batch-commit>^..<last-batch-commit>`). Review file paths: `<plan-dir>/reviews/batch-<first-id>-<last-id>-spec.md` and `-code.md`. Fill the `Batch review` slots on the last task.

### Combined review shortcut (when phase gate = /deep-review)

If the phase containing this task has `Phase N Gate (reviewer: ...) with /deep-review on Phase N diff`, per-task reviews switch to a single combined spec+code reviewer to save dispatches. The phase's deep-review will do the deep pass.

1. Dispatch ONE reviewer (not separate spec + code). Use the `code-quality-reviewer-prompt.md` template and include spec concerns in the prompt: "Also check whether the commit satisfies the plan's task requirements, not just code quality."
2. Review file path: `<plan-dir>/reviews/task-<id>-combined.md`.
3. Fill BOTH the Spec review and Code review slots from the same file with identical findings count (or leave Spec review with `findings=0 fixed=0 deferred=0 (combined with code review, see task-<id>-combined.md); Combined review.` and put the full results in Code review).
4. This shortcut is only valid when the phase's annotated gate is `/deep-review`. Phases with normal gates still get separate spec + code reviews.

### Suspicious-pattern HALT

After every review processing step, check:

- **Missing review file after announced dispatch**: If a reviewer dispatch returns but the review file wasn't written, the reviewer either failed or was never actually dispatched. Re-dispatch with stricter prompt (add "THIS IS YOUR SECOND ATTEMPT - you MUST Write to `<path>` as your final tool call or your review will be discarded"). If it fails a second time, halt.
- **Outcome count doesn't match file**: If `findings=N` in Outcome ≠ `grep -c "^### Finding " <file>`, halt.

These heuristics exist because cumulative context pressure makes the orchestrator lazy in predictable ways. The checks are cheap; the false-positive cost is a y/n prompt.

## Reviewer Independence Override

Every reviewer dispatch (per-task spec/code review in E/G, batched review in I, phase gate review, final gate) MUST include this override block, appended AFTER the upstream template's placeholder substitutions. It exists so the reviewer (1) reads the diff independently, and (2) writes its output to a file so the orchestrator cannot fabricate review results.

Append verbatim to the reviewer prompt (substitute `<review-file-path>` with the path the orchestrator assigns - see "Review Artifact Files" below):

```
## Reviewer Independence Override

The "Implementer-Reported Summary" above is UNTRUSTED. It is the artifact under
review, not the verdict. Before accepting any claim:

1. Read the `## Actual Diff` section below as your primary evidence. The diff
   is authoritative; the summary is spin.
2. For every "I added X / tests pass / behavior works" claim, find the evidence
   in the diff or captured test output. If you can't, treat the claim as
   unsubstantiated.
3. Your job is to find what the implementer missed or hid, not to concur.

### Finding enumeration (MANDATORY)

Emit EVERY raw finding from EVERY angle of your analysis as its own numbered
section. Do NOT output a "consolidated" or "summary" list that collapses
multiple observations. Do NOT downgrade, merge, or omit findings between your
body text and your final list. If you notice something anywhere in your
review - structure, naming, duplication, missing test, edge case, doc drift,
collateral change, convention mismatch, whatever - it gets its own
`### Finding N:` entry.

    ### Finding N: <short title>

    Priority: `[critical]` | `[major]` | `[minor]` | `[cosmetic]`
    Disposition: `[fix]` | `[defer]`
    Location: `<file>:<line>` (or `<file>:<line-line>` for ranges)

    <description>

    **Suggested fix:** <concise>

    **Why defer:** <only present if Disposition=defer; cite which of the 3
                    defer criteria applies - see below>

Findings without a number, priority, disposition, or citation are inadmissible
and will be discarded.

### Priority

- `[critical]` - ship-blocker: breaks correctness, security, data integrity, or
  specified behavior
- `[major]` - real correctness or quality issue; would annoy a careful reviewer
- `[minor]` - small correctness issue or noticeable style/convention mismatch
- `[cosmetic]` - purely aesthetic

Priority is for fix order and human readability. It does NOT gate whether to
fix - disposition does.

### Disposition: fix by default

**Default is `[fix]` for every finding, regardless of priority.** Little things
compound; style smell propagates into new code; deferring creates a hygiene
backlog that never gets done. Extract-helper refactors and naming cleanups are
part of healthy implementation, not a separate track.

Use `[defer]` ONLY if one of these three criteria applies:

1. **Needs user decision** - product/UX semantics, architectural direction, or
   anything where the fix depends on human intent rather than code judgment.
2. **Phase-sized effort** - the fix alone would take as long as an entire plan
   phase (major refactor, schema migration, multi-file architectural change).
3. **Extremely risky** - security-adjacent, data-integrity, unclear blast
   radius on unfamiliar code, or hard-to-reverse changes.

"This is just a style nit" is NOT a defer criterion. If it's worth mentioning,
it's worth fixing.

### Project-rule priority

Abide by the rules in the project's `AGENTS.md` and the user-global
`~/.claude/AGENTS.md` (plus anything they reference). Any violation of rules
found there is AT LEAST `[major]` priority; if the rule explicitly names the
pattern as causing bugs or being correctness-blocking, tag `[critical]`.
Project/user rules override generic review conventions.

### Honest-null rule

If the diff has no issues after you read it, output exactly `No issues.`
Only say this after you have actually read every hunk.

### MANDATORY: write review to file as your final tool call

Your final tool call MUST be a Write (or equivalent) to:

    <review-file-path>

The file's contents: everything after this Override block - your full review,
every `### Finding N:` section, and either `No issues.` or the finding list.
Start the file with a YAML header:

    ---
    review-type: <spec | code | batch | phase-N | final>
    task-or-scope: <e.g. Task 7.4 | Phase 12 | Final>
    reviewer-model: <your model name>
    commit-sha: <the sha or range under review>
    findings-count: <integer>
    ---

Return a brief summary (1-2 sentences + total finding count) in your text
response, but the file is the authoritative artifact. If you do not write the
file, your review is discarded and will be re-dispatched.
```

Reviewer prompt MUST also contain these two sections, clearly labeled:

- `## Implementer-Reported Summary (untrusted)` - implementer's report text.
- `## Actual Diff` - raw output of `git show <sha>` for single-task reviews, or `git diff <base>..<head>` for batched/phase/final reviews.

## Review Artifact Files

Every review MUST produce durable on-disk artifact. SHA-equivalent for reviews: orchestrator cannot claim `findings=0` without file on disk saying so; user can audit after the fact.

### Path convention

    <plan-dir>/reviews/<task-or-scope>-<review-type>.md

Examples:
- `docs/specs/m3/reviews/task-7.4-spec.md`
- `docs/specs/m3/reviews/task-7.4-code.md`
- `docs/specs/m3/reviews/batch-10.2-10.3-combined.md`
- `docs/specs/m3/reviews/phase-7-gate.md`
- `docs/specs/m3/reviews/phase-11-deep-review.md`
- `docs/specs/m3/reviews/final-deep-review.md`

`<plan-dir>` is directory containing plan and checklist files. Create `reviews/` subdirectory on first write.

### Orchestrator assigns path before dispatch

In each reviewer dispatch, orchestrator substitutes `<review-file-path>` placeholder with concrete absolute path. Reviewer writes to that path.

### Post-dispatch verification

After reviewer returns:

1. Check file exists at assigned path. If missing → review did not actually run (or reviewer disobeyed). Re-dispatch with sterner prompt; if fails again, halt and surface to user.
2. Read file and use its findings list as SOURCE OF TRUTH. Not summary in reviewer's text response.
3. Confirm file's YAML header's `findings-count` matches number of `### Finding N:` sections inside.

### For deep-reviews: normalization pass

`/deep-review` runs multiple parallel sub-reviewers (Codex review, Chrome MCP UI review, rule compliance, simplification, collateral change audit, Claude's own diff analysis). Each sub-reviewer has own findings. `/deep-review` skill consolidates them; in that consolidation, findings routinely dropped or merged. Well-known body-vs-summary gap.

For deep-review files ONLY, run extra normalization pass:

1. Dispatch small subagent (model: haiku) with deep-review file contents. Prompt:

   ```
   This file is the output of a /deep-review. Multiple sub-reviewers contributed
   findings. Your job: extract EVERY distinct observation from anywhere in the
   file - body text, summary, consolidated list, sub-reviewer sections - and
   emit them as a flat numbered list using the same `### Finding N:` format
   the top of the file specifies. Do NOT filter, merge, or downgrade. If a
   sub-reviewer mentioned something in prose but didn't put it in their
   consolidated list, it STILL becomes a finding. Preserve priority tags but
   re-number sequentially starting from 1.

   Write the normalized list to: <deep-review-file>.normalized.md

   Return just the finding count.
   ```

2. Use normalized file as source of truth for step F processing, not original deep-review file.
3. If normalized count > original deep-review's claimed count, that's expected and fine (skill was under-reporting). Log delta in Outcome (`(normalized: +N)` token).

This normalization pass does NOT run for per-task reviews. Single reviewer's single file is already flat.

## Outcome Slot Format

When filling `Outcome: \`<fill>\`` slot, use structured single-line format:

```
findings=N fixed=N deferred=N (review: <path>); <one-sentence summary>
```

Tokens:
- `findings=N` - total admissible findings (numbered, prioritized, disposition-tagged, cited).
- `fixed=N` - findings fixed by fix-implementer loop. Includes any priority; disposition is `[fix]`.
- `deferred=N` - findings written to `-deferred.md`. Only legitimately `[defer]` dispositions (user decision / phase-sized / extremely risky), plus any `[fix]` findings that genuinely BLOCKED after model upgrade.
- `review: <path>` - MANDATORY reference to review artifact file (e.g. `review: reviews/task-7.4-code.md`). SHA-equivalent: no artifact = no review happened. For deep-reviews, use normalized file path: `review: reviews/phase-11-deep-review.normalized.md`.
- `<summary>` - one sentence describing outcome.
- Optional priority breakdown: `(crit=N maj=N min=N cos=N)`.
- Optional: `inadmissible=N` for findings discarded for missing number/priority/disposition/citation.
- Optional: `(normalized: +N)` for deep-review outcomes where normalization pass surfaced more findings than consolidated list.

**Invariants:**
- `findings == fixed + deferred`. If mismatch, orchestrator lost finding. Halt.
- `review:` path points to file that exists, has matching YAML header, and has exactly `findings` `### Finding N:` sections.

Examples:
- `findings=0 fixed=0 deferred=0 (review: reviews/task-7.4-code.md); No issues.`
- `findings=10 fixed=10 deferred=0 (review: reviews/task-11.1-code.md, crit=1 maj=3 min=4 cos=2); All inline.`
- `findings=12 fixed=11 deferred=1 (review: reviews/phase-12-deep-review.normalized.md, normalized: +4); 11 inline; §5 deferred (user UX decision).`
- `findings=5 fixed=0 deferred=0 inadmissible=5 (review: reviews/task-9.2-code.md); All findings missing disposition; reviewer re-dispatched.`

Prose-only Outcomes (no `findings=` token OR no `review:` token) fail Final Verification.

## Per-Task Integrity Gate

After filling BOTH Outcome slots for a task (end of step H for the standard spec + code path, end of step I for batched tasks, or end of the combined-review shortcut), fly MUST invoke the integrity-check script before moving on. This is mandatory, not optional.

### Why this exists

Under context pressure, the orchestrator can forge review artifact files directly (write a plausible file with a `findings-count: 0` YAML header and a `No issues.` body) without ever dispatching a reviewer subagent. All the existing mtime, size, and YAML-header checks pass because the orchestrator is the one writing the file. Self-report cannot catch this failure mode; on-disk evidence from Claude Code's own per-subagent JSONL transcripts can.

The integrity-check script reads the CC subagent transcripts at `~/.claude/projects/<encoded-cwd>/<session>/subagents/agent-*.jsonl` and verifies that a real subagent actually wrote to the review file path AND did non-trivial work (at least 3 tool calls, consistent with reading the diff and writing the review).

### Invocation

Resolve the script path first. The skill ships at `.claude/skills/fly/integrity-check.sh` (in this dotfiles repo it lives under `~/.claude/skills/fly/integrity-check.sh`; inside a project using a plugin install it may live under the plugin cache). Use Glob if unsure:

`~/.claude/skills/fly/integrity-check.sh` (primary path)

Invoke via a single Bash tool call, passing the task id, the plan directory (the directory containing the checklist file), and the task's commit SHA:

```
bash <path-to-integrity-check.sh> <task-id> <plan-dir> <task-sha>
```

Output is one line on stdout:

- `PASS` (exit 0) - integrity verified. Proceed to the next task.
- `HALT: <reason>` (exit 1) - integrity failed. STOP immediately. Do NOT try to patch the symptom (e.g., re-dispatching the reviewer, re-writing the file, tweaking slots). Surface the HALT reason to the user verbatim. This is drift detection; the user needs to see it.

### Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>` that are NOT the last task in the batch: the script returns `PASS` silently because no review files are expected on non-last batched tasks. The phase gate (phase regression check + phase review gate) catches missing batch reviews. Run the integrity gate against the batch's LAST task id, where the review files actually live.

### Agent-agnostic caveat

The script is Claude Code specific. It depends on the `~/.claude/projects/.../subagents/agent-*.jsonl` layout. On non-CC agents it will HALT with `cannot locate CC project dir`; that is acceptable because the entire subagent dispatch mechanism `/fly` uses is already CC-specific.

## Periodic SKILL.md Re-read

Late-session drift is a predictable failure mode: rules that were fresh at task 1 get compressed away by task 15, and the orchestrator silently starts skipping or paraphrasing them. To counter that, fly maintains a counter of completed tasks (tasks whose full step sequence A through I has been ticked) in the current session.

At every 10th completed task - before starting task 11, task 21, task 31, and so on:

1. Re-read this SKILL.md file via the Read tool.
2. Continue. No other action required.

Purpose: refresh the discipline rules in context so that late-session tasks receive the same rigor as early-session tasks. This is a structural reminder, not a literal test. The cost is one Read tool call per ten tasks. Preflight's split target is 20 tasks per checklist, so this triggers at most twice per `/fly` run (task 10 and task 20).

## Phase Gates

After all tasks in phase complete (all per-task slots filled):

### Phase regression check (MANDATORY, runs before review gate)

Per-task TDD catches regressions inside each task's scope. Phase regression check catches regressions task-level tests didn't cover (unrelated tests newly broken, integration failures, etc.). Also defangs "it was a pre-existing failure" gaslighting: pre-existing = proven by running test at base commit, not asserted.

1. Invoke the regression script:

     bash <path-to-phase-regression.sh> <phase-first-commit-sha>^ <phase-last-commit-sha>

   (The caret `^` on the base SHA expands to its parent in the script's git
   invocations.) Resolve the script path the same way as integrity-check.sh
   (primary path `~/.claude/skills/fly/phase-regression.sh`, fall back to
   Glob if installed under a plugin cache).

2. Parse the single-line output:

     tests_pass=N tests_fail=N regressions=K | <test1> | <test2> | ...

   - If regressions=0: phase gate may proceed. Cache the `tests_pass=N
     tests_fail=N regressions=0;` prefix - it MUST prefix this phase's
     gate Outcome slot when it gets filled below.
   - If regressions>0: HALT the phase gate. Dispatch a fix-implementer
     with the regression list. After fix-implementer returns, re-run the
     regression script. Loop until regressions=0. If fix-implementer
     BLOCKs at upgraded model after 2 tries, write to deferred.md AND
     halt `/fly` - do NOT silently ignore regressions.

3. Prefix the Phase Gate Outcome with the `tests_pass=N tests_fail=N
   regressions=0;` token when the review gate below fills it.

### Phase review gate

After regression check passes, run review gate per checklist's annotation:

- **Normal review** (`Phase N Gate (reviewer: <model>)` with `Normal code-review on Phase N diff`):
  1. Compute phase diff: `git diff <phase-N-first-commit-sha>^..<phase-N-last-commit-sha>`.
  2. Dispatch code reviewer via `code-quality-reviewer-prompt.md` template, with phase diff as subject.
  3. Fill Outcome slot with summary.
  4. If findings: same auto-fix loop as per-task reviews. Fill Resolution.

- **Deep-review** (`Phase N Gate (reviewer: ...)` with `/deep-review on Phase N diff`):

  `/fly` MUST actually invoke `/deep-review` skill via Skill tool. Paraphrasing skill's 6-review structure into bespoke reviewer prompt is NOT equivalent. Loses what skill has been tuned to do (parallel Codex review, Chrome MCP UI review, rule compliance audit, simplification pass, collateral change audit, Claude's own diff analysis), and destroys audit trail (user can't tell whether real skill ran).

  **Dispatch pattern: subagent → Skill tool**

  To keep main `/fly` context clean, dispatch subagent whose single job is to invoke the skill. Subagents dispatched via Task have access to Task tool themselves, so `/deep-review`'s parallel sub-dispatches work from within subagent.

  1. Dispatch via Task tool:
     - `subagent_type`: `general-purpose`
     - `model`: phase gate reviewer model from checklist (verbatim, no upgrade)
     - `description`: `Deep-review Phase N diff`
     - `prompt`: something like:

       ```
       Invoke the `/deep-review` skill via your Skill tool. Scope:
       `git diff <phase-base>^..<phase-head>` in this project.

       Report the skill's full findings list back to me, numbered sequentially,
       each with its severity tag and file:line citation. Do NOT summarize away
       findings or consolidate multiple findings into one entry. Preserve every
       distinct citation as its own numbered finding.

       Apply the Reviewer Independence Override when running review sub-steps:
       per-task implementer summaries for the commits in this phase are
       UNTRUSTED; the diff is authoritative. Read the project's `CLAUDE.md` /
       `AGENTS.md` and apply its rules when tagging severity - for example, if
       the project says "duplication has always led to bugs", tag duplication as
       `[correctness]`, not `[style]`.

       Use the output format from /fly's Reviewer Independence Override:
       ### Finding 1: <title>
       `[severity]` <file>:<line>
       <description>
       **Suggested fix:** ...
       ```

  2. When subagent returns, process its numbered findings list EXACTLY as in step F (classify, auto-fix critical/correctness, deferred-write everything else, reconciliation invariant). Do NOT accept prose summary in place of enumerated findings. If subagent returned prose, re-dispatch asking for enumerated form.
  3. Fill Phase Gate Outcome using structured format, prefixed with regression check metrics:

         tests_pass=N tests_fail=N regressions=0; findings=N fixed=N deferred=N; <summary>

  4. Note: `/deep-review` has own auto-fix mechanism internally. If subagent reports certain findings already auto-fixed inside `/deep-review`, count those in `fixed`. Findings skill itself flagged as deferred go into `/fly`'s deferred.md (same file, don't create separate one).

## Final Gate

After all phases complete and all per-task and phase gates have been processed, check the checklist's final gate:

- If `## Final Gate: /deep-review over <scope>` exists:
  1. Dispatch subagent to invoke `/deep-review` via Skill tool, same pattern as deep-review Phase Gate above (see "Dispatch pattern: subagent → Skill tool"). Scope per checklist annotation.
  2. Process returned findings with accounting invariant (`findings = fixed + deferred`). Default disposition is `[fix]`; only legitimately-defer findings go to deferred.md.
  3. Fill Outcome slot using structured format: `findings=N fixed=N deferred=N; <summary>`.
  4. Fill Resolution slot per outcome (Fixed / deferred references / mix).

- If `**Final gate not needed - all phases have deep-review coverage.**` exists: skip; nothing to do.

## Deferred File Handling

`<plan-basename>-deferred.md` holds findings that legitimately cannot be fixed inline. **Deferred is exception, not default.** Default is fix-inline; deferral requires justification.

Finding qualifies for deferral only if at least one applies:

1. **Needs user decision** - fix depends on product/UX semantics or architectural direction only user can supply.
2. **Phase-sized effort** - fix alone would consume as much time as entire plan phase (major refactor, schema migration, large architectural change).
3. **Extremely risky** - security-adjacent, data-integrity, unclear blast radius on unfamiliar code, hard-to-reverse.

Also: `[fix]` finding that fix-implementer BLOCKED on after model upgrade can legitimately defer, IF evaluation shows it meets one of three criteria. Failed fix attempt on tractable problem is not defer. Halt and surface to user instead.

"It's just a style nit" is NOT defer criterion. If worth mentioning, worth fixing.

Each finding gets OWN `§N` entry. Format:

```markdown
# Deferred Items: <feature>

> Items flagged during `/fly` execution that require your attention - user decision needed, too large for inline fix, or too risky to auto-apply.

## §1: <task/gate context> - [priority] <short title>

**Finding:** <description from reviewer, preserving file:line citation>

**Why deferred:** <one of: "needs user decision - <specifics>" | "phase-sized effort - <estimate>" | "extremely risky - <blast radius>" | "BLOCKED at upgraded model; fits defer criterion X because <reason>">

**Suggested fix:** <from reviewer's output>
```

When writing deferred item:
1. Assign next available `§N`.
2. Include priority in heading.
3. Update Resolution slot in checklist: `Action: Deferred to <plan-basename>-deferred.md §N`.

If deferred file doesn't exist yet, create it with header before appending `§1`.

**Watch defer rate.** If writing more than 1-2 defer entries per review, pause: either reviewer is mis-disposing findings (re-dispatch), or task genuinely needs user's attention (halt `/fly` and surface instead of accumulating defers silently).

## Final Verification

After all tasks, phase gates, and final gate are processed, run the
verification block at the bottom of the checklist. Verification is
performed by a single bash script invocation:

    bash <path-to-final-verify.sh> <checklist-path>

Resolve the script path the same way as integrity-check.sh (primary path
`~/.claude/skills/fly/final-verify.sh`, fall back to Glob if installed
under a plugin cache). Invoke via a single Bash tool call.

Script output:

- `PASS` on success: all checks passed. Proceed to tick each verification
  checkbox in the checklist (via Edit) and emit the Completion message.
- `HALT: <summary>` on failure: the preceding lines enumerate specific
  failures (unticked boxes, unfilled slots, mismatched findings counts,
  missing phase-gate regression prefix, etc.). Do NOT tick verification
  checkboxes. Surface the full failure list to the user.
- `WARN: ...` lines are soft signals (e.g., fabrication-pattern rate
  exceeded). Surface to the user but do not HALT.
- `DEFERRED:` block contains the full `<plan>-deferred.md` contents;
  surface to the user as "deferred items need manual review before
  shipping."

The previous bulleted list of individual checks is preserved in the
script itself for maintainers; fly's job here is to invoke, parse, and
react.

## Completion

After final verification passes:
1. Print final report: tasks completed, commits made, deferred items (if any), time taken.
2. **DO NOT auto-invoke `/ship` or `/superpowers:finishing-a-development-branch`.** Explicit user command only.
3. Suggest next step: "Ready to ship? Run `/ship` when you've reviewed any deferred items."

## Rationalization Table

`/fly` exists because LLM coordinators rationalize shortcuts under context pressure. Before skipping any step, check this table:

| Excuse | Reality |
|--------|---------|
| "This task is trivial, no review needed" | Checklist has review gate checkboxes for every task. Skipping violates contract. |
| "I already did the spec review conceptually" | Outcome slot requires written summary. Mental review doesn't fill slot. |
| "Finding is minor, skip it" | Resolution slot MUST be filled. Valid Actions: Fixed / FIXME / Deferred. Not "ignored", not "skipped", not empty. |
| "Fix-implementer reported BLOCKED, move on" | Upgrade model one tier and retry FIRST. If still BLOCKED, write to `-deferred.md`. Never silent skip. |
| "Context pressure, let me batch some tasks myself" | Batching is preflight's decision, encoded in checklist. Do NOT invent new batches at execution time. |
| "Running the review feels redundant, code looks fine" | "Looks fine" is not review. Dispatch reviewer subagent. Fill slot. |
| "The plan doesn't have TDD steps, so I'll skip TDD" | Either checklist has `[INJECTED]` TDD steps, OR implementer dispatch has TDD override instruction. Do TDD. |
| "I'll fix all review findings at the end in one batch" | Each review's Resolution must be filled before moving to next gate. No accumulating findings across gates. |
| "Verification block is just a formality" | Verification catches tasks you forgot. Tick each box only after actually verifying its condition (grep for unticked boxes, check SHA slots aren't `<fill>`, etc.). |
| "Deep-review on this phase is slow, let me skip" | Preflight decided which phases get deep-review to satisfy invariant. Skipping breaks it. |
| "The implementer's summary says it's good, reviewer can skim" | Summary is UNTRUSTED. Reviewer must read `## Actual Diff` independently. Dispatching reviewer with only summary is reviewer priming. |
| "I'll just write 'Looks good' in the Outcome slot" | Outcome needs `findings=N fixed=N deferred=N`. Prose-only fails Final Verification. If you didn't count, you didn't review. |
| "Reviewer returned findings without file:line, I'll act on them anyway" | Inadmissible. Fabricated findings without citations waste fix cycles. Discard, log `inadmissible=N`, move on. |
| "Auto-fixing this style nit won't hurt" | Only `[critical]` / `[correctness]` auto-fix. Style/cosmetic amplifies fabricated-finding waste. Log and move on. |
| "That test was probably failing on main anyway" | Phase regression check: run suite at phase base commit. Assertion without running is gaslighting. |
| "This task looks harder than sonnet, let me use opus to be safe" | NO. Checklist is contract. If model is wrong, HALT and ask user to edit checklist. Silent upgrades destroy audit trail. Checklist says sonnet, dispatch log says opus, reality becomes un-reproducible. |
| "Opus is better, it won't hurt to upgrade" | Cost and audit: opus costs more, and "we used sonnet" becomes lie when checklist-vs-dispatch drift. Preflight picked sonnet for reason. Respect decision or surface disagreement to user. |
| "I'll use opus for the reviewer because this code is tricky" | Same rule. Reviewer model is in checklist. Upgrading silently primes review outcome (opus reviews differ from sonnet reviews) and defeats preflight's per-gate assignment. |
| "Defaulting to opus is fine for everything" | NOT fine. Preflight assigned per-task models to balance cost, latency, appropriate rigor. Fly run that always uses opus has ignored checklist. |
| "Reviewer returned 20 findings, let me consolidate the main ones" | NO. Every admissible finding processed by number. Consolidation into prose loses detail. Fix it or defer it (with valid defer reason). |
| "This cosmetic finding can wait for a hygiene pass" | NO. Default disposition is [fix]. Cosmetic nits compound into quality drift; later tasks copy the smell. Fix now. Cheaper than whack-a-mole later. |
| "Let me defer this 5-minute extract-helper refactor" | Extract-helper refactors are part of healthy implementation, not separate track. Only defer if fix is phase-sized, needs user decision, or extremely risky. |
| "Let me paraphrase /deep-review's structure into a subagent prompt instead of invoking the skill" | NO. Paraphrasing destroys skill's tuned behavior (parallel Codex review, Chrome MCP UI review, etc.) and destroys audit trail. Dispatch subagent that invokes skill via Skill tool. |
| "The reviewer tagged this [minor] so I won't bother" | Priority doesn't gate fix; disposition does. If it's [fix], fix it regardless of priority. |
| "findings = 10, fixed = 2, deferred = 0, let me note '8 style findings' in the summary" | INVARIANT VIOLATION: findings = fixed + deferred. 8 findings disappeared. Halt. |
| "The reviewer tagged this [defer] so I'll defer it" | Check "Why defer" reason. If doesn't cite one of 3 criteria (user decision / phase-sized / extremely risky), reject and re-dispatch. Reviewer misdisposed. |
| "Most of these should defer because they're out of scope" | If reviewer is producing high defer rate, reviewer is wrong or task scope is wrong. Re-dispatch or halt. Silent acceptance of mass-defer defeats fix-inline principle. |
| "I read the diff myself, it's clearly fine, no need for a real reviewer" | Your read is not reviewer dispatch. Review artifact file must exist and must be produced by dispatched reviewer subagent. Orchestrator inspection is not substitute. |
| "Meta-verifier said SUSPICIOUS but I'm sure the review was fine" | SUSPICIOUS triggers re-dispatch of REAL reviewer. Override attempts destroy contract. Re-dispatch, or HALT and surface to user. |
| "findings=0, skip the integrity gate, I just filled the slot and it's fine" | NO. The integrity gate is mandatory after every task. It reads CC's subagent transcript to verify the reviewer actually ran. Self-report is not proof. |
| "I already read the skill, re-reading at task 10 is a waste" | The re-read is a structural reminder, not a literal test. Its purpose is to refresh compressed rules before late-session drift sets in. Do it. |
| "The integrity gate HALTed but I'm sure the review was real, let me just continue" | HALT means the evidence doesn't support your claim. Do not override. Surface to user. |

## Red Flags - STOP

If you catch yourself thinking any of these, STOP and re-read Rationalization Table:

- "Just this one review can be skipped"
- "The finding is so minor it's not worth fixing"
- "I'll come back to this slot later"
- "This is close enough to complete"
- "Let me batch these myself since preflight didn't"
- "Reviewer said 'mostly fine', that counts as approved"
- "I'll fill in the SHA slot later from memory"
- "Ticking the verification box is fine, I'm sure it's done"
- "The implementer said DONE, no need to verify each step checkbox"
- "This task is complex, opus will be safer than the checklist's sonnet"
- "Let me just use opus for everything, it's fine"
- "The reviewer will be more rigorous on opus, so I'll swap the model"
- "Let me consolidate these findings into main points"
- "The deep-review returned 20 findings, I'll focus on the critical ones"
- "This nit can wait for a hygiene pass"
- "Default to defer and let the user triage"
- "Fix-inline for a style thing is overkill, just defer"
- "Invoking /deep-review as a full skill is heavy, let me just replicate its prompts"
- "The reviewer tagged [defer] so I'll defer it" (without checking the defer reason)
- "The task said use sonnet but haiku will be fine" (downgrade drift is as bad as upgrade drift)
- "Writing 'No issues.' to the file is basically the same as dispatching a reviewer"
- "Meta-verifier is SUSPICIOUS but I trust the original review, overriding"
- "findings=0, skip the integrity gate, I just filled the slot and it's fine"
- "Re-reading SKILL.md at task 10 is unnecessary since I already read it"
- "Integrity gate HALTed but I'm sure the work is fine; override and continue"

**All of these mean: you are about to violate the checklist contract. Do the work.**

## The Iron Rule

Every slot value traces to a specific tool call. If you cannot point to
the Task, Write, Edit, or Bash call that produced it, the slot is unfilled
and the work is incomplete.

- Every `SHA:` slot traces to an implementer subagent's report.
- Every `Outcome:` slot traces to a review file on disk that a
  **dispatched reviewer subagent** wrote. The `review:` token names the
  file; the file's mtime is after the commit SHA timestamp; the file's
  YAML `commit-sha` matches.
- Every `Resolution:` slot traces to either a fix-implementer subagent's
  commit, a FIXME in source, or a `<plan>-deferred.md` section.

Mental review is not a review. A reviewer is a Task dispatch that returns
and writes a file. If no Task dispatch happened, no review happened.

The per-task integrity gate (invoking `integrity-check.sh`) enforces this
mechanically after every task. The final verification sweep enforces it
structurally at the end. Both must pass before `/fly` exits successfully.
