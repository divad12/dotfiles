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

Parse the reviewer's output. For each finding, classify by its tag:

- **Inadmissible** - missing a tag, or missing a `<file>:<line>` citation. Log to Outcome (`inadmissible=N`) but do NOT auto-fix. Findings without citations are inadmissible on purpose, to prevent auto-fix loops on fabricated or vacuous findings.
- **`[critical]` or `[correctness]`** - trigger auto-fix (see below).
- **`[style]` or `[cosmetic]`** - note in Outcome, do NOT auto-fix. (Auto-fixing nits amplifies fabricated-finding waste without improving correctness.)

If no admissible critical/correctness findings remain:
- Fill `Spec review resolution - Action: \`None needed\`` (or `\`N style/cosmetic noted\`` if those exist). Tick the resolution checkbox. Proceed to code review.

If admissible critical/correctness findings remain:
1. Craft a fix prompt listing only the admissible critical/correctness findings, each with its citation. Do not include inadmissible or style/cosmetic findings.
2. Dispatch fix-implementer with model = task's implementer model (from checklist).
3. Wait for fix report. If BLOCKED or NEEDS_CONTEXT, upgrade model one tier and retry; if still BLOCKED, write to deferred file (see "Deferred File Handling").
4. Re-dispatch spec reviewer (full cycle: independence override, fresh diff, tag requirements). Loop until no admissible critical/correctness findings remain.
5. Fill resolution: `Fixed in <last-fix-commit-sha>`.

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

Every finding MUST be tagged with exactly one severity:

- `[critical]` - breaks correctness, security, or specified behavior
- `[correctness]` - logic error, missing edge case, or wrong output
- `[style]` - naming, formatting, or convention mismatch
- `[cosmetic]` - purely aesthetic

Every finding MUST cite a concrete `<file>:<line>` (or `<file>:<line-line>` for
ranges). Findings without citations are inadmissible and will be discarded by
the orchestrator.

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
findings=N critical=N auto_fixed=N; <one-sentence summary>
```

Tokens:
- `findings=N` - total admissible findings (tagged and cited).
- `critical=N` - count of findings tagged `[critical]` or `[correctness]` (the auto-fix-triggering set).
- `auto_fixed=N` - how many critical/correctness findings were fixed by the fix-implementer loop.
- `<summary>` - one sentence describing the outcome. Include explicit mention of inadmissible findings if any (`inadmissible=N` optional token).

Examples:
- `findings=0 critical=0 auto_fixed=0; No issues.`
- `findings=3 critical=1 auto_fixed=1; Null check added; 2 style nits not auto-fixed.`
- `findings=5 critical=2 auto_fixed=1; 1 deferred to -deferred.md §3; 3 style nits noted.`
- `findings=0 critical=0 auto_fixed=0 inadmissible=2; Reviewer produced 2 untagged findings; discarded.`

Prose-only Outcomes (no `findings=` token) fail Final Verification. The machine-checkable prefix is how `/fly` audits that reviews actually ran and how they resolved.

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

- **Outcome slots use structured format:** grep for `Outcome: \`` lines that do NOT contain `findings=`. Should find none. Prose-only Outcomes without the `findings=N critical=N auto_fixed=N` prefix fail verification - they indicate a review happened without structured accounting (or no review happened at all).

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

**All of these mean: you are about to violate the checklist contract. Do the work.**

## The Iron Rule

**The checklist is the contract. Every checkbox must be ticked by verifying its condition. Every slot must be filled with actual content. No exceptions, no rationalizations.**

If `/fly` completes without every box ticked and every slot filled, the final verification will catch the gap and halt. Do not try to work around the verification - fix the missing work. The verification exists because commitment contracts only hold when they're enforced.

If you genuinely believe a step is wrong or impossible, surface the issue explicitly to the user. Do not silently skip.
