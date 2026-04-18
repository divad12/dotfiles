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

## Octopus Mode Detection

After state detection, grep the checklist for `Octopus:` tokens in `## Phase` headers:

- **Any found** → octopus mode. The checklist carries per-phase `Octopus: <status> (coordinator: <model>)` tokens, and fly acts as a main-side dispatcher for per-phase subagents (see "Octopus Main Loop" below). Single-orchestrator code paths for per-task loops still run, but they run INSIDE the phase subagents, not in main.
- **None found** → single-orchestrator mode (unchanged behavior). Fly walks tasks and phase gates itself.

Announce the detected octopus mode alongside the state announcement:
- "Flying <checklist>. Mode: fresh run | single_orchestrator."
- "Flying <checklist>. Mode: resuming from Task <X.Y> | octopus_single_session."
- "Flying <checklist>. Mode: resuming | octopus_multi_session."

Mode name strings (use verbatim): `single_orchestrator`, `octopus_single_session`, `octopus_multi_session`. The single/multi distinction is derived from phase count: if phase count exceeds `phase_session_cap` (10), mode is `octopus_multi_session`; otherwise `octopus_single_session`. Preflight's terminal summary surfaces the same strings.

## Phase-Scoped Invocation (`--phase=N`)

Fly accepts a `--phase=N` scope argument in its invocation string (e.g., passed by main via the Skill tool `args` parameter, or appearing as an explicit token in the prompt after the checklist path). When present, fly operates in phase-scoped mode:

- Walks only Phase N's tasks using the existing per-task loop (A-I, unchanged).
- Runs Phase N's phase gate (normal or `/deep-review` per checklist) after all tasks complete.
- Honors the existing mid-flight pickup logic: if some slots in Phase N are already filled (from a prior failed dispatch), resume from the first gap.
- Emits the 4-line receipt (see "Receipt Format" below) as the final report back to main.

Phase-scoped fly does NOT:
- Run the final gate.
- Run the final verification sweep.
- Update any `Octopus:` status headers (main owns those).
- Enter the octopus main loop (no nesting).

All /fly discipline (review-artifact mandate, HALT heuristics, Rationalization Table, reviewer independence override, structured Outcome format) applies unchanged inside the phase scope.

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

## Octopus Main Loop

Runs ONLY when mode is octopus (checklist has `Octopus:` tokens) AND `--phase=N` is NOT set. Phase-scoped fly skips this section entirely and runs the per-task loop directly against its assigned phase.

After announcing mode, main enters the octopus loop:

```
session_phase_count = 0
for each phase in checklist (top-to-bottom):
    parse Octopus: status from phase header
    if status == "done":
        continue
    if session_phase_count >= phase_session_cap (10):
        halt with session-window message; exit fly cleanly.

    flip phase header: "pending" or "in-flight:<old>" -> "in-flight:<new-id>"
        (new id: short timestamp + short random suffix; audit breadcrumb only)
    dispatch phase subagent via Task tool:
        subagent_type: general-purpose
        model: coordinator model from phase header (VERBATIM, no drift, HALT if disagree)
        description: "Octopus phase <N>: <phase name>"
        prompt: per "Phase Subagent Prompt Template" below
    await receipt

    parse receipt line 1:
        must match "Phase <N> done." or treat as failure
        if missing, malformed, or begins "Phase <N> HALTED:":
            retry up to 2x (fresh dispatch)
            on third failure: HALT, surface to user.

    run Per-Phase Reconciliation (see below)
    if reconciliation fails:
        retry dispatch up to 2x (mid-flight pickup resumes from first gap)
        on third failure: HALT, surface gap list to user.

    flip phase header: "in-flight:<id>" -> "done"
    session_phase_count += 1

# all phases done; proceed to final gate + final verification (unchanged).
```

### Model selection for phase subagent dispatch (VERBATIM, no drift)

The phase subagent dispatch's `model` parameter is copied EXACTLY from the phase header's `coordinator: <model>` annotation. Same rule as task-implementer and reviewer model dispatch: preflight decided the coordinator model; main does not upgrade or downgrade.

If main believes the coordinator model is wrong for this phase, HALT. Tell the user: "Phase <N> checklist says coordinator: <X>, but the phase appears to need <Y> because <reason>. Edit the checklist and re-run?" Do NOT silently drift.

