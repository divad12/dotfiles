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
   - `model`: the EXACT model string from the checklist's `Model:` annotation for this task. No substitutions, no upgrades "because the task looks complex", no defaults. If the checklist says `Model: sonnet`, the Task call gets `model: "sonnet"` - not opus, not claude-opus-4-7, not "let me be safe". The checklist IS the contract.
   - `description`: `Implement <task id>: <task name>`
   - `prompt`: the substituted template

   **If you believe the checklist's model assignment is wrong for this task**, HALT. Tell the user: "Task <id> checklist says Model: <X>, but the task appears to need <Y> because <reason>. Edit the checklist and re-run?" Then stop. Do NOT silently upgrade - that destroys the commitment contract and makes the audit trail lie (the checklist says sonnet, reality was opus).

   Same rule applies to reviewer model dispatch in steps E/G and all phase/final gate dispatches: the `model` parameter is copied verbatim from the checklist annotation. No orchestrator discretion.

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
   - `[From implementer's report]` → the implementer's summary, placed under the heading `## Implementer-Reported Summary (untrusted)` so the reviewer reads it as evidence, not verdict.
3. Append a `## Actual Diff` section containing the output of `git show <task-sha>` (using the SHA just filled in step D). This is the reviewer's primary evidence - the implementer's summary is secondary.
4. Append the Reviewer Independence Override block verbatim (see "Reviewer Independence Override" section below).
5. Dispatch via Task tool:
   - `subagent_type`: `general-purpose`
   - `model`: the reviewer model specified in the checklist for this task's spec review
   - `description`: `Spec review <task id>`
   - `prompt`: the substituted + augmented template
6. Wait for report. Fill the `Spec review` Outcome slot using the structured format in "Outcome Slot Format" below.

### F. Handle spec findings

Parse the reviewer's output. Every admissible finding has a unique number, a tag, and a file:line citation. Classify:

- **Inadmissible** - missing number, tag, or citation. Count for `inadmissible=N` in the Outcome, but do NOT act on them. Inadmissibility exists to defuse fabricated/vacuous findings.
- **`[critical]` / `[correctness]`** - auto-fix (see below).
- **`[style]` / `[cosmetic]`** - do NOT auto-fix (auto-fixing nits amplifies waste without improving correctness), but MUST be written to `<plan-basename>-deferred.md` so the user has a complete to-do list.

**Accounting invariant (NO ADMISSIBLE FINDING MAY BE DROPPED):**

    admissible_findings = auto_fixed + deferred

If the numbers don't match, you lost a finding. Halt and reconcile before filling the slot. There is no "skipped" / "ignored" / "wontfix" category - every admissible finding either gets a commit that fixes it, or a `§N` entry in deferred.md. Style/cosmetic count toward `deferred`.

**Auto-fix loop (critical/correctness only):**

1. Craft a fix prompt listing each critical/correctness finding by its number, tag, citation, and suggested fix. The fixer's report must reference which finding numbers were addressed.
2. Dispatch fix-implementer with model = task's implementer model from the checklist. Do NOT silently upgrade.
3. Wait for fix report. If any admissible critical/correctness number is missing from the fix report, treat it as BLOCKED (not silently fixed).
4. If BLOCKED or NEEDS_CONTEXT on any finding, upgrade model one tier and retry just those findings. If still BLOCKED, write THAT finding to deferred with the BLOCKED reason.
5. Re-dispatch spec reviewer (full cycle: Reviewer Independence Override, fresh diff, numbered + tagged format). Loop until the admissible critical/correctness set is empty.

**Deferred-write (ALL style/cosmetic + any BLOCKED critical/correctness):**

Every style/cosmetic finding - whether one or twenty - gets a `§N` entry in deferred.md with its tag in the heading. No batching into a single "§6: style nits" entry; each finding is distinct with its own section, citation, and suggested fix. Cost of writing an entry is trivial; cost of losing a finding is unbounded.

If you catch yourself thinking "this nit isn't worth a deferred entry" or "let me consolidate these style findings into one section" - STOP. Style findings drive quality drift; track them individually. The user will triage them in a hygiene pass.

