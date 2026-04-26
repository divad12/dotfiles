# Preflight Checklist: Sample Feature

> **READ FIRST:** `.claude/skills/preflight/tests/samples/sample-plan.md` - this checklist references plan steps by number; fly needs both files.
> Built by `/preflight` on 2026-04-17. Execute with `/fly`.

## Decisions
- 5 tasks across 2 phases
- Deep-review coverage: final deep-review covers all phases (both phases use normal review; plan is under overwhelm threshold)
- Per-task models: Phase 1 → haiku (simple schema/model/helper), Phase 2 → sonnet (integration concerns)
- Review batching: Task 2 + Task 3 batched (trivial, adjacent, single-file each)
- TDD gaps injected: Task 2, Task 3 (plan lacks failing-test steps)
- Octopus: deferred

---

## Phase 1: Schema and Models | Phase gate: normal review (reviewer: sonnet)

### Task 1 (plan §Task 1) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test for table existence
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Write migration SQL
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 2 (plan §Task 2) | Model: haiku | Review: batched-with Task 3 | TDD steps injected

Plan steps:
- [ ] [INJECTED] Write failing test for ExportRequest model
- [ ] [INJECTED] Run test, verify FAIL
- [ ] Step 1 (from plan): Define model class
- [ ] Step 2 (from plan): Commit - SHA: `<fill>`

(No individual review gates - batch review below covers Task 2 + Task 3)

### Task 3 (plan §Task 3) | Model: haiku | Review: batched-with Task 2 | TDD steps injected

Plan steps:
- [ ] [INJECTED] Write failing test for ExportRow serializer
- [ ] [INJECTED] Run test, verify FAIL
- [ ] Step 1 (from plan): Implement serializer
- [ ] Step 2 (from plan): Commit - SHA: `<fill>`

Batch review gate (covers Task 2 + Task 3):
- [ ] Batch review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Batch review resolution - Action: `<fill>`

### Phase 1 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 1 diff - Outcome: `<fill>`
- [ ] Phase 1 gate resolution - Action: `<fill>`

---

## Phase 2: Query and Endpoint | Phase gate: normal review (reviewer: sonnet)

### Task 4 (plan §Task 4) | Model: sonnet | Review: standard

Plan steps:
- [ ] Step 1: Write failing test for query builder
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement query builder
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 5 (plan §Task 5) | Model: sonnet | Review: standard

Plan steps:
- [ ] Step 1: Write integration test hitting the endpoint
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement endpoint with StreamingResponse
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Phase 2 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 2 diff - Outcome: `<fill>`
- [ ] Phase 2 gate resolution - Action: `<fill>`

---

## Final Gate: /deep-review over all phases
- [ ] Outcome: `<fill>`
- [ ] Final gate resolution - Action: `<fill>`

---

## Fly Verification
- [ ] All plan-step and [INJECTED] checkboxes ticked
- [ ] All SHA slots filled
- [ ] All Outcome slots filled (non-`<fill>`)
- [ ] All Resolution slots filled (non-empty, not "ignored"/"skipped")
- [ ] Deep-review invariant satisfied
- [ ] If `<feature>-deferred.md` exists, surface contents to user
