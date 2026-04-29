---
name: bugfix-tdd
description: "Use when the user reports a bug or says 'fix', 'broken', 'doesn't work', 'regression', or describes unexpected behavior."
---

# Bugfix TDD

Every bug fix starts with a failing test. No exceptions.

## Steps

### 1. Write a failing test FIRST - before ANY investigation

**Do NOT read the implementation code yet.** Do not investigate the root cause. Do not look at what function is responsible. Write the test purely from the user's description of what's broken - the symptom, not the cause.

Why: If you investigate first, you'll write a test that targets the specific bug you found (e.g., "off-by-one in line 42"). That test is too specific - it only guards against that exact mistake. Instead, write the test from the user's perspective: "when I do X, I expect Y but get Z." This produces a behavioral regression test that catches ANY cause of the same symptom, including future bugs you can't predict.

Write a test that:
- **Describes the symptom from the user's perspective** - what they did, what they expected, what happened instead
- **Asserts the correct behavior** - what SHOULD happen
- **Is minimal** - tests only this bug, not the whole feature
- **Has a descriptive name** - e.g., `it("should not double-count stops when reordering")`
- **Uses only the public API / component interface** - not internal implementation details

Run the test and confirm it fails. If it passes, your test doesn't reproduce the bug - rewrite it.

```
# Run just the new test to confirm it fails
npm test -- --run -t "your test name"
```

### 2. NOW investigate and find the root cause

With the failing test in hand, read the relevant code and find the root cause. Use these techniques:

**Trace backward, not forward.** Don't fix where the error appears - trace up the call chain. Ask "what called this with bad data?" repeatedly until you reach the original source. Example: `git init` ran in the wrong directory because `projectDir` was empty, because `context.tempDir` was accessed before `beforeEach`. Fix at source, not symptom.

**For cross-layer bugs, instrument each boundary.** If the bug spans multiple components (form -> API route -> service -> database), add temporary logging at each boundary to see where data goes wrong. Run once, read the logs, identify the failing layer. Don't guess which layer - observe it.

**Find duplicated logic.** If similar code exists elsewhere that works correctly, that's both a clue to the bug AND a problem in itself - it should have been consolidated. Note it for step 3.

### 3. Fix the bug and consolidate

Now fix the implementation. Change what's necessary to make the failing test pass. If you found duplicated logic in step 2, consolidate it as part of the fix - duplication is a bug factory and deduplication prevents the same class of bug from recurring elsewhere.

**Defense-in-depth:** After fixing the root cause, consider adding validation at other layers the bad data passed through. A single fix at the source is correct but fragile - validation at multiple layers makes the bug structurally impossible to recur from new code paths.

### 4. Verify

Run the full test suite to confirm:
- Your new test passes
- No existing tests broke

```
npm test -- --run
```

### 5. Summarize

Tell the user:
- What the bug was (root cause)
- What the test covers (regression guard)
- What the fix was (minimal change)

## Rules

- **Never skip the test.** Even if the fix is "obvious", the test prevents this exact bug from returning.
- **Never modify the test after writing it** to make it pass. If the test is wrong, that's a different issue - fix the test to correctly describe the expected behavior, confirm it still fails, THEN fix the code.
- **Test at the right level.** Unit test for logic bugs. Integration/API test for data flow bugs. E2E test only if the bug is purely a UI interaction issue.
- **One test per bug.** Don't bundle multiple bug fixes into one test.
- **3 failed fixes = stop and escalate.** If you've tried 3 fixes and the test still fails, stop. This is a signal the architecture is wrong, not that you haven't found the right tweak. Tell the user: "I've tried 3 approaches and none worked. This might be an architectural issue. Here's what I've learned so far: [findings]. How do you want to proceed?"
