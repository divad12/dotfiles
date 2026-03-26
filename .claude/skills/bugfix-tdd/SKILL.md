---
name: bugfix-tdd
description: "Fix a bug by first writing a failing test that reproduces it, then fixing the code to make the test pass. The test becomes a permanent regression guard. Triggers automatically when the user reports a bug, says 'fix', 'broken', 'doesn't work', 'regression', or describes unexpected behavior."
---

# Bugfix TDD

Every bug fix starts with a failing test. No exceptions.

## Steps

### 1. Understand the bug

Read the relevant code. Reproduce the issue mentally (or via the dev server if it's a UI bug). Identify the exact incorrect behavior and what the correct behavior should be.

### 2. Write a failing test FIRST

Before touching any implementation code, write a test that:
- **Reproduces the exact bug** - it must FAIL on the current code
- **Asserts the correct behavior** - what SHOULD happen
- **Is minimal** - tests only this bug, not the whole feature
- **Has a descriptive name** - e.g., `it("should not double-count stops when reordering")`

Run the test and confirm it fails. If it passes, your test doesn't reproduce the bug - rewrite it.

```
# Run just the new test to confirm it fails
npm test -- --run -t "your test name"
```

### 3. Fix the bug

Now fix the implementation. Change only what's necessary to make the failing test pass. Keep the fix minimal and atomic. If you spot a worthwhile refactor (e.g., deduplication), do it as a separate step after the test is green - don't mix it into the bug fix.

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