### Phase Subagent Prompt Template

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

  Write your receipt as the last thing you report back. Receipt format
  (exact, 4 lines):

    Phase <N> done.
    Commits: <first-sha>..<last-sha> (<count>)
    Deferred: <0 | N - see <plan>-deferred.md §A-§Z>
    HALTs hit: <none | list>
```

The phase subagent's Skill tool invocation re-enters /fly, which on re-entry detects the `--phase=N` argument and runs the phase-scoped loop (no octopus main loop nesting - `--phase=N` bypasses the octopus main loop).

### Per-Phase Reconciliation (main-side integrity gate)

Reconciliation is the integrity gate that makes octopus trustworthy. The receipt is a breadcrumb; the real evidence is the checklist state and review artifact files on disk. Main never reads review files for content - reconciliation is pure grep/stat.

After each phase subagent returns a clean `Phase <N> done.` receipt line, main slices the checklist from `## Phase N:` to the next `## Phase` header (or to the Final Gate / Fly Verification block) and runs these checks against that slice:

1. Grep for `- [ ]` in the slice. Expected: none.
2. Grep for `` `<fill>` `` in the slice. Expected: none.
3. Grep for `findings=` lines missing a `review:` token. Expected: none.
4. For each `review: <path>` token in the slice:
   - File exists at `<path>`.
   - File is non-trivial (>500 bytes OR contains at least one `### Finding` header OR an explicit `No issues.` line).
   - `stat` mtime is AFTER the timestamp of the commit SHA referenced in the same task/phase-gate entry.
   - `findings-count` in the file's YAML header equals `grep -c "^### Finding " <path>`.
5. Phase Gate Outcome starts with `tests_pass=N tests_fail=N regressions=0;` prefix (Phase regression check ran).
6. Deep-review invariant: if this phase has a `/deep-review` gate, its Phase Gate Outcome's `review:` path points to a `.normalized.md` file (per the /deep-review normalization pass rule).

**Outcome:**

