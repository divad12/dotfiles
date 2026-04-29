# Checklist Format

Tracking-only markdown file. Every task and review gate is a checkbox; every SHA and outcome is a `<fill>` slot that `/fly` replaces during execution. Task content (files, steps, code blocks) lives in the plan file, not the checklist.

## Header

Single-session case:

```markdown
# Preflight Checklist: <feature>

> **READ FIRST:** `plan.md` (this session's plan content).
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

Multi-session case (each file 1..K):

```markdown
# Preflight Checklist: <feature> (File X of K)

> **READ FIRST:** `plan-X.md` (this session's plan content).
> Full plan at `plan.md` for audit.
> Built by `/preflight` on YYYY-MM-DD. Execute with `/fly`.
```

`<feature>` is the plan file's basename without date prefix or `.md` extension. E.g., `2026-04-17-export.md` -> `Export`.

## Decisions block

```markdown
## Decisions
- <N> tasks across <M> phases
- Deep-review coverage: <summary>
- Per-task models: <per-phase or per-task summary>
- Phase normal review: <list of phases that need it> | none (all tasks reviewed individually)
- TDD gaps injected: <list of task IDs> | none
- LOC distribution: avg <N>, median <N>; inline <X>, subagent <Y>; smallest <id>=<N>, largest <id>=<N>
- Phase verification tags: <per-phase summary, e.g., "Phase 0: tests-only, Phase 1: suggest-verify">
- Split: single file | <K> files (<file-paths>)
```

In split mode, the `Split:` line lists the sibling checklist file paths (e.g., `3 files (checklist-1.md, checklist-2.md, checklist-3.md)`). Each file carries this same line so a reader of any one file sees the full split.

## Phase blocks

```markdown
## Phase <N>: <phase name> | Phase gate: <normal review | deep-review> (reviewer: <model>)
```

Tasks are tracking-only (no embedded plan content):

```markdown
### Task <id> | Model: <haiku|sonnet|opus> | Mode: <inline | subagent> | LOC: ~<N> | Review: <combined | separate | phase>

Plan steps:
- [ ] Step 1: <title extracted from plan>
- [ ] [INJECTED] <injected step title, if any>
- [ ] Step N: Commit - SHA: `<fill>`

Review gates:
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`

(For tasks with `Review: separate`, use the legacy two-block format: `Spec review` + `Spec review resolution` + `Code review` + `Code review resolution`.)

(For tasks with `Mode: inline`, KEEP the Review gates block exactly as for subagent mode. The orchestrator does the implement, but a reviewer subagent still reviews the diff. Only the implementer dispatch is skipped.)
```

No **Files:** block, no embedded task text, no code blocks. Fly reads task content from the plan file (plan.md for single-session, plan-N.md for multi-session).

## Synthetic integration-test task

Injected when at least one verification step in the phase was convertible. Placement: at the end of the phase's impl tasks, but BEFORE any "final cleanup" task that audits the phase's work (signals: last task, looks like cleanup/audit/summary commit/typecheck-lint-build smoke). Use your judgment on which task is the cleanup. Goal: cleanup audits the test file too, and the integration test runs against complete impl. If no cleanup task exists, append after the last impl task:

```markdown
### Task <N>.synthetic-test [SYNTHETIC: integration-test] | Model: sonnet | Mode: subagent | LOC: ~<N> | Review: combined

Goal: write integration test covering Phase <N> end-state verification (auto-generated from plan's manual test steps).

Convertible steps to cover:
- <step 1 verbatim from plan, with mock/fake/fixture noted>
- <step 2 verbatim from plan, with mock/fake/fixture noted>
- ...

Plan steps:
- [ ] Step 1: write failing integration test covering the steps above
- [ ] Step 2: run test, verify FAIL for the right reason
- [ ] Step 3: implement (only if production code missing - usually skip)
- [ ] Step 4: run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`

(For tasks with `Review: separate`, use the legacy two-block format: `Spec review` + `Spec review resolution` + `Code review` + `Code review resolution`.)
```

For tasks annotated `Review: phase`, omit per-task review gates entirely. The phase-end normal review (below) covers them collectively.

## Phase end-state verification block

Goes before the phase gate, at the end of each phase's tasks - AFTER any synthetic integration-test task:

```markdown
### Phase <N> end-state verification
- Type: <tests-only | has-residual>
- Automated coverage: synthetic integration test covers: <list of convertible steps> | none
- Residual manual test: <list of truly-manual steps with brief rationale per item> | none (all steps automated)
```

Tag is binary:
- `tests-only`: ALL verification steps were convertible (no residual manual). Most common outcome.
- `has-residual`: at least one truly-manual step remains. The end-of-run synthetic deferred-resolution task surfaces these to the user as the "Try it yourself" walkthrough.

If the plan has no "Phase end-state test" paragraph for a phase, both lines read `(none specified in plan)` and tag is `tests-only`.

## Phase regression check + (optional) phase normal review

Phase gate at the end of each phase block (after the end-state verification):

```markdown
### Phase <N> Regression Check
- [ ] Run tests; verify no regressions on Phase N diff - Outcome: `<fill>` (`tests_pass=N tests_fail=N regressions=0`)
- [ ] Phase <N> regression resolution - Action: `<fill>`
```

If any task in the phase has `Review: phase`, ALSO emit a Phase Normal Review block right after the regression check (replaces the old "batch review" attached to last task in batch):

```markdown
### Phase <N> Normal Review (covers Tasks <a>, <b>, <c> with Review: phase)
- [ ] Code review of cumulative diff for `Review: phase` tasks (reviewer: <model>) - Outcome: `<fill>`
- [ ] Phase <N> review resolution - Action: `<fill>`
```

If no task in the phase has `Review: phase`, omit this block entirely. Skip directly to next phase.

## Session deep-review gate (END of every checklist)

Always present, every checklist (single-session OR per checklist-N.md in multi-session). Covers the cumulative diff for THIS session's tasks.

```markdown
## Session Gate: /deep-review over <scope description>
- [ ] Outcome: `<fill>`
- [ ] Session gate resolution - Action: `<fill>`
```

Scope description for single-session: `all session tasks (<base-sha>^..HEAD)`.
Scope description for multi-session: `session N tasks (<session-N-base-sha>^..HEAD)`. Each session-N's gate covers ONLY its own session's commits, not prior sessions'.

In split mode, EVERY checklist file (1..K) has its own Session Gate. They are independent gates, each covering only that session's diff.

## Deferred resolution task (every checklist file)

Inserted at the end of EVERY checklist (single-session: after Session Gate, before Fly Verification; multi-session: end of each checklist-N.md so each session clears its own backlog). Always injected. See `references/synthetic-tasks/deferred-resolution.md` for the full task body. Brief skeleton:

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Review: combined

Goal: do as much of the deferred work as possible automatically; surface the rest clearly with recommendations. Also compose "Try it yourself" walkthrough for residual manual verification. (See preflight skill for full prompt.)

Plan steps:
- [ ] Step 1: read `<plan-basename>-deferred.md` (no-op if missing/empty)
- [ ] Step 2: for each §N, try to resolve OR format as user-facing block
- [ ] Step 3: compose "Try it yourself" walkthrough from residual manual items
- [ ] Step 4: print summary; commit deferred.md Status updates - SHA: `<fill>`

Review gates:
- [ ] Combined review (reviewer: <model>) - Outcome: `<fill>`
- [ ] Combined review resolution - Action: `<fill>`
```

## Verification block (LAST file only in split mode; always present in single-file mode)

```markdown
## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
```

In split mode, files 1..K-1 do NOT contain a Fly Verification block. Only file `K` does.

## Next-file pointer (split mode, files 1..K-1 only)

At the very end of each non-last file, append a single line:

```markdown
Next file: <relative-path-to-next-checklist>
```

Omit this line on file `K`.
