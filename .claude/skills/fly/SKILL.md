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

## Helper Scripts

Four bash scripts live adjacent to this SKILL.md in the same directory. Use the "Base directory for this skill" path injected by the runtime to locate them:

```
<base-dir>/integrity-check.sh   - per-task reviewer-dispatch verification
<base-dir>/final-verify.sh      - end-of-run checklist sweep
<base-dir>/phase-regression.sh  - phase gate regression check
<base-dir>/tick-steps.sh        - bulk-tick plan-step checkboxes
<base-dir>/reviewer-override.md - Reviewer Independence Override block (Read once, cache, append to every reviewer dispatch)
```

**On first use in a session**, resolve `SCRIPT_DIR` once and cache it:

1. If the runtime injected "Base directory for this skill: <path>", use that path as `SCRIPT_DIR`.
2. Otherwise, find by name: `SCRIPT_DIR=$(dirname "$(find ~/.claude -name "integrity-check.sh" -path "*/fly/*" 2>/dev/null | head -1)")`
3. If still empty, HALT: "Fly helper scripts not found. Check skill installation."

All script invocations below use `$SCRIPT_DIR/<script-name>`. Do NOT use Glob or ad-hoc path guessing.

## Triggers

User invokes `/fly <checklist-path>` - typically in a fresh Claude Code session for clean context.

## Input

- **Primary:** path to a preflight checklist file (produced by `/preflight`).
- **Secondary:** the per-session plan file referenced in the checklist's `READ FIRST` header (e.g., `plan-1.md`). Contains task content, conventions, code blocks for this session's tasks.
- Fly reads both files on entry: checklist for tracking (what to tick/fill), plan file for task content (what to implement).

## State Detection

On entry, read the checklist file. Also read the plan file referenced in the checklist's `READ FIRST` header. Then classify the checklist's state:

- **Fresh run** - all checkboxes are unticked (`- [ ]`) and all slots contain `<fill>`.
- **Mid-flight pickup** - some checkboxes are ticked (`- [x]`) or some slots are non-`<fill>`. Resume from the first unticked checkbox or unfilled slot.
- **Already complete** - every checkbox ticked, every slot filled, verification block ticked. Print "Already complete. Nothing to do." and exit.

Announce the detected mode at start:
- Fresh run: "Flying <checklist>. Mode: fresh run."
- Mid-flight: "Flying <checklist>. Mode: resuming from Task <X.Y>."
- Complete: "Already complete. Nothing to do."

## Multi-File Checklist Support

`/fly` executes exactly ONE checklist file per invocation. Each checklist has a companion per-session plan file (e.g., `plan-1.md`): the checklist tracks progress, the plan file holds task content. Together they form a complete session: its own tasks, its own phase gates, and (if present) its own final gate.

When a plan is large enough that preflight splits it, preflight emits multiple checklist files alongside the plan, typically named like:

- `<plan>-checklist-1.md`
- `<plan>-checklist-2.md`
- `<plan>-checklist-3.md`

In that case, the user runs `/fly <checklist-N>` once per file, in order, each in a fresh Claude Code session. Each invocation is a complete run over its own file. Fly does not cross-reference other checklist files, does not attempt to read sibling checklists, and does not coordinate state between them. The checklist file you were handed is the universe for this invocation.

## Template Resolution

Template Resolution applies ONLY to per-task and phase-level dispatches of implementer, spec-reviewer, and code-quality-reviewer subagents. It does NOT apply to deep-review gate dispatches - those invoke the `/deep-review` skill directly via the Skill tool in main context, without templates. See "Phase Gates - Deep-review" and "Final Gate" for that pattern.

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
   - `[FULL TEXT of task from plan - paste it here, don't make subagent read file]` → the task's full text, read from the per-session plan file. Match the checklist's task ID (e.g., Task 0.1) to the corresponding `### Task 0.1:` section in the plan file.
   - `[Scene-setting: where this fits, dependencies, architectural context]` → a short paragraph describing the task's context (read the checklist's overall goal and phase description; summarize).
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

    bash $SCRIPT_DIR/tick-steps.sh <checklist-path> <task-id> <comma-separated-step-numbers>