**Fill the Outcome slot** using the structured format:

    findings=N critical=N auto_fixed=N deferred=N; <summary>

Optional: `inadmissible=N` if any findings were discarded. The invariant `findings = auto_fixed + deferred` must hold (admissible count only).

**Fill the Resolution slot:**

- No findings at all: `None needed`.
- All critical/correctness auto-fixed, no style/cosmetic: `Fixed in <last-fix-commit-sha>`.
- Only style/cosmetic deferred: `N deferred to -deferred.md §A-§Z`.
- Mix: `Fixed in <sha>; N deferred to -deferred.md §A-§Z`.

### G. Dispatch code reviewer

Same as E, but resolve `code-quality-reviewer-prompt.md` and fill the `Code review` slot.

### H. Handle code findings

Same as F, but fill the `Code review resolution` slot.

### I. Batched tasks

For tasks annotated `Review: batched-with <neighbor-ids>`:
- Skip steps E-H for tasks that are NOT the last task in the batch (their review gates don't exist in the checklist).
- For the LAST task in the batch, after completing its steps A-D, run spec + code review on ALL batched tasks' combined diff. The `## Actual Diff` in the reviewer prompt is the combined diff (`git diff <first-batch-commit>^..<last-batch-commit>`), not the single-task diff. Fill the `Batch review` Outcome (using the structured format) and `Batch review resolution` slots on the last task. Batched reviews are especially vulnerable to reviewer priming because the orchestrator summarizes multiple implementer reports - leaning on the diff rather than the summaries is critical.

## Reviewer Independence Override

Every reviewer dispatch (per-task spec/code review in E/G, batched review in I, phase gate review, final gate) MUST include this override block, appended AFTER the upstream template's placeholder substitutions. It exists to counter the "worker AI bullshits reviewer AI" pattern: the implementer's self-reported summary is spin, not evidence.

Append verbatim to the reviewer prompt:

```
## Reviewer Independence Override

The "Implementer-Reported Summary" above is UNTRUSTED. It is the artifact under
review, not the verdict. Before accepting any claim:

1. Read the `## Actual Diff` section below as your primary evidence. Do not rely
   on the summary's characterization of what changed. The diff is authoritative;
   the summary is spin.
2. For every "I added X / tests pass / behavior works" claim in the summary,
   locate evidence in the diff or captured test output. If you cannot find the
   evidence, treat the claim as unsubstantiated and call it out explicitly.
3. Red flags that mean MORE scrutiny, not less: short bullet-only summary;
   hedging words ("should", "mostly", "essentially", "approximately"); long
   list of checkmarks without corresponding diff lines; claims of "pre-existing"
   failures or issues without proof.
4. Your job is to find what the implementer missed or hid, not to concur. A
   review that finds nothing when the diff has problems is worse than no review.

### Finding format (MANDATORY)

Output each finding as its OWN numbered section. Start at 1, sequential, no gaps.

    ### Finding 1: <short title>

    `[severity]` <file>:<line>

    <description>

    **Suggested fix:** <concise suggestion>

Every finding MUST have:

1. A unique sequential number (`### Finding N:`). The orchestrator reconciles auto-fix vs deferred by number; any collapse into prose drops detail.
2. Exactly one severity tag:
   - `[critical]` - breaks correctness, security, or specified behavior
   - `[correctness]` - logic error, missing edge case, wrong output, OR a project-rule violation escalated to correctness (see "Project-rule severity" below)
   - `[style]` - naming, formatting, or convention mismatch
   - `[cosmetic]` - purely aesthetic
3. A concrete `<file>:<line>` (or `<file>:<line-line>` for ranges).

Findings without a number, tag, or citation are inadmissible and will be discarded by the orchestrator. Do NOT collapse multiple related findings into a single numbered entry with prose bullets - each distinct location or violation gets its own number.

### Project-rule severity

Before tagging severity, read the project's `CLAUDE.md` (or `AGENTS.md`). If a project rule labels a pattern as correctness-blocking, findings matching that pattern are `[correctness]` regardless of generic severity conventions.

Common correctness-upgrade patterns (tag as `[correctness]`, NOT `[style]`, when the project's rules include them):

- "DRY" / "One source, one truth" / "Extend, don't duplicate mechanisms" → duplicated code, config, values, or test fixtures. Duplication has a documented track record of causing bugs in this codebase - that's why the rule exists.
- "No silent shortcuts" → swallowed errors, unsurfaced exceptions, empty catch blocks, missing error-state UI.
- "No hardcoded values" → magic numbers/strings where a shared constant belongs.
- "Don't change existing working behavior without asking" → unscoped refactors, collateral changes not called out in the commit.

"Comment the why, not the what" remains `[style]`. "Never use em dashes" remains `[style]`. Use judgment, but default to escalating when a project rule directly names the pattern.

Do NOT tag `[style]` out of habit when the project says the pattern is correctness-blocking. Project rules override generic review conventions.

### Honest-null rule

If the diff has no issues after you have actually read it, output exactly:

    No issues.

Do NOT pad with vacuous findings to "look thorough". Do NOT invent security
concerns for unauthenticated services, flag harmless third-party scripts as
risky, or list stylistic preferences as findings. A clean "No issues." after a
real review is the correct answer and is preferred over fabricated findings.

Only say "No issues." after you have read every hunk of the diff. Stating it
without reading is worse than saying nothing.
```

In addition, the reviewer prompt MUST contain these two sections (populated by the orchestrator), clearly labeled so the reviewer understands the trust boundary:

- `## Implementer-Reported Summary (untrusted)` - the implementer's report text.
- `## Actual Diff` - the raw output of `git show <sha>` for single-task reviews, or `git diff <base>..<head>` for batched/phase/final reviews.

## Outcome Slot Format

When filling an `Outcome: \`<fill>\`` slot, use this structured single-line format:

```
findings=N critical=N auto_fixed=N deferred=N; <one-sentence summary>
```

Tokens:
- `findings=N` - total admissible findings (numbered, tagged, cited).
- `critical=N` - count of findings tagged `[critical]` or `[correctness]` (the auto-fix-triggering set).
- `auto_fixed=N` - how many critical/correctness findings were fixed by the fix-implementer loop.
- `deferred=N` - how many findings were written to `-deferred.md`. Includes all `[style]` / `[cosmetic]` findings (they always deferred) plus any `[critical]` / `[correctness]` that BLOCKED even at upgraded model.
- `<summary>` - one sentence describing the outcome.
- `inadmissible=N` (optional) - count of findings discarded for missing number/tag/citation.

**Invariant:** `findings == auto_fixed + deferred`. If they don't match, the orchestrator lost a finding - halt and reconcile before filling.

Examples:
- `findings=0 critical=0 auto_fixed=0 deferred=0; No issues.`
- `findings=3 critical=1 auto_fixed=1 deferred=2; Null check added; 2 style findings deferred to §12-§13.`
- `findings=10 critical=4 auto_fixed=3 deferred=7; 1 correctness BLOCKED at opus, deferred §5; 6 style deferred §6-§11.`
- `findings=5 critical=0 auto_fixed=0 deferred=5 inadmissible=2; 2 uncited findings discarded; 5 style deferred.`

Prose-only Outcomes (no `findings=` token) fail Final Verification. The machine-checkable prefix is how `/fly` audits that reviews actually ran, how they resolved, and that no finding was silently dropped.

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
  3. Fill Outcome slot with summary.
  4. If findings: same auto-fix loop as per-task reviews. Fill Resolution.

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
  3. Fill the Phase Gate Outcome using the structured format, prefixed with the regression check metrics from above:

         tests_pass=N tests_fail=N regressions=0; findings=N critical=N auto_fixed=N deferred=N; <summary>

  4. Note: `/deep-review` has its own auto-fix mechanism internally. If the subagent reports that certain findings were already auto-fixed inside `/deep-review`, count those in `auto_fixed`. Findings the skill itself flagged as deferred go into `/fly`'s deferred.md (same file - don't create a separate one).

## Final Gate

After all phases complete, check the checklist's final gate:

- If `## Final Gate: /deep-review over <scope>` exists:
  1. Dispatch a subagent to invoke `/deep-review` via the Skill tool, same pattern as the deep-review Phase Gate above (see "Dispatch pattern: subagent → Skill tool"). Scope per the checklist annotation.
  2. Process returned findings with the accounting invariant (`findings = auto_fixed + deferred`). All style/cosmetic findings → deferred.md.
  3. Fill Outcome slot using the structured format: `findings=N critical=N auto_fixed=N deferred=N; <summary>`.
  4. Fill Resolution slot per the outcome (Fixed / deferred references / mix).

- If `**Final gate not needed - all phases have deep-review coverage.**` exists: skip; nothing to do.

## Deferred File Handling

`<plan-basename>-deferred.md` is the catch-all for every admissible finding that was NOT auto-fixed. It is the complete post-execution to-do list. Creating a deferred entry is cheap; losing a finding is unbounded damage.

Create/append to the deferred file when:
- A fix-implementer reports BLOCKED even at an upgraded model (→ that one finding is deferred).
- A `/deep-review` invocation reports findings it couldn't auto-fix (→ each one is a deferred entry).
- Any `[style]` or `[cosmetic]` admissible finding exists from any review (per-task spec/code, batched, phase gate, final gate). Style/cosmetic are ALWAYS deferred - they are not auto-fixed per policy, but they must still be tracked.

Each finding gets its OWN `§N` entry. Do not consolidate multiple findings into one entry - each distinct citation is its own section, even if they're all tagged `[style]` or share a theme. The user will triage them in a hygiene pass; a flat numbered list is easier to process than nested bullets.

Format:

```markdown
# Deferred Items: <feature>

> Items found during `/fly` execution that were not auto-fixed. Review and address manually before shipping (or schedule for a hygiene pass).

## §1: <task/gate context> - [critical|correctness|style|cosmetic] <short title>

**Finding:** <description from reviewer, preserving file:line citation>

**Why deferred:** <one of: "style/cosmetic - not auto-fixed by policy" | "fix-implementer reported BLOCKED: <reason>" | "deep-review output flagged as manual">

**Suggested fix:** <from reviewer's output>
```

When writing a deferred item:
1. Assign the next available `§N`.
2. Include the severity tag in the heading so the user can grep by type (`grep "\[style\]" -deferred.md`).
3. Update the corresponding Resolution slot in the checklist: `Action: Deferred to <plan-basename>-deferred.md §N` (or `§A-§Z` for ranges).

If the deferred file doesn't exist yet, create it with the header before appending `§1`.

**Anti-pattern**: batching 10 style findings into a single `§N: style nits` section with 10 bullets. This loses the individual citations and makes per-finding triage harder. Each finding is its own entry.

## Final Verification

After all tasks, phase gates, and final gate are processed, run the verification block at the bottom of the checklist. Tick each item by actually verifying:

- **All plan-step and [INJECTED] checkboxes ticked:** grep the checklist for `- \[ \]` occurrences before the verification block. Should find none. If any found, halt: "Task <X> step <N> not ticked - did the implementer actually complete it?"

- **All SHA slots filled:** grep for `SHA: \`<fill>\``. Should find none.

- **All Outcome slots filled (non-`<fill>`):** grep for `Outcome: \`<fill>\``. Should find none.

- **Outcome slots use structured format:** grep for `Outcome: \`` lines that do NOT contain `findings=`. Should find none. Prose-only Outcomes without the `findings=N critical=N auto_fixed=N deferred=N` prefix fail verification - they indicate a review happened without structured accounting (or no review happened at all).

- **Findings accounting invariant:** for every Outcome, parse the tokens and confirm `findings == auto_fixed + deferred`. If mismatch, findings were dropped. Halt and ask the user to reconcile.

- **Phase Gate Outcomes contain regression-check prefix:** each phase's Outcome must start with `tests_pass=N tests_fail=N regressions=0;`. Any phase missing this prefix means the Phase regression check was skipped - halt and fail.

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
| "The implementer's summary says it's good, reviewer can skim" | The summary is UNTRUSTED. Reviewer must read the `## Actual Diff` independently. Dispatching a reviewer with only the summary is reviewer priming. |
| "I'll just write 'Looks good' in the Outcome slot" | Outcome needs `findings=N critical=N auto_fixed=N`. Prose-only fails Final Verification. If you didn't count, you didn't review. |
| "Reviewer returned findings without file:line, I'll act on them anyway" | Inadmissible. Fabricated findings without citations waste fix cycles. Discard, log `inadmissible=N`, move on. |
| "Auto-fixing this style nit won't hurt" | Only `[critical]` / `[correctness]` auto-fix. Style/cosmetic amplifies fabricated-finding waste. Log and move on. |
| "That test was probably failing on main anyway" | Phase regression check: run the suite at the phase base commit. Assertion without running is gaslighting. |
| "This task looks harder than sonnet, let me use opus to be safe" | NO. The checklist is the contract. If you think the model is wrong, HALT and ask the user to edit the checklist. Silent upgrades destroy the audit trail - the checklist says sonnet, the dispatch log says opus, reality becomes un-reproducible. |
| "Opus is better, it won't hurt to upgrade" | Cost and audit: opus costs more, and "we used sonnet" becomes a lie when checklist-vs-dispatch drift. Preflight picked sonnet for a reason. Respect the decision or surface the disagreement to the user. |
| "I'll use opus for the reviewer because this code is tricky" | Same rule. Reviewer model is in the checklist. Upgrading silently also primes the review outcome (opus reviews differ from sonnet reviews) and defeats preflight's per-gate assignment. |
| "Defaulting to opus is fine for everything" | It is NOT fine. Preflight assigned per-task models to balance cost, latency, and appropriate rigor. A fly run that always uses opus has ignored the checklist. |
| "Reviewer returned 20 findings, let me consolidate the main ones" | NO. Every admissible finding gets processed by number. Consolidation into prose loses detail. Either auto-fix it (critical/correctness) or deferred-write it (style/cosmetic). No third option. |
| "This style finding isn't worth a deferred entry" | WRONG. Deferred entries cost nothing; losing findings costs unbounded quality drift. Every style/cosmetic finding gets its own §N. |
| "I'll batch these 10 style findings into one §N entry with bullets" | NO. Each citation is its own entry. Flat enumerated list is easier for the user to triage than nested bullets. Anti-pattern explicitly called out. |
| "Let me paraphrase /deep-review's structure into a subagent prompt instead of invoking the skill" | NO. Paraphrasing destroys the skill's tuned behavior (parallel Codex review, Chrome MCP UI review, etc.) and destroys the audit trail. Dispatch a subagent that invokes the skill via Skill tool. |
| "The reviewer tagged duplication as [style] so I won't escalate" | Read the project's CLAUDE.md/AGENTS.md. If it says "duplication has always led to bugs" or "One source, one truth", duplication is [correctness], not [style]. Project rules override generic tagging. |
| "findings = 10, auto_fixed = 2, deferred = 0 - I'll note '8 style findings' in the summary" | INVARIANT VIOLATION: findings must equal auto_fixed + deferred. 8 findings disappeared. Halt and deferred-write each one individually. |

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
- "This nit doesn't need its own deferred entry"
- "I'll write 'style findings deferred' in the summary instead of enumerating them"
- "Invoking /deep-review as a full skill is heavy, let me just replicate its prompts"
- "The reviewer tagged duplication as style, I'll respect their tag" (when CLAUDE.md says duplication is correctness-blocking)

**All of these mean: you are about to violate the checklist contract. Do the work.**

## The Iron Rule

**The checklist is the contract. Every checkbox must be ticked by verifying its condition. Every slot must be filled with actual content. No exceptions, no rationalizations.**

If `/fly` completes without every box ticked and every slot filled, the final verification will catch the gap and halt. Do not try to work around the verification - fix the missing work. The verification exists because commitment contracts only hold when they're enforced.

If you genuinely believe a step is wrong or impossible, surface the issue explicitly to the user. Do not silently skip.
