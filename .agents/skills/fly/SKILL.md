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
2. Running spec and code reviewers; fixing findings inline or via fix-implementer dispatch (orchestrator's call per finding).
3. Filling SHA, Outcome, and Resolution slots in the checklist as work progresses.
4. Running per-phase regression checks and a single session-end deep-review gate per the checklist.
5. Final verification sweep: all boxes ticked, all slots filled, deep-review invariant satisfied.

`/fly` does NOT invoke `superpowers:subagent-driven-development` as a skill. It owns its per-task loop and uses that skill's prompt templates by reading them at runtime.

## Fire-and-forget

The user runs `/fly` and walks away for hours. Don't pause to ask, offer options, or wait for decisions. When something fails: try, escalate, then defer with FIXME and continue. The deferred-resolution task at session end is the user's inbox.

**Halt only on:** integrity gate failure you can't fix yourself, or phase regression that persists after fix-implementer retries. When halting, print: `HALT: <reason>. Run /compact then re-invoke /fly <checklist>. Mid-flight pickup resumes from this task.`

## Helper Scripts

Five bash scripts live adjacent to this SKILL.md. Use the "Base directory for this skill" path injected by the runtime to locate them:

```
<base-dir>/dispatch-reviewer.sh - MANDATORY reviewer-dispatch contract resolver (run BEFORE every reviewer Task call)
<base-dir>/integrity-check.sh   - per-task reviewer-dispatch + model verification
<base-dir>/final-verify.sh      - end-of-run checklist sweep
<base-dir>/phase-regression.sh  - phase gate regression check
<base-dir>/tick-steps.sh        - bulk-tick plan-step checkboxes
<base-dir>/reviewer-override.md - Reviewer Independence Override block (Read once, cache, append to every reviewer dispatch)
```

**On first use in a session**, resolve `SCRIPT_DIR` once and cache it:

1. If the runtime injected "Base directory for this skill: <path>", use that path as `SCRIPT_DIR`.
2. Otherwise: `SCRIPT_DIR=$(dirname "$(find ~/.claude -name "integrity-check.sh" -path "*/fly/*" 2>/dev/null | head -1)")`
3. If still empty, HALT: "Fly helper scripts not found. Check skill installation."

All script invocations below use `$SCRIPT_DIR/<script-name>`. Do NOT use Glob or ad-hoc path guessing.

## Bundled References

Read these only when you reach the matching step:

- `references/review-artifacts.md` - path conventions, post-dispatch verification, deep-review normalization pass
- `references/outcome-format.md` - structured Outcome slot format, tokens, examples
- `references/integrity-gate.md` - rationale + agent-agnostic caveat for the per-task integrity check
- `references/final-verify-output.md` - how to react to PASS / HALT / WARN / DEFERRED output

## Triggers

User invokes `/fly <checklist-path>` - typically in a fresh Claude Code session for clean context.

## Input

- **Primary:** path to a preflight checklist file (produced by `/preflight`).
- **Secondary:** the per-session plan file referenced in the checklist's `READ FIRST` header (e.g., `plan-1.md`).
- Fly reads both files on entry: checklist for tracking (what to tick/fill), plan file for task content (what to implement).

## State Detection

On entry, read the checklist file and the plan file referenced in its `READ FIRST` header. Then classify state:

- **Fresh run** - all checkboxes unticked (`- [ ]`) and all slots contain `<fill>`.
- **Mid-flight pickup** - some checkboxes ticked or some slots non-`<fill>`. Resume from the first unticked checkbox or unfilled slot.
- **Already complete** - every checkbox ticked, every slot filled, verification block ticked. Print "Already complete. Nothing to do." and exit.

Announce mode at start: "Flying <checklist>. Mode: fresh run." / "Mode: resuming from Task <X.Y>." / "Already complete."

## Multi-File Checklist Support

`/fly` executes exactly ONE checklist file per invocation. Each checklist has a companion per-session plan file (e.g., `plan-1.md`); the checklist tracks progress, the plan file holds task content. Together they form a complete session: own tasks, own phase regression checks, own session deep-review gate.

For split plans (`<plan>-checklist-1.md`, `-checklist-2.md`, ...), the user runs `/fly <checklist-N>` once per file in order, each in a fresh session. Fly does not cross-reference sibling checklists or coordinate state between them. The checklist you were handed is the universe for this invocation.

## Template Resolution

Applies ONLY to per-task and phase-level dispatches of implementer, spec-reviewer, and code-quality-reviewer subagents. NOT to deep-review gate dispatches - those invoke `/deep-review` directly via the Skill tool in main context (see "Session Gate").

For in-scope dispatches, resolve each template at dispatch time:

1. Glob: `~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/<template>.md`
2. Glob returns paths sorted by mtime (newest first). Take the first match.
3. Read the file.

Templates `/fly` resolves this way:
- `implementer-prompt.md` - implementer subagents (step A)
- `spec-reviewer-prompt.md` - spec reviewer (step E)
- `code-quality-reviewer-prompt.md` - code reviewer (step E) and phase normal review

NOT resolved this way: `/deep-review` (Skill tool, no template); fix-implementer dispatches (reuse implementer template).

If Glob returns no match, halt: "Upstream templates not found at <pattern>. Check plugin install or update the Glob pattern."

## Per-Task Loop

Walk the checklist's tasks in order. For each task, FIRST check `Mode:`:

### Mode: inline (small tasks, no implementer subagent)

Tasks tagged `Mode: inline` skip IMPLEMENTER subagent dispatch. The orchestrator does the work directly using already-loaded context. Saves ~5-20k boot tokens per task. Reviewer dispatch is unchanged - inline tasks still get reviewed by a subagent, preserving independent-review fidelity (subtle bugs in 30 LOC are exactly where review earns its keep).

Inline flow:
1. Read the task's full text from the per-session plan file.
2. Honor `[INJECTED]` TDD steps if any: write failing test, watch it fail, then implement.
3. Apply changes via Edit/Write/Bash directly. Run tests. Commit with message `feat: <task title> (task <id>)`. Commit message MUST contain `task <id>` substring (final-verify.sh greps for it; no separate transcript).
4. Tick all plan-step checkboxes via `bash $SCRIPT_DIR/tick-steps.sh <checklist-path> <task-id> 1,2,...`.
5. Fill SHA slot.
6. Proceed to step E (dispatch reviewer) and onward EXACTLY as for subagent mode. The reviewer doesn't care that the orchestrator did the implement - it reviews the actual diff.
7. Fix-loop on review findings: orchestrator does all fixes directly (already has the code context). Tag commit `(orch-inline, task <id>)`.

If you can't commit cleanly (tests fail, conflict), HALT and surface to user.

### Mode: subagent (default)

Standard Task-dispatch flow per steps A-G below.

### A. Dispatch implementer

1. Resolve `implementer-prompt.md` via Glob + Read.
2. Substitute placeholders:
   - `[FULL TEXT of task from plan - paste it here, don't make subagent read file]` → the task's full text from the per-session plan file. Match the checklist's task ID (e.g., Task 0.1) to the corresponding `### Task 0.1:` section in the plan file.
   - `[Scene-setting: where this fits, dependencies, architectural context]` → short paragraph from checklist's overall goal and phase description.
   - `[directory]` → user's project root.
3. Append explicit override text:

   ```
   ## Checklist Overrides

   The following overrides take precedence over anything in the task text above:

   1. **TDD is mandatory.** Write a failing test first, watch it fail, then implement. If the task text doesn't mention TDD, do it anyway.

   2. **Extra steps from preflight audit** (execute these before the plan's own steps):
      <list of [INJECTED] step titles from the checklist for this task>
   ```

   If no injected steps, still include the section but say "None."

4. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: the EXACT model string from the checklist's `Model:` annotation. No drift in either direction. If the checklist says `Model: sonnet`, the Task call gets `model: "sonnet"` - not opus, not haiku, not a different opus variant. The checklist IS the contract.
   - `description`: `Implement <task id>: <task name>`
   - `prompt`: the substituted template

   Use the checklist's Model annotation verbatim. If you think it's wrong, log a note in deferred.md and continue - the user reviews at session end. Don't pause to ask.

   Same rule for REVIEWER model dispatch in step E and session-gate dispatches: the `model` parameter is copied verbatim from the checklist annotation.

   **Exception: fix-implementer dispatches** (step F and session-gate fix loops) are NOT governed by a checklist annotation. The fixer defaults to the task's implementer model but may upgrade on its own judgment when a finding is architecturally gnarly or when the default-model fix BLOCKED. Discretionary, not contract-gated.

5. Wait for the implementer's report.

### B. Handle implementer status

- **DONE** or **DONE_WITH_CONCERNS**: proceed. If DONE_WITH_CONCERNS, read the concerns - fix them before review if they're about correctness; note and proceed if they're observations.
- **NEEDS_CONTEXT**: provide best-effort context from already-read files and re-dispatch. If still NEEDS_CONTEXT after retry, defer with FIXME and continue. Don't pause to ask.
- **BLOCKED**: assess per subagent-driven-development's escalation guidance - more context, upgrade model, or break down task.

### C. Tick plan-step checkboxes

```
bash $SCRIPT_DIR/tick-steps.sh <checklist-path> <task-id> <comma-separated-step-numbers>
```

Output: `OK <N checkboxes ticked>` on success, `ERROR <reason>` on failure. On ERROR, halt and surface.

Rationale: N Edit calls per task bloat orchestrator context. The script handles all steps in one `sed` pass.

### D. Fill commit SHA slot

Read the implementer's report for the commit SHA. Edit the checklist to replace the task's `SHA: \`<fill>\`` with `SHA: \`<actual-sha>\``.

### E. Dispatch reviewer (combined by default)

For tasks annotated `Review: combined` (default): dispatch ONE reviewer covering both spec + code concerns.

**Step 0 (MANDATORY): resolve the dispatch contract before doing anything else.**

```
bash $SCRIPT_DIR/dispatch-reviewer.sh <checklist-path> <task-id> combined <task-sha>
```

The script parses the checklist for the task's `(reviewer: <model>)` annotation and emits canonical key=value lines:

```
MODEL=sonnet
REVIEW_PATH=/abs/path/to/reviews/task-<id>-combined.md
DIFF_CMD=git show <sha>
PROMPT_HEADER_NOTE=...
```

You **copy these values verbatim** into the Task call. The orchestrator never types the model string by hand. This is how reviewer-model drift sneaks in (e.g., silently downgrading sonnet to haiku to save cost). Any value the script emits is contract; if it's wrong, edit the checklist and re-run the script - do not modify the script's output before passing to Task.

If the script exits non-zero, HALT and surface - it means the checklist is missing a reviewer annotation that `/preflight` should have written.

1. Resolve `code-quality-reviewer-prompt.md` via Glob + Read.
2. Review file path: use `REVIEW_PATH` from the script.
3. Substitute placeholders:
   - `[FULL TEXT of task requirements]` → the task's text from the per-session plan file.
   - `[From implementer's report]` → the implementer's summary, under the heading `## Implementer-Reported Summary (untrusted)`.
4. Append a `## Actual Diff` section containing the output of `DIFF_CMD`.
5. Append the Reviewer Independence Override block verbatim (read once from `$SCRIPT_DIR/reviewer-override.md`, cache for the session). Substitute `<review-file-path>` with `REVIEW_PATH`.
6. Add a `## Review scope` section to the prompt with explicit dual focus:
   ```
   This is a COMBINED review covering both spec and code concerns. Emit findings under both lenses:
   ### Spec concerns: does the commit satisfy plan requirements? (missing steps, wrong behavior, scope drift)
   ### Code concerns: quality, correctness, conventions, duplication, edge cases.
   ```
7. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: **`MODEL` value from the script, verbatim**.
   - `description`: `Combined review <task id>`
   - `prompt`: the substituted + augmented template
8. Wait for report. Verify the review file exists (see `references/review-artifacts.md`). If missing, re-dispatch; if fails again, halt.
9. Read the review file. `### Finding N:` sections are source of truth.
10. Fill the `Combined review` Outcome slot using the structured format (see `references/outcome-format.md`).

**For `Review: separate` tasks** (high-risk: opus implementer / security / schema / broad blast-radius): use the legacy two-step pattern - dispatch spec-reviewer first (run `dispatch-reviewer.sh ... spec ...` to get its model + path), then code-reviewer (`dispatch-reviewer.sh ... code ...`), filling the `Spec review` and `Code review` Outcome slots separately. Same fix-loop semantics apply per review. Spec and code reviewers often have DIFFERENT models in the checklist - the script's per-call output is what guarantees you don't conflate them.

### F. Handle findings

Parse the reviewer's output. Every admissible finding has a unique number, a priority, a disposition, and a file:line citation. Classify by disposition:

- **Inadmissible** - missing number, priority, disposition, or citation. Count for `inadmissible=N` in the Outcome. Do NOT act on them.
- **`[fix]`** - auto-fix via fix-implementer (see below). Default disposition; most findings land here regardless of priority.
- **`[defer]`** - write to deferred.md. Only valid if the reviewer cited one of the three defer criteria (user decision / phase-sized / extremely risky). Reject otherwise: halt and re-dispatch the reviewer asking it to reconsider disposition.

**Accounting invariant:** `admissible_findings = fixed + deferred`. Every admissible finding lands in one bucket. No "skipped" / "ignored" / "wontfix".

**Fix loop (all `[fix]` findings, highest priority first):**

1. Order by priority (critical → major → minor → cosmetic). For each finding, choose a path - your judgment, but lean conservative:
   - **Inline (orchestrator does it).** Trivial verbatim fix from the reviewer that you can apply with one Edit and no test changes. Commit `fix: §<n> <title> (orch-inline, task <id>)`. Inline-mode tasks always go this path.
   - **Dispatch fix-implementer.** Everything else. Default model: task's implementer model; upgrade if BLOCKED or architecturally gnarly. **When in doubt, dispatch** - saving one dispatch isn't worth a silent regression.

2. Wait for fix report (if dispatched). Missing finding numbers or failed inline Edits = BLOCKED.

3. BLOCKED retries escalate: inline → fix-implementer dispatch; default-model dispatch → upgraded model. Still BLOCKED: defer with FIXME and continue.

4. Re-dispatch reviewer (Reviewer Independence Override, fresh diff). Re-reviewer overwrites the prior review. Reviewer dispatch stays strict regardless of how fixes were applied - the integrity gate validates the re-review the same way. Loop until no `[fix]` admissible findings remain.

Why inline is safe: the integrity gate guards reviewer authorship, not fix authorship, and the re-review runs on a real subagent so any orchestrator-inline fix that went wrong gets caught.

**Deferred-write (only `[defer]` findings + any `[fix]` that legitimately blocked):**

Each deferred finding gets its own `§N` entry with priority in the heading and the specific defer reason. If you find yourself writing many defer entries in a single review, that's a signal - either the reviewer is mis-disposing (re-dispatch), or the scope of this task genuinely needs the user's attention (halt, surface).

**Fill the Outcome slot from the FINAL review file** (after all fix loops complete). The Outcome's `findings=N` must match the current file on disk, not an earlier review round. Format: see `references/outcome-format.md`.

**Fill the Resolution slot:**

- No findings at all: `None needed`.
- All fixed, none deferred: `Fixed in <last-fix-commit-sha>`.
- Some deferred: `Fixed in <sha>; N deferred to -deferred.md §A-§Z` (or just the defer reference if nothing was fixed inline).

### G. Phase-deferred tasks

For tasks annotated `Review: phase`: skip step E (no per-task review). The task's diff gets covered by the Phase Normal Review at end of phase (see "Phase Normal Review" below).

## Reviewer Independence Override

Every reviewer dispatch (per-task combined or separate, phase normal review, session gate) MUST include the Reviewer Independence Override block, appended AFTER the upstream template's placeholder substitutions. The block lives at `$SCRIPT_DIR/reviewer-override.md`. Read once per session, cache. Substitute `<review-file-path>` with the absolute path the orchestrator assigns.

Reviewer prompt MUST also contain, clearly labeled:
- `## Implementer-Reported Summary (untrusted)` - implementer's report text.
- `## Actual Diff` - raw output of `git show <sha>` for single-task reviews, or `git diff <base>..<head>` for phase/session reviews.

## Per-Task Integrity Gate

After filling BOTH Outcome slots for a task, fly MUST invoke the integrity-check script:

```
bash $SCRIPT_DIR/integrity-check.sh <task-id> <plan-dir> <task-sha>
```

Output:
- `PASS` (exit 0) - integrity verified. Proceed to the next task.
- `HALT: <reason>` (exit 1) - STOP immediately. Do NOT try to patch the symptom (re-dispatching, re-writing, tweaking slots). Surface verbatim with the recovery hint: `HALT: <reason>. Run /compact then re-invoke /fly <checklist>. Mid-flight pickup resumes from this task.`

Why this gate exists, what the script checks, and the agent-agnostic caveat: see `references/integrity-gate.md`.

## Periodic SKILL.md Re-read

Every 10 completed tasks (before task 11, 21, ...), Read this SKILL.md to refresh discipline against late-session drift. One Read per 10 tasks; triggers at most twice per `/fly` run.

## Phase Regression Check

After all tasks in a phase complete (all per-task slots filled). Per-task TDD catches regressions inside each task's scope. Phase regression check catches regressions task-level tests didn't cover (unrelated tests newly broken, integration failures). Also defangs "it was a pre-existing failure" gaslighting: pre-existing = proven by running test at base commit, not asserted.

NO reviewer subagent at phase boundaries. Per-phase deep-reviews are gone; one session-end deep-review covers all that session's tasks at lower total cost.

1. Invoke the regression script:

   ```
   bash $SCRIPT_DIR/phase-regression.sh <phase-first-commit-sha>^ <phase-last-commit-sha>
   ```

   (The caret `^` on the base SHA expands to its parent in the script's git invocations.)

2. Parse the single-line output:

   ```
   tests_pass=N tests_fail=N regressions=K | <test1> | <test2> | ...
   ```

   - `regressions=0`: phase regression check passes. Fill the Phase Regression Check Outcome with `tests_pass=N tests_fail=N regressions=0`. Continue to the next phase.
   - `regressions>0`: dispatch a fix-implementer with the regression list, re-run the script, loop until regressions=0. If fix-implementer BLOCKs at upgraded model after 2 tries, halt with the compact-restart hint (continuing on a broken codebase makes every subsequent task fail).

### Phase Normal Review (conditional)

If the checklist's phase block contains a `### Phase <N> Normal Review` block (preflight emits this only when at least one task in the phase is annotated `Review: phase`):

1. Compute the cumulative diff for `Review: phase` tasks in this phase. Their commit SHAs are in their filled SHA slots; the phase normal review's scope is the union (`git diff <first-phase-task-sha>^..<last-phase-task-sha>` works if they're contiguous; otherwise pass each SHA range explicitly).
2. Dispatch code-reviewer via `code-quality-reviewer-prompt.md` template against that diff. Review file path: `<plan-dir>/reviews/phase-<N>-normal-review.md`.
3. Append the Reviewer Independence Override block; substitute review-file path.
4. Wait for report. Process findings via the same step F fix-loop semantics.
5. Fill the Phase Normal Review Outcome and Resolution.

If no Phase Normal Review block exists for this phase, skip - all tasks were reviewed individually.

### Phase end-state verification

After filling the Phase Regression Check Outcome + Resolution (and Phase Normal Review if present), check the phase's end-state verification section (written by preflight):

- **tests-only**: nothing to do per-phase. End-of-session synthetic deferred-resolution task composes an OPTIONAL "Try it yourself" walkthrough.
- **has-residual**: nothing to do per-phase. End-of-session synthetic deferred-resolution task collects `Residual manual test` lines and surfaces them as the REQUIRED "Try it yourself" walkthrough.

## Session Gate (end of every checklist)

After all phases complete + their regression checks pass, run the session-end deep-review. Always present, every checklist (single-session OR per-checklist-N.md):

Locate the `## Session Gate: /deep-review over <scope>` block. Scope is the cumulative diff for THIS session's tasks (`<session-base-sha>^..HEAD` per checklist annotation).

1. Invoke `/deep-review` directly via Skill tool from main fly context. Do NOT wrap in a Task-dispatched subagent - subagents cannot nest-dispatch Task, which `/deep-review` may need internally for its parallel sub-reviewers.
2. Process returned findings with accounting invariant (`findings = fixed + deferred`). Default disposition is `[fix]`; only legitimately-defer findings go to deferred.md. Do NOT accept prose summary in place of enumerated findings.
3. Fill Session Gate Outcome using structured format (see `references/outcome-format.md`).
4. Fill Session Gate Resolution slot per outcome.

`/deep-review` has its own internal auto-fix mechanism. If it reports findings already auto-fixed, count those in `fixed`. Findings flagged as deferred go into `/fly`'s deferred.md (same file).

**Independent reviewer caveat:** when `/deep-review`'s independent reviewer is Codex, `codex review --base <X>` takes a BRANCH name, not a SHA. The `/deep-review` skill owns the reviewer-specific dispatch details. Do NOT skip the independent reviewer - it's load-bearing.

## Deferred File Handling

**Prefer doing over deferring.** Default is fix-inline; the synthetic deferred-resolution task at end of run will process whatever does land in the deferred file anyway. The 3 valid defer criteria (needs user decision / phase-sized / extremely risky) are spec'd canonically in `reviewer-override.md` - reviewers see them there.

`<plan-basename>-deferred.md` format. Each finding gets its own `§N` entry:

```markdown
# Deferred Items: <feature>

## §1: <task/gate context> - [priority] <short title>

**Finding:** <reviewer description, preserving file:line citation>
**Why deferred:** <which of the 3 criteria + specifics>
**Suggested fix:** <from reviewer's output>
```

Update Resolution slot when writing: `Action: Deferred to <plan-basename>-deferred.md §N`. Create the file with the header before appending `§1` if it doesn't exist.

More than 1-2 defer entries per review = signal. If reviewer seems to be mis-disposing, re-dispatch once; otherwise log a `## Defer rate note` line in deferred.md and continue. Fire-and-forget: don't pause to ask.

## Final Verification

After all tasks, phase regression checks, and session gate are processed, run:

```
bash $SCRIPT_DIR/final-verify.sh <checklist-path>
```

How to react to PASS / HALT / WARN / DEFERRED output (including the spawn_task handoff for deferred-resolution items): see `references/final-verify-output.md`.

## Completion

After final verification passes:
1. Print final report: tasks completed, commits made, time taken. **Do NOT independently list deferred items here.** The synthetic deferred-resolution task is the SINGLE canonical surface for deferred items - it has already enforced the user-facing impact discipline (see global AGENTS.md / CLAUDE.md "Surfacing to the User"). Re-listing raw `§N` entries from deferred.md in the final report bypasses that discipline and leaks dev jargon to the user.
2. Surface the synthetic deferred-resolution task's return value verbatim if you haven't already (its structured "Need your input" / "Try it yourself" output). If it returned "No items need your input" + walkthrough, just surface that.
3. If you want to mention deferred items in the final report at all, only the COUNT is acceptable (e.g., "2 items still in plan-1-deferred.md - see surfaced blocks above"). Never list `§N` titles or descriptions; that's the synthetic task's job and it's already done.
4. **DO NOT mention `/ship` or prompt the user about shipping.** User decides when to ship; nudging adds noise.

## Discipline: shortcuts to NEVER take

`/fly` exists because LLM coordinators rationalize shortcuts under context pressure. The checklist is the contract; every slot traces to a tool call that produced it. If you can't point to the Task / Write / Edit / Bash call that filled a slot, the slot is unfilled.

If you catch yourself thinking any of these, STOP - you're about to violate the contract:

| If you're tempted to... | Reality |
|---|---|
| Skip `dispatch-reviewer.sh` and just type the model into the Task call ("haiku is faster", "sonnet for the small diff", "the checklist annotation is obvious") | Run the script. Always. The `MODEL` value goes in verbatim. integrity-check.sh reads `message.model` from the JSONL and HALTs if the dispatched model doesn't match the checklist. Skipping the script doesn't get you out of the verification - it just means the HALT lands later, after wasted reviewer work. |
| Skip a review ("trivial", "code looks fine", "I read the diff") | Review = dispatched subagent + on-disk file. No dispatch, no review. Per-task integrity gate catches this; do not try to override. |
| Dispatch haiku reviewer when checklist says sonnet ("the diff is small", "just test fixtures", "haiku is fine here") | DRIFT. Halt, edit the checklist explicitly, then re-dispatch. integrity-check.sh verifies the JSONL `message.model` against the checklist annotation post-hoc; you can't get away with it. |
| Use a different model than checklist says (upgrade "to be safe" or downgrade "looks easy") | Checklist IS the contract. Silent drift breaks the audit trail. Use it verbatim; if you think it's wrong, log a note in deferred.md and continue. |
| Pause to ask the user "should I plow on, stop here, or pivot?" - even with a polite "I'll keep going if no answer" | The user is gone for hours. /fly is fire-and-forget. Pick the default (plow on), log uncertainty in deferred.md, keep moving. The deferred-resolution task surfaces it at the end. |
| Skip TDD because the task text didn't mention it | Implementer dispatch always appends TDD override. Do TDD. |
| Stretch inline-fix path ("basically a rename, just a few extra lines", "I see what the reviewer means") | Inline-fix is for trivial verbatim slam-dunks. If you have to think, dispatch. |
| Consolidate / merge / paraphrase reviewer findings | Every numbered finding processed by number. `findings == fixed + deferred` invariant. Halt if violated. |
| Defer a finding without one of the 3 valid criteria | Reject the disposition and re-dispatch reviewer. Default = `[fix]`. |
| Write "Looks good" in an Outcome slot | Outcome needs `findings=N fixed=N deferred=N (review: <path>)`. Final verification rejects prose-only. |
| Act on findings missing number/priority/disposition/citation | Inadmissible. Discard, log `inadmissible=N`, move on. |
| Tick the final verification block without actually running checks | Run `final-verify.sh`. Tick only after PASS. |
| Skip the periodic SKILL.md re-read at task 10/20 | Structural reminder. One Read. Do it. |
| Override an integrity-gate or final-verify HALT because "the work is really fine" | HALT means evidence doesn't support the claim. Surface to user, don't override. |

**All shortcuts mean: you are about to violate the checklist contract. Do the work.**