Example: if the implementer completed steps 1, 2, 3, 4 of Task 3.2:

    bash ~/.claude/skills/fly/tick-steps.sh docs/specs/2026-04-18-feature/checklist.md 3.2 1,2,3,4

Script output: `OK <N checkboxes ticked>` on success, `ERROR <reason>`
on failure. On ERROR, do NOT proceed to step D; halt and surface.

Rationale: N Edit calls per task (one per step) bloat orchestrator
context unnecessarily when the operation is mechanical find-and-replace.
The script handles all steps in one `sed` pass.

### D. Fill commit SHA slot

Read the implementer's report for the commit SHA. Edit the checklist to replace the task's `SHA: \`<fill>\`` with `SHA: \`<actual-sha>\``.

### E. Dispatch reviewer (combined by default)

For tasks annotated `Review: combined` (default): dispatch ONE reviewer covering both spec + code concerns.

1. Resolve `code-quality-reviewer-prompt.md` via Glob + Read.
2. Review file path: `<plan-dir>/reviews/task-<id>-combined.md`. Create `reviews/` if missing.
3. Substitute placeholders:
   - `[FULL TEXT of task requirements]` → the task's text from the per-session plan file.
   - `[From implementer's report]` → the implementer's summary, placed under the heading `## Implementer-Reported Summary (untrusted)`.
4. Append a `## Actual Diff` section containing the output of `git show <task-sha>`.
5. Append the Reviewer Independence Override block verbatim, with `<review-file-path>` replaced by the absolute path.
6. Add a `## Review scope` section to the prompt with explicit dual focus:
   ```
   This is a COMBINED review covering both spec and code concerns. Emit findings under both lenses:
   ### Spec concerns: does the commit satisfy plan requirements? (missing steps, wrong behavior, scope drift)
   ### Code concerns: quality, correctness, conventions, duplication, edge cases.
   ```
7. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: the reviewer model specified in the checklist (typically the higher of spec+code defaults; sonnet for most)
   - `description`: `Combined review <task id>`
   - `prompt`: the substituted + augmented template
8. Wait for report. Verify the review file exists. If missing, re-dispatch; if fails again, halt.
9. Read the review file. `### Finding N:` sections are source of truth.
10. Fill the `Combined review` Outcome slot using the structured format.

**For `Review: separate` tasks** (high-risk: opus implementer / security / schema / broad blast-radius): use the legacy two-step pattern - dispatch spec-reviewer first (file: `task-<id>-spec.md`), then code-reviewer (file: `task-<id>-code.md`), filling the `Spec review` and `Code review` Outcome slots separately. Same fix-loop semantics apply per review.

### F. Handle findings

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
5. Re-dispatch spec reviewer (full cycle: Reviewer Independence Override, fresh diff). The re-reviewer writes to the SAME review file path, overwriting the prior review. This is correct - the file should reflect the CURRENT state of the code. Loop until no `[fix]` admissible findings remain.

**Deferred-write (only `[defer]` findings + any `[fix]` that legitimately blocked):**

Each deferred finding gets its own `§N` entry with priority in the heading and the specific defer reason (which of the 3 criteria). If you find yourself writing many defer entries in a single review, that's a signal - either the reviewer is mis-disposing (re-dispatch), or the scope of this task genuinely needs the user's attention (halt, surface).

**Fill the Outcome slot from the FINAL review file** (after all fix loops complete). The Outcome's `findings=N` must match the current file on disk, not an earlier review round. If the fix loop ran, the final re-review file is authoritative:

    findings=N fixed=N deferred=N; <summary>

Optional: `inadmissible=N`. Invariant: `findings == fixed + deferred`.

**Fill the Resolution slot:**

- No findings at all: `None needed`.
- All fixed, none deferred: `Fixed in <last-fix-commit-sha>`.
- Some deferred: `Fixed in <sha>; N deferred to -deferred.md §A-§Z` (or just the defer reference if nothing was fixed inline).

### G. Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>`:
- Skip step E for tasks that are NOT the last task in the batch.
- For the LAST task in the batch, run combined review on the combined diff (`git diff <first-batch-commit>^..<last-batch-commit>`). Review file path: `<plan-dir>/reviews/batch-<first-id>-<last-id>-combined.md`. Fill the `Batch review` slots on the last task.