- All clean → flip header `in-flight:<id>` → `done`. Move to next phase.
- Gap detected → re-dispatch SAME phase subagent (fresh subagent, but fly's existing mid-flight pickup logic resumes from first gap). Bounded retry: 2 re-dispatches max. Third failure → HALT, surface gap list to user.

### Session-Window Heuristic

Main tracks `session_phase_count` - the number of phases this main session has flipped to `Octopus: done`. Constant: `phase_session_cap = 10`.

After reaching `phase_session_cap`, halt cleanly with:

```
Session window done: processed <K> phases this session.
Remaining phases: <list of phase IDs with Octopus: pending or in-flight>.
Start a fresh Claude Code session and re-run:
  /fly <checklist-path>
```

Do NOT dispatch more phases this session. Between sessions is a hard human-in-the-loop boundary; no auto-continuation across Claude Code sessions. The authoritative resume state lives in the checklist's `Octopus:` headers, so the next session picks up at the first phase not marked `done`.

### Receipt Format

Both emit (phase-scoped fly) and parse (main). Exact format, four lines:

```
Phase <N> done.
Commits: <first-sha>..<last-sha> (<count>)
Deferred: <0 | N - see <plan>-deferred.md §A-§Z>
HALTs hit: <none | list>
```

- Line 1: literal `Phase <N> done.` If the phase halted without completing, emit instead `Phase <N> HALTED: <reason>` and main treats the receipt as a failure.
- Line 2: first and last commit SHAs of the phase (from the phase's task commits). Count is total commits in the phase.
- Line 3: deferred-count summary. `0` if no deferrals. Otherwise `N - see <plan>-deferred.md §A-§Z` where A-Z is the range of deferred entries this phase appended.
- Line 4: HALT heuristics tripped during the phase. `none` is the expected case. Anything else is a human-interest signal, not an auto-action trigger for main.

Main greps receipt line 1 for `Phase <N> done.` prefix to determine success vs failure. Success path proceeds to reconciliation (reconciliation is the actual gate).

Phase-scoped fly emits the receipt as its final text response, after the phase gate Outcome is filled and before returning control to main.

### Handoff File (advisory)

When preflight detects multi-session tier, it writes `<plan-dir>/<plan-basename>-handoff.md` as advisory session-by-session guidance. Fly does not write or update this file - its authoritative state is the checklist's `Octopus:` headers. Fly resumes from the first non-done phase regardless of how the user chunked sessions.

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

As the implementer reports completed steps, edit the checklist file to tick the corresponding checkboxes:
- Change `- [ ] Step 1: ...` to `- [x] Step 1: ...`

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

**Before filling the Outcome slot with findings=0: run the Null-Result Meta-Check.** If the admissible findings count is 0, you MUST dispatch the meta-verifier per "Null-Result Meta-Check" section below before writing `findings=0` to the Outcome slot. Only a CONFIRMED meta-check allows the null Outcome; SUSPICIOUS forces re-dispatch of the real reviewer. See that section for the exact flow.

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

- **3 consecutive `findings=0` Outcomes**: Legitimate "no issues" reviews are rare. Three in a row is a red flag for fabricated reviews. Halt and surface: "3 reviews in a row found nothing. Please verify the last 3 review files exist and look reasonable: `<paths>`. Continue? (y/n)"
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

In addition, the reviewer prompt MUST contain these two sections, clearly labeled so the reviewer understands the trust boundary:

- `## Implementer-Reported Summary (untrusted)` - the implementer's report text.
- `## Actual Diff` - raw output of `git show <sha>` for single-task reviews, or `git diff <base>..<head>` for batched/phase/final reviews.

## Review Artifact Files

Every review MUST produce a durable on-disk artifact. This is the SHA-equivalent for reviews: the orchestrator cannot claim `findings=0` without a file on disk saying so, and the user can audit the file after the fact.

### Path convention

    <plan-dir>/reviews/<task-or-scope>-<review-type>.md

Examples:
- `docs/specs/m3/reviews/task-7.4-spec.md`
- `docs/specs/m3/reviews/task-7.4-code.md`
- `docs/specs/m3/reviews/batch-10.2-10.3-combined.md`
- `docs/specs/m3/reviews/phase-7-gate.md`
- `docs/specs/m3/reviews/phase-11-deep-review.md`
- `docs/specs/m3/reviews/final-deep-review.md`

`<plan-dir>` is the directory containing the plan and checklist files. Create the `reviews/` subdirectory on first write.

### Orchestrator assigns the path before dispatch

In each reviewer dispatch, the orchestrator substitutes the `<review-file-path>` placeholder with a concrete absolute path. The reviewer writes to that path.

### Post-dispatch verification

After the reviewer returns:

1. Check the file exists at the assigned path. If missing → the review did not actually run (or the reviewer disobeyed). Re-dispatch with a sterner prompt; if it fails again, halt and surface to the user.
2. Read the file and use its findings list as the SOURCE OF TRUTH. Not the summary in the reviewer's text response.
3. Confirm the file's YAML header's `findings-count` matches the number of `### Finding N:` sections inside.

### For deep-reviews: normalization pass

`/deep-review` runs multiple parallel sub-reviewers (Codex review, Chrome MCP UI review, rule compliance, simplification, collateral change audit, Claude's own diff analysis). Each sub-reviewer has its own findings. The `/deep-review` skill consolidates them, and in that consolidation, findings are routinely dropped or merged - the well-known body-vs-summary gap.

For deep-review files ONLY, run an extra normalization pass:

1. Dispatch a small subagent (model: haiku) with the deep-review file contents. Prompt:

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

2. Use the normalized file as the source of truth for step F processing, not the original deep-review file.
3. If the normalized count > original deep-review's claimed count, that's expected and fine (the skill was under-reporting). Log the delta in the Outcome (`(normalized: +N)` token).

This normalization pass does NOT run for per-task reviews. A single reviewer's single file is already flat.

## Outcome Slot Format

When filling an `Outcome: \`<fill>\`` slot, use this structured single-line format:

```
findings=N fixed=N deferred=N (review: <path>); <one-sentence summary>
```

Tokens:
- `findings=N` - total admissible findings (numbered, prioritized, disposition-tagged, cited).
- `fixed=N` - how many findings were fixed by the fix-implementer loop. Includes findings of any priority; disposition is `[fix]`.
- `deferred=N` - how many findings were written to `-deferred.md`. Only findings where disposition is legitimately `[defer]` (user decision / phase-sized / extremely risky), plus any `[fix]` findings that genuinely BLOCKED even after model upgrade.
- `review: <path>` - MANDATORY reference to the review artifact file (e.g. `review: reviews/task-7.4-code.md`). This is the SHA-equivalent: no artifact = no review happened. For deep-reviews, use the normalized file path: `review: reviews/phase-11-deep-review.normalized.md`.
- `<summary>` - one sentence describing the outcome.
- Optional priority breakdown for readability: `(crit=N maj=N min=N cos=N)`.
- Optional: `inadmissible=N` for findings discarded for missing number/priority/disposition/citation.
- Optional: `(normalized: +N)` for deep-review outcomes where the normalization pass surfaced more findings than the consolidated list.

**Invariants:**
- `findings == fixed + deferred`. If they don't match, the orchestrator lost a finding - halt.
- `review:` path points to a file that exists, has the matching YAML header, and has exactly `findings` `### Finding N:` sections.

Examples:
- `findings=0 fixed=0 deferred=0 (review: reviews/task-7.4-code.md); No issues.`
- `findings=10 fixed=10 deferred=0 (review: reviews/task-11.1-code.md, crit=1 maj=3 min=4 cos=2); All inline.`
- `findings=12 fixed=11 deferred=1 (review: reviews/phase-12-deep-review.normalized.md, normalized: +4); 11 inline; §5 deferred (user UX decision).`
- `findings=5 fixed=0 deferred=0 inadmissible=5 (review: reviews/task-9.2-code.md); All findings missing disposition; reviewer re-dispatched.`

Prose-only Outcomes (no `findings=` token OR no `review:` token) fail Final Verification.

## Null-Result Meta-Check (findings=0 verifier)

Every `findings=0` outcome MUST pass a meta-check before the Outcome slot gets filled. This closes the specific fabrication vector where an orchestrator under pressure writes a rubber-stamp review file (`findings-count: 0`, body literal `No issues.`) without ever dispatching the real reviewer. The existing review-artifact mandate, YAML header, and mtime checks all pass for a fabricated file because the same orchestrator wrote them.

### When this fires

After every reviewer dispatch (step E spec review, step G code review, step I batched review, phase gate normal review, phase gate deep-review post-normalization, final gate), if the admissible findings count is 0, run the meta-check BEFORE filling the Outcome slot.

- If findings > 0: no meta-check needed. The fix loop itself is evidence the review engaged (fabricated findings would fail the fix-implementer cycle).
- If findings = 0: dispatch the meta-verifier described below. Proceed only on CONFIRMED.

Applies in every mode: single-orchestrator fly, phase-scoped fly (`--phase=N`). Main octopus loop does NOT run the meta-check itself because main never fills task-level Outcomes in octopus mode; the phase subagent does, and the phase subagent runs phase-scoped fly which inherits this requirement.

### Meta-verifier dispatch

- `subagent_type`: `general-purpose`
- `model`: `haiku` (narrow verification task; upgrade to sonnet only on retry)
- `description`: `Verify null review for <task-or-scope>`
- `prompt`: see "Meta-verifier prompt" below

Substitutions:
- `<review-file-contents>`: the full text of the review file the reviewer wrote.
- `<diff>`: output of `git show <sha>` for a single-commit review, or `git diff <base>..<head>` for phase/final scope.
- `<diff-line-count>`, `<diff-file-count>`: compute from the diff.

### Meta-verifier prompt

```
You are a meta-verifier for a claimed null review.

Another reviewer submitted a review file claiming findings=0 (no issues).
Your job: determine whether that reviewer actually engaged with the diff, or
whether the review is boilerplate/fabricated.

## Review file under verification

<review-file-contents>

## Actual diff under review (size: <diff-line-count> lines, <diff-file-count> files)

<diff>

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

### Handling the response

- **CONFIRMED**: fill the Outcome slot as normal. Proceed to next step.
- **SUSPICIOUS**: treat as if the original review never happened.
  1. Re-dispatch the REAL reviewer (not the meta-verifier) with a stricter prompt. Append this text to the original reviewer prompt template: `THIS IS YOUR SECOND ATTEMPT. A meta-check flagged the prior null-result review as suspicious: <reason from meta-verifier>. Read every hunk in the diff and either emit findings or emit an explicit engagement trail listing the files and functions you verified.`
  2. If the second review also returns findings=0, re-run the meta-check on the new file.
  3. If meta-check returns CONFIRMED on the second attempt, proceed normally.
  4. If meta-check returns SUSPICIOUS on the second attempt, HALT. Surface to user with: paths of both review files, both meta-verifier reasons, and the diff. Do NOT fill the Outcome slot. Let the user resolve (manual review, upgrade reviewer model, etc.).

### Cost and scope

One haiku dispatch per findings=0 outcome. A phase with 5 clean task reviews + 1 clean phase gate = 6 haiku calls. Negligible against a single fabricated review slipping through.

### Does NOT replace existing HALT heuristics

The "3 consecutive `findings=0` Outcomes" HALT still fires even after meta-check CONFIRMED the individual reviews. Meta-check catches per-outcome fabrication; the consecutive-nulls HALT catches a pattern that warrants human spot-check regardless.

## Phase Gates

After all tasks in a phase complete (all per-task slots filled):

### Phase regression check (MANDATORY, runs before the review gate)

Per-task TDD catches regressions inside each task's scope. The phase regression check catches regressions the task-level tests didn't cover (unrelated tests newly broken, integration failures, etc.). This also defangs the "it was a pre-existing failure" gaslighting pattern: pre-existing = proven by running the test at the base commit, not asserted.

1. Detect the project's test command once per `/fly` run (cache the answer):
   - `package.json` `scripts.test` → use it.
   - `pyproject.toml` / `pytest.ini` → `pytest`.
   - `Cargo.toml` → `cargo test`.
   - `go.mod` → `go test ./...`.
   - Otherwise, ask the user once: "What's the test command for this project? (cached for the rest of this /fly run)"
2. Run the test command at HEAD. Capture `pass=N fail=N` and the list of failing test names.
3. Run the same command at `<phase-first-commit>^` (the phase's parent). Use a detached worktree or `git stash` + `git checkout` + `git stash pop` to avoid disturbing HEAD. Capture `pass_base=N fail_base=N` and the base failing-test list.
4. Compute `regressions = HEAD failing tests − base failing tests`. These are new failures introduced during the phase.
5. If `regressions` is non-empty: HALT the phase gate. Dispatch fix-implementer with the regression list. Loop until `regressions` is empty. If fix-implementer BLOCKs at upgraded model, write to deferred and halt `/fly` - do NOT silently ignore regressions.
6. Prefix the Phase Gate Outcome with `tests_pass=N tests_fail=N regressions=0;` once the subsequent review gate fills it.

### Phase review gate

After the regression check passes, run the review gate per the checklist's annotation:

- **Normal review** (`Phase N Gate (reviewer: <model>)` with `Normal code-review on Phase N diff`):
  1. Compute the phase diff: `git diff <phase-N-first-commit-sha>^..<phase-N-last-commit-sha>`.
  2. Dispatch code reviewer via `code-quality-reviewer-prompt.md` template, with the phase diff as the subject.
  3. **If admissible findings = 0, run the Null-Result Meta-Check** (see section above) BEFORE filling the Outcome slot. Only CONFIRMED allows a null Outcome.
  4. Fill Outcome slot with summary.
  5. If findings: same auto-fix loop as per-task reviews. Fill Resolution.

- **Deep-review** (`Phase N Gate (reviewer: ...)` with `/deep-review on Phase N diff`):

  `/fly` MUST actually invoke the `/deep-review` skill via the Skill tool. Paraphrasing the skill's 6-review structure into a bespoke reviewer prompt is NOT equivalent - it loses what the skill has been tuned to do (parallel Codex review, Chrome MCP UI review, rule compliance audit, simplification pass, collateral change audit, Claude's own diff analysis), and it destroys the audit trail (the user can't tell whether the real skill ran).

  **Dispatch pattern: subagent → Skill tool**

  To keep the main `/fly` context clean, dispatch a subagent whose single job is to invoke the skill. Subagents dispatched via Task have access to the Task tool themselves, so `/deep-review`'s parallel sub-dispatches work from within the subagent.

  1. Dispatch via Task tool:
     - `subagent_type`: `general-purpose`
     - `model`: the phase gate reviewer model from the checklist (verbatim, no upgrade)
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

  2. When the subagent returns, process its numbered findings list EXACTLY as in step F (classify, auto-fix critical/correctness, deferred-write everything else, reconciliation invariant). Do NOT accept a prose summary in place of enumerated findings - if the subagent returned prose, re-dispatch asking for the enumerated form.
  3. **If normalized admissible findings = 0, run the Null-Result Meta-Check** on the normalized deep-review file BEFORE filling the Outcome slot. Only CONFIRMED allows a null Outcome.
  4. Fill the Phase Gate Outcome using the structured format, prefixed with the regression check metrics from above:

         tests_pass=N tests_fail=N regressions=0; findings=N fixed=N deferred=N; <summary>

  5. Note: `/deep-review` has its own auto-fix mechanism internally. If the subagent reports that certain findings were already auto-fixed inside `/deep-review`, count those in `fixed`. Findings the skill itself flagged as deferred go into `/fly`'s deferred.md (same file - don't create a separate one).

## Final Gate

Final Gate runs ONLY in main (single-orchestrator mode) or in the main octopus loop AFTER all phases are `Octopus: done`. Phase-scoped fly (`--phase=N`) NEVER runs the Final Gate - main owns it.

After all phases complete, check the checklist's final gate:

- If `## Final Gate: /deep-review over <scope>` exists:
  1. Dispatch a subagent to invoke `/deep-review` via the Skill tool, same pattern as the deep-review Phase Gate above (see "Dispatch pattern: subagent → Skill tool"). Scope per the checklist annotation.
  2. Process returned findings with the accounting invariant (`findings = fixed + deferred`). Default disposition is `[fix]`; only legitimately-defer findings go to deferred.md.
  3. **If normalized admissible findings = 0, run the Null-Result Meta-Check** on the normalized final-gate review file BEFORE filling the Outcome slot. Only CONFIRMED allows a null Outcome.
  4. Fill Outcome slot using the structured format: `findings=N fixed=N deferred=N; <summary>`.
  5. Fill Resolution slot per the outcome (Fixed / deferred references / mix).

- If `**Final gate not needed - all phases have deep-review coverage.**` exists: skip; nothing to do.

## Deferred File Handling

`<plan-basename>-deferred.md` holds findings that legitimately cannot be fixed inline. **Deferred is the exception, not the default.** Default is fix-inline; deferral requires justification.

A finding qualifies for deferral only if at least one of these applies:

1. **Needs user decision** - fix depends on product/UX semantics or architectural direction only the user can supply.
2. **Phase-sized effort** - fix alone would consume as much time as an entire plan phase (major refactor, schema migration, large architectural change).
3. **Extremely risky** - security-adjacent, data-integrity, unclear blast radius on unfamiliar code, hard-to-reverse.

Also: a `[fix]` finding that fix-implementer BLOCKED on after model upgrade can legitimately defer, IF evaluation shows it actually meets one of the three criteria. A failed fix attempt on a tractable problem is not a defer - halt and surface to the user instead.

"It's just a style nit" is NOT a defer criterion. If it's worth mentioning, it's worth fixing.

Each finding gets its OWN `§N` entry. Format:

```markdown
# Deferred Items: <feature>

> Items flagged during `/fly` execution that require your attention - user decision needed, too large for inline fix, or too risky to auto-apply.

## §1: <task/gate context> - [priority] <short title>

**Finding:** <description from reviewer, preserving file:line citation>

**Why deferred:** <one of: "needs user decision - <specifics>" | "phase-sized effort - <estimate>" | "extremely risky - <blast radius>" | "BLOCKED at upgraded model; fits defer criterion X because <reason>">

**Suggested fix:** <from reviewer's output>
```

When writing a deferred item:
1. Assign the next available `§N`.
2. Include priority in the heading.
3. Update the Resolution slot in the checklist: `Action: Deferred to <plan-basename>-deferred.md §N`.

If the deferred file doesn't exist yet, create it with the header before appending `§1`.

**Watch your defer rate.** If you find yourself writing more than 1-2 defer entries per review, pause: either the reviewer is mis-disposing findings (re-dispatch to re-evaluate), or the task genuinely needs the user's attention (halt `/fly` and surface to the user instead of accumulating defers silently).

## Final Verification

Final Verification runs ONLY in main (single-orchestrator mode) or in the main octopus loop AFTER all phases are `Octopus: done` and the Final Gate is processed. Phase-scoped fly (`--phase=N`) NEVER runs the Final Verification sweep - main owns it.

After all tasks, phase gates, and final gate are processed, run the verification block at the bottom of the checklist. Tick each item by actually verifying:

- **All plan-step and [INJECTED] checkboxes ticked:** grep the checklist for `- \[ \]` occurrences before the verification block. Should find none. If any found, halt: "Task <X> step <N> not ticked - did the implementer actually complete it?"

- **All SHA slots filled:** grep for `SHA: \`<fill>\``. Should find none.

- **All Outcome slots filled (non-`<fill>`):** grep for `Outcome: \`<fill>\``. Should find none.

- **Outcome slots use structured format:** grep for `Outcome: \`` lines that do NOT contain `findings=`. Should find none. Prose-only Outcomes without the `findings=N fixed=N deferred=N` prefix fail verification.

- **Outcome slots reference a review artifact:** every Outcome must contain a `review: <path>` token. Grep for `findings=` lines missing `review:`. Should find none.

- **Review artifact files exist:** for every `review: <path>` token, check that `<path>` resolves to an existing file that is non-trivial (>500 bytes or contains at least one `### Finding` header or an explicit `No issues.` line).

- **Review file mtime after task commit:** for per-task reviews, `stat <review-file>` mtime must be AFTER the commit SHA's timestamp. If earlier, the file predates the code and cannot be a review of it.

- **Findings count matches review file:** for every Outcome, `grep -c "^### Finding " <review-path>` must equal the Outcome's `findings=N` value. Mismatch = silent finding loss.

- **Findings accounting invariant:** `findings == fixed + deferred`. Halt on mismatch.

- **Fabrication-pattern scan:** count `findings=0` Outcomes across the checklist. If the ratio exceeds 50% of all reviews, warn the user: "High rate of 'no issues' reviews - please spot-check review files."

- **Phase Gate Outcomes contain regression-check prefix:** each phase's Outcome must start with `tests_pass=N tests_fail=N regressions=0;`. Any phase missing this prefix means the Phase regression check was skipped - halt and fail.

- **All Resolution slots filled (non-empty, not "ignored"/"skipped"):** grep for `Action: \`<fill>\`` or `Action: \`ignored\`` or `Action: \`skipped\``. Should find none.

- **Deep-review invariant satisfied:** confirm that every task's commit SHA is in the scope of at least one deep-review Outcome that's non-`<fill>` (i.e., actually ran). If a task's commits aren't covered by any deep-review scope, halt: "Task <X> not covered by a deep-review - invariant violated."

- **If `<plan-basename>-deferred.md` exists, surface contents to user:** read the file and include its full contents in the final report. Explicitly tell the user "deferred items need manual review before shipping."

- **(Octopus mode only) All phases marked `Octopus: done`:** the checklist's Fly Verification block in octopus mode has an additional line:

      - [ ] All phases marked `Octopus: done`

  Tick this box only after grepping the checklist and confirming no `Octopus: pending` or `Octopus: in-flight:` remains. Any surviving non-`done` status means a phase didn't complete - halt and report which phases are still pending/in-flight. Single-orchestrator checklists do not contain this line; skip the check.

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
| "The implementer's summary says it's good, reviewer can skim" | The summary is UNTRUSTED. Reviewer must read the `## Actual Diff` independently. Dispatching a reviewer with only the summary is reviewer priming. |
| "I'll just write 'Looks good' in the Outcome slot" | Outcome needs `findings=N fixed=N deferred=N`. Prose-only fails Final Verification. If you didn't count, you didn't review. |
| "Reviewer returned findings without file:line, I'll act on them anyway" | Inadmissible. Fabricated findings without citations waste fix cycles. Discard, log `inadmissible=N`, move on. |
| "Auto-fixing this style nit won't hurt" | Only `[critical]` / `[correctness]` auto-fix. Style/cosmetic amplifies fabricated-finding waste. Log and move on. |
| "That test was probably failing on main anyway" | Phase regression check: run the suite at the phase base commit. Assertion without running is gaslighting. |
| "This task looks harder than sonnet, let me use opus to be safe" | NO. The checklist is the contract. If you think the model is wrong, HALT and ask the user to edit the checklist. Silent upgrades destroy the audit trail - the checklist says sonnet, the dispatch log says opus, reality becomes un-reproducible. |
| "Opus is better, it won't hurt to upgrade" | Cost and audit: opus costs more, and "we used sonnet" becomes a lie when checklist-vs-dispatch drift. Preflight picked sonnet for a reason. Respect the decision or surface the disagreement to the user. |
| "I'll use opus for the reviewer because this code is tricky" | Same rule. Reviewer model is in the checklist. Upgrading silently also primes the review outcome (opus reviews differ from sonnet reviews) and defeats preflight's per-gate assignment. |
| "Defaulting to opus is fine for everything" | It is NOT fine. Preflight assigned per-task models to balance cost, latency, and appropriate rigor. A fly run that always uses opus has ignored the checklist. |
| "Reviewer returned 20 findings, let me consolidate the main ones" | NO. Every admissible finding gets processed by number. Consolidation into prose loses detail. Fix it or defer it (with a valid defer reason). |
| "This cosmetic finding can wait for a hygiene pass" | NO. Default disposition is [fix]. Cosmetic nits compound into quality drift, and later tasks copy the smell. Fix it now. Cheaper overall than whack-a-mole later. |
| "Let me defer this 5-minute extract-helper refactor" | Extract-helper refactors are part of healthy implementation, not a separate track. Only defer if fix is phase-sized, needs user decision, or is extremely risky. |
| "Let me paraphrase /deep-review's structure into a subagent prompt instead of invoking the skill" | NO. Paraphrasing destroys the skill's tuned behavior (parallel Codex review, Chrome MCP UI review, etc.) and destroys the audit trail. Dispatch a subagent that invokes the skill via Skill tool. |
| "The reviewer tagged this [minor] so I won't bother" | Priority doesn't gate fix; disposition does. If it's [fix], fix it regardless of priority. |
| "findings = 10, fixed = 2, deferred = 0, let me note '8 style findings' in the summary" | INVARIANT VIOLATION: findings = fixed + deferred. 8 findings disappeared. Halt. |
| "The reviewer tagged this [defer] so I'll defer it" | Check the "Why defer" reason. If it doesn't cite one of the 3 criteria (user decision / phase-sized / extremely risky), reject and re-dispatch - the reviewer misdisposed. |
| "Most of these should defer because they're out of scope" | If the reviewer is producing a high defer rate, the reviewer is wrong or the task scope is wrong. Re-dispatch or halt. Silent acceptance of mass-defer defeats the fix-inline principle. |
| "Phase subagent's receipt says done, skip reconciliation" | Reconciliation is the integrity gate. Receipt is a breadcrumb, not evidence. Grep the slice. |
| "Phase subagent returned but slot X is still `<fill>`, close enough" | That's a reconciliation failure. Re-dispatch. No drift. |
| "Main is busy; reuse prior phase's receipt" | No. Each phase has its own dispatch, receipt, reconciliation. |
| "findings=0, skip meta-check, just write 'No issues.' to the review file and the Outcome" | NO. findings=0 MANDATES the Null-Result Meta-Check. Writing a rubber-stamp review file without dispatching a real reviewer is the exact fabrication vector the meta-check exists to catch. Dispatch haiku meta-verifier. |
| "I read the diff myself, it's clearly fine, no need for a real reviewer" | Your read is not a reviewer dispatch. The review artifact file must exist and must be produced by a dispatched reviewer subagent. Orchestrator inspection is not a substitute. |
| "Meta-verifier said SUSPICIOUS but I'm sure the review was fine" | SUSPICIOUS triggers re-dispatch of the REAL reviewer. Override attempts destroy the contract. Re-dispatch, or HALT and surface to user. |

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
- "Phase subagent said done, reconciliation is just a formality" (reconciliation is the gate; grep the slice)
- "Just flip this phase to Octopus: done without running reconciliation first"
- "Session cap is a soft limit, one more phase won't hurt"
- "This phase's coordinator model looks weak, let me upgrade it" (same rule as task/reviewer models - HALT and ask, don't drift)
- "findings=0, I'll just write the review file myself and skip the meta-check"
- "Writing 'No issues.' to the file is basically the same as dispatching a reviewer"
- "Meta-verifier is SUSPICIOUS but I trust the original review, overriding"

**All of these mean: you are about to violate the checklist contract. Do the work.**

## The Iron Rule

**The checklist is the contract. Every checkbox must be ticked by verifying its condition. Every slot must be filled with actual content. No exceptions, no rationalizations.**

If `/fly` completes without every box ticked and every slot filled, the final verification will catch the gap and halt. Do not try to work around the verification - fix the missing work. The verification exists because commitment contracts only hold when they're enforced.

If you genuinely believe a step is wrong or impossible, surface the issue explicitly to the user. Do not silently skip.
