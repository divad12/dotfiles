# Preflight Checklist: Dry-Run Sample

> **READ FIRST:** `.claude/skills/fly/tests/samples/sample-plan-stub.md` - stubbed plan (tasks have no implementation code).
> Built by `/preflight` on 2026-04-17. Execute with `/fly`.

## Decisions
- 2 tasks across 1 phase
- Deep-review coverage: final deep-review covers the single phase
- Per-task models: Phase 1 → haiku
- Review batching: none
- TDD gaps injected: none
- Octopus: deferred

---

## Phase 1: Setup | Phase gate: normal review (reviewer: sonnet)

### Task 1 (plan §Task 1) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test (stub - dry-run)
- [ ] Step 2: Run test, verify FAIL (stub)
- [ ] Step 3: Implement (stub)
- [ ] Step 4: Run test, verify PASS (stub)
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Task 2 (plan §Task 2) | Model: haiku | Review: standard

Plan steps:
- [ ] Step 1: Write failing test (stub)
- [ ] Step 2: Run test, verify FAIL (stub)
- [ ] Step 3: Implement (stub)
- [ ] Step 4: Run test, verify PASS (stub)
- [ ] Step 5: Commit - SHA: `<fill>`

Review gates:
- [ ] Spec review (reviewer: haiku) - Outcome: `<fill>`
- [ ] Spec review resolution - Action: `<fill>`
- [ ] Code review (reviewer: sonnet) - Outcome: `<fill>`
- [ ] Code review resolution - Action: `<fill>`

### Phase 1 Gate (reviewer: sonnet)
- [ ] Normal code-review on Phase 1 diff - Outcome: `<fill>`
- [ ] Phase 1 gate resolution - Action: `<fill>`

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