## Reviewer Independence Override

Every reviewer dispatch (per-task combined or separate in E, batched review in G, phase gate review, final gate) MUST include the Reviewer Independence Override block, appended AFTER the upstream template's placeholder substitutions.

The block lives at `$SCRIPT_DIR/reviewer-override.md` (sibling to this SKILL.md). Read it once per session and cache. Substitute `<review-file-path>` with the absolute path the orchestrator assigns (see "Review Artifact Files").

Reviewer prompt MUST also contain, clearly labeled:

- `## Implementer-Reported Summary (untrusted)` - implementer's report text.
- `## Actual Diff` - raw output of `git show <sha>` for single-task reviews, or `git diff <base>..<head>` for batched/phase/final reviews.

## Review Artifact Files

Every review MUST produce durable on-disk artifact. SHA-equivalent for reviews: orchestrator cannot claim `findings=0` without file on disk saying so; user can audit after the fact.

### Path convention

    <plan-dir>/reviews/<task-or-scope>-<review-type>.md

Examples:
- `docs/specs/2026-04-18-feature/reviews/task-7.4-spec.md`
- `docs/specs/2026-04-18-feature/reviews/task-7.4-code.md`
- `docs/specs/2026-04-18-feature/reviews/batch-10.2-10.3-combined.md`
- `docs/specs/2026-04-18-feature/reviews/phase-7-gate.md`
- `docs/specs/2026-04-18-feature/reviews/phase-11-deep-review.md`
- `docs/specs/2026-04-18-feature/reviews/final-deep-review.md`

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
- `findings=12 fixed=11 deferred=1 (review: reviews/phase-12-deep-review.normalized.md, normalized: +4); 11 inline; §5 deferred (user UX decision).`

Prose-only Outcomes (no `findings=` token OR no `review:` token) fail Final Verification.

## Per-Task Integrity Gate

After filling BOTH Outcome slots for a task (end of step H for the standard spec + code path, end of step I for batched tasks, or end of the combined-review shortcut), fly MUST invoke the integrity-check script before moving on. This is mandatory, not optional.

### Why this exists

Under context pressure, the orchestrator can forge review artifact files directly (write a plausible file with a `findings-count: 0` YAML header and a `No issues.` body) without ever dispatching a reviewer subagent. All the existing mtime, size, and YAML-header checks pass because the orchestrator is the one writing the file. Self-report cannot catch this failure mode; on-disk evidence from Claude Code's own per-subagent JSONL transcripts can.

The integrity-check script reads the CC subagent transcripts at `~/.claude/projects/<encoded-cwd>/<session>/subagents/agent-*.jsonl` and verifies that a real subagent actually wrote to the review file path AND did non-trivial work (at least 3 tool calls, consistent with reading the diff and writing the review).

### Invocation

Use `$SCRIPT_DIR` resolved per "Helper Scripts" section above. Invoke via single Bash tool call:

```
bash $SCRIPT_DIR/integrity-check.sh <task-id> <plan-dir> <task-sha>
```

Output is one line on stdout:

- `PASS` (exit 0) - integrity verified. Proceed to the next task.
- `HALT: <reason>` (exit 1) - integrity failed. STOP immediately. Do NOT try to patch the symptom (e.g., re-dispatching the reviewer, re-writing the file, tweaking slots). Surface the HALT reason to the user verbatim. This is drift detection; the user needs to see it.

### Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>` that are NOT the last task in the batch: the script returns `PASS` silently because no review files are expected on non-last batched tasks. The phase gate (phase regression check + phase review gate) catches missing batch reviews. Run the integrity gate against the batch's LAST task id, where the review files actually live.

### Agent-agnostic caveat

The script is Claude Code specific. It depends on the `~/.claude/projects/.../subagents/agent-*.jsonl` layout. On non-CC agents it will HALT with `cannot locate CC project dir`; that is acceptable because the entire subagent dispatch mechanism `/fly` uses is already CC-specific.

## Periodic SKILL.md Re-read

Every 10 completed tasks (before task 11, 21, ...), Read this SKILL.md to refresh discipline against late-session drift. One Read per 10 tasks; triggers at most twice per `/fly` run.

