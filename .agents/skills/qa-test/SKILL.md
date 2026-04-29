---
name: qa-test
description: "Use when the user says 'QA test', 'test the UI', 'click through it', or 'test the flows', or when end-to-end browser validation is needed."
user-invocable: true
---

# QA Test

Launch a browser-only subagent that tests the running app like a real user. The agent has **no access to source code** - it can only see and interact with the browser via Playwright MCP. This forces realistic testing: if a button doesn't work, the agent can't check the onClick handler to understand why. It just reports "FAIL: clicking Submit does nothing."

## When to use

- **Complex multi-step flows** - create event -> add group -> add stops -> reorder -> preview
- **After significant changes** - when you've touched many files and want confidence the flows still work
- **When the user asks** - "test it", "QA this", "click through it"
- **From /build** - when the critique loop reveals the feature has many interaction paths worth testing

**Don't use for:** simple UI changes (copy, colors, layout tweaks), non-frontend work, or features that are just a single page with no interactions.

## How to run

1. **Identify the test URL and scenarios.** Look at what was built and determine:
   - The starting URL (from `launch.json` port)
   - 3-7 test scenarios covering happy path, edge cases, and navigation

2. **Launch a subagent** with `model: "sonnet"` and this prompt (fill in the specifics):

```
You are a QA tester. You can ONLY use Playwright MCP browser tools - you cannot read or edit source code.

Test the feature at: http://localhost:<PORT>/<path>

Feature: [brief description of what was built]

Test these scenarios:
1. [Happy path - the main flow end-to-end]
2. [Edge case - empty state, no data]
3. [Edge case - invalid input, form validation errors]
4. [Edge case - very long text, special characters]
5. [Navigation - back button, URL changes, refresh]
6. [Any feature-specific scenarios]

For each scenario:
- Navigate to the starting point
- Perform the actions a real user would
- Use browser_snapshot after each interaction to verify the result
- Use browser_take_screenshot for visual issues
- Report: PASS (works as expected), FAIL (broken), or CONCERN (works but feels wrong)

After testing, produce a structured report:

## QA Report

### Summary
X scenarios tested: Y PASS, Z FAIL, W CONCERN

### Results
| # | Scenario | Status | Notes |
|---|----------|--------|-------|
| 1 | [name]   | PASS   | [brief note] |
| 2 | [name]   | FAIL   | [what went wrong] |

### Failures (details)
For each FAIL:
- Steps to reproduce
- What happened vs what was expected

### Concerns
For each CONCERN, plain English with the user-facing impact:
- **<plain-English title>**
  - **What feels wrong:** <2-3 sentences in user terms - what did the QA tester see/feel?>
  - **User-facing impact:** <one sentence: what would a real user experience? "A first-time user would hesitate before clicking the primary action because the label is ambiguous", "Power users will work around it but new users will get stuck", "Looks fine but is one click slower than it needs to be on the most common path">
  - **Why I didn't fail it:** <one short sentence - works as built, just suboptimal>
```

3. **Act on the results:**
   - **FAILs** - fix them. These are real bugs.
   - **CONCERNs** - include in the build report for the user to decide.
   - **All PASS** - note it in the build report ("QA: all scenarios passed").

## Output

When called by another skill, return the QA report for inclusion in the build report. When called standalone, present the report directly and offer to fix any FAILs.