## Phase Gates

After all tasks in phase complete (all per-task slots filled):

### Phase regression check (MANDATORY, runs before review gate)

Per-task TDD catches regressions inside each task's scope. Phase regression check catches regressions task-level tests didn't cover (unrelated tests newly broken, integration failures, etc.). Also defangs "it was a pre-existing failure" gaslighting: pre-existing = proven by running test at base commit, not asserted.

1. Invoke the regression script:

     bash $SCRIPT_DIR/phase-regression.sh <phase-first-commit-sha>^ <phase-last-commit-sha>

   (The caret `^` on the base SHA expands to its parent in the script's git
   invocations.)

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

  **Dispatch pattern: direct Skill tool invocation in main context**

  Invoke `/deep-review` directly via the Skill tool from main fly context. Do NOT wrap in a Task-dispatched subagent - subagents cannot nest-dispatch Task, which `/deep-review` may need internally for its parallel sub-reviewers.

  1. Invoke via Skill tool: `/deep-review` with scope `git diff <phase-base>^..<phase-head>`.
  2. When `/deep-review` completes, process its findings list as in step F (classify, auto-fix, deferred-write, reconciliation invariant). Do NOT accept prose summary in place of enumerated findings.
  3. Fill Phase Gate Outcome using structured format, prefixed with regression check metrics:

         tests_pass=N tests_fail=N regressions=0; findings=N fixed=N deferred=N; <summary>

  4. `/deep-review` has own auto-fix mechanism internally. If it reports certain findings already auto-fixed, count those in `fixed`. Findings it flagged as deferred go into `/fly`'s deferred.md (same file, don't create separate one).

  Context cost note: running `/deep-review` in main context adds its sub-reviewer output to fly's transcript. With 1M context and <=20 tasks per session, this is acceptable. The alternative (subagent wrapper) fails due to nested Task dispatch restrictions.

  **Codex sub-reviewer caveat:** `codex review --base <X>` takes a BRANCH name, not a SHA. Phase-gate scope is a SHA range (`<phase-base>^..<phase-head>`). Create a temp branch at the base SHA before invoking: `git branch -f /tmp/codex-base <phase-base>^ && codex review --base /tmp/codex-base && git branch -D /tmp/codex-base`. Do NOT skip codex - it's load-bearing for deep-review.

### Phase end-state verification

After filling the phase gate Outcome + Resolution, check the phase's end-state verification section (written by preflight):

- **tests-only**: skip (regression check + integration tests covered it).
- **has-residual**: nothing to do per-phase. The end-of-run synthetic deferred-resolution task collects `Residual manual test` lines across all phases and surfaces them as the "Try it yourself" walkthrough.

## Final Gate

After all phases complete and all per-task and phase gates have been processed, check the checklist's final gate:

- If `## Final Gate: /deep-review over <scope>` exists:
  1. Invoke `/deep-review` directly via Skill tool (same as Phase Gate deep-review pattern - direct invocation, no subagent wrapper). Scope per checklist annotation.
  2. Process returned findings with accounting invariant (`findings = fixed + deferred`). Default disposition is `[fix]`; only legitimately-defer findings go to deferred.md.
  3. Fill Outcome slot using structured format: `findings=N fixed=N deferred=N; <summary>`.
  4. Fill Resolution slot per outcome (Fixed / deferred references / mix).

- If `**Final gate not needed - all phases have deep-review coverage.**` exists: skip; nothing to do.

## Deferred File Handling

**Prefer doing over deferring.** Default is fix-inline; the synthetic deferred-resolution task at end of run will process whatever does land in the deferred file anyway, so deferring just adds round-trips. The 3 valid defer criteria (needs user decision / phase-sized / extremely risky) are spec'd canonically in `reviewer-override.md` - reviewers see them there.

`<plan-basename>-deferred.md` format. Each finding gets its own `§N` entry:

```markdown
# Deferred Items: <feature>

## §1: <task/gate context> - [priority] <short title>

**Finding:** <reviewer description, preserving file:line citation>
**Why deferred:** <which of the 3 criteria + specifics>
**Suggested fix:** <from reviewer's output>
```

Update Resolution slot when writing: `Action: Deferred to <plan-basename>-deferred.md §N`. Create the file with the header before appending `§1` if it doesn't exist.

**Watch defer rate.** More than 1-2 defer entries per review = signal: either reviewer is mis-disposing (re-dispatch), or task scope is too big (halt and surface to user). Don't accumulate defers silently.

## Final Verification

After all tasks, phase gates, and final gate are processed, run the
verification block at the bottom of the checklist. Verification is
performed by a single bash script invocation:

    bash $SCRIPT_DIR/final-verify.sh <checklist-path>

Script output:

- `PASS` on success: all checks passed. Proceed to tick each verification
  checkbox in the checklist (via Edit) and emit the Completion message.
- `HALT: <summary>` on failure: the preceding lines enumerate specific
  failures (unticked boxes, unfilled slots, mismatched findings counts,
  missing phase-gate regression prefix, etc.). Do NOT tick verification
  checkboxes. Surface the full failure list to the user.
- `WARN: ...` lines are soft signals (e.g., fabrication-pattern rate
  exceeded). Surface to the user but do not HALT.
- `DEFERRED:` block contains the full `<plan>-deferred.md` contents.
  Do NOT dump verbatim to the user. The preflight checklist's final
  `[SYNTHETIC: deferred-resolution]` task handles it: a fresh subagent
  resolves what it can (dispatches implementer, commits) and returns
  ONLY items that need the user's input, each with a recommendation +
  options (or do-now/spawn/skip if it's a follow-up). Surface that
  return value to the user as-is. For any item the user picks "spawn"
  on, invoke `mcp__ccd_session__spawn_task` from your main context
  with the item's title + tldr + a self-contained prompt from the
  deferred.md §N entry (subagents lack access to that tool).

The previous bulleted list of individual checks is preserved in the
script itself for maintainers; fly's job here is to invoke, parse, and
react.

## Completion

After final verification passes:
1. Print final report: tasks completed, commits made, deferred items (if any), time taken.
2. The synthetic deferred-resolution task already surfaced any "Try it yourself" walkthrough; surface its return value verbatim if you haven't already.
3. **DO NOT auto-invoke `/ship`.** Suggest: "Ready to ship? Run `/ship` when you've reviewed any deferred items."

## Discipline: shortcuts to NEVER take

`/fly` exists because LLM coordinators rationalize shortcuts under context pressure. The checklist is the contract; every slot traces to a tool call that produced it. If you can't point to the Task / Write / Edit / Bash call that filled a slot, the slot is unfilled.

If you catch yourself thinking any of these, STOP - you're about to violate the contract:

| If you're tempted to... | Reality |
|---|---|
| Skip a review ("trivial", "code looks fine", "I read the diff") | Review = dispatched subagent + on-disk file. No dispatch, no review. Per-task integrity gate catches this; do not try to override. |
| Use a different model than checklist says (upgrade "to be safe" or downgrade "looks easy") | Checklist IS the contract. Silent drift breaks the audit trail. If the model is wrong, HALT and ask user to edit. Same for reviewer model. |
| Skip TDD because the task text didn't mention it | Implementer dispatch always appends TDD override. Do TDD. |
| Consolidate / merge / paraphrase reviewer findings | Every numbered finding processed by number. `findings == fixed + deferred` invariant. Halt if violated. |
| Defer a finding without one of the 3 valid criteria (user decision / phase-sized / extremely risky) | Reject the disposition and re-dispatch reviewer. Default = `[fix]`; deferring just adds round-trips since deferred items get processed at end of run anyway. |
| Write "Looks good" in an Outcome slot | Outcome needs `findings=N fixed=N deferred=N (review: <path>)`. Final verification rejects prose-only. |
| Act on findings missing number/priority/disposition/citation | Inadmissible. Discard, log `inadmissible=N`, move on. |
| Tick the final verification block without actually running checks | Run `final-verify.sh`. Tick only after PASS. |
| Skip the periodic SKILL.md re-read at task 10/20 | Structural reminder. One Read. Do it. |
| Override an integrity-gate or final-verify HALT because "the work is really fine" | HALT means evidence doesn't support the claim. Surface to user, don't override. |

**All shortcuts mean: you are about to violate the checklist contract. Do the work.**
