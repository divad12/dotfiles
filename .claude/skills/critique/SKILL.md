---
name: critique
description: "Visually critique the current UI/UX by taking screenshots, evaluating what's good and what could be improved, and acting on findings. Use when the user says 'critique', 'critique the UI', 'how does it look', 'check the UI', 'visual review', or 'polish the UI'. Also use proactively after implementing frontend features to catch visual issues before presenting to the user."
user-invocable: true
---

# Critique

Step back and evaluate the current UI/UX with fresh eyes. Take screenshots, assess what's working and what isn't, then fix what you can. This is a visual and interaction review, not a code review.

## When to use this

- After implementing a frontend feature (before presenting to the user)
- When the user asks "how does it look" or "critique this"
- When called by other skills (e.g. `/build` uses this in its critique loop)

## What to test

### 1. First impression (5-second test)

Open the page and take a screenshot. Before analyzing details, answer:
- Where does my eye go first? Is that the right place?
- Does this feel intentional and designed, or default and generic?
- Could I tell what this page does from a glance?

### 2. Visual design

| Check | What to look for |
|-------|-----------------|
| **Hierarchy** | Clear entry point. Primary action is obvious. Secondary content recedes. |
| **Spacing** | Consistent scale (4/8/12/16/24/32/48). No arbitrary values. Related items grouped. |
| **Alignment** | Elements snap to a grid. No subtle misalignments. |
| **Typography** | Font sizes from a deliberate scale. Line heights readable (1.4-1.6 for body). No more than 2-3 font sizes per view. |
| **Color** | Palette feels cohesive. Accent colors used for emphasis, not decoration. Sufficient contrast (WCAG AA: 4.5:1 body, 3:1 large text). |
| **Borders & shadows** | Consistent weight. Not overused. Serve a purpose (separation, elevation). |
| **Icons** | Consistent style and size. Meaningful, not decorative. |

### 3. Layout and structure

- No overlapping, clipped, or overflowing elements
- Content doesn't stretch too wide (max ~65ch for body text)
- Whitespace is purposeful, not accidental
- Page has clear sections with visual separation
- No orphaned elements floating without context

### 4. States (check every one that applies)

| State | How to test | What to look for |
|-------|------------|-----------------|
| **Empty** | Clear any data or navigate to an empty collection | Helpful message, not just blank space. Suggests what to do next. |
| **Loading** | Refresh the page or trigger data fetch | Skeleton or spinner visible. No layout shift when content loads. |
| **Error** | Submit invalid data or disconnect network | Clear error message near the problem. Not just a red border. |
| **Hover** | Mouse over interactive elements | Visual feedback. Cursor changes. Tooltips where helpful. |
| **Focus** | Tab through the page | Visible focus ring. Logical tab order. No focus traps. |
| **Disabled** | Find any disabled controls | Visually muted. Cursor indicates not-interactive. Tooltip explains why. |
| **Overflow** | Add very long text or many items | Text truncates gracefully. Lists scroll. No broken layouts. |

### 5. Interactions

- Click through the main flows. Do forms submit? Do buttons respond?
- Are destructive actions confirmed? (delete, remove, discard)
- Do transitions feel smooth? No jarring jumps.
- Does the back button work? Does the URL update?
- Are there loading indicators for async operations?

**If there are forms/dialogs**, also check (per CLAUDE.md conventions):
- Required fields marked with red `*`
- Submit button disabled until required fields filled, text reflects the action (not generic "Submit")
- Enter key submits the form (`<form>` tag with `onSubmit`)
- Validation on blur + inline errors (red border + message below field, not toasts)
- Errors clear when user starts typing
- Loading state on submit ("Saving...")
- Pre-populated fields where context is available
- Server errors displayed inline, never silently swallowed

### 6. Consistency

- Does the new UI match the existing design language?
- Same button styles, card patterns, table formats?
- Same spacing between similar elements?
- Same color usage (e.g., red for errors, not suddenly for a non-error accent)

### 7. Accessibility quick-check

- [ ] Color contrast passes (use browser devtools or visual inspection)
- [ ] All images have alt text
- [ ] Form inputs have visible labels (not just placeholders)
- [ ] Interactive elements reachable via keyboard (tab through the page)
- [ ] Focus indicators visible
- [ ] No information conveyed by color alone
- [ ] `prefers-reduced-motion` respected on animations

## How to run

1. **Make sure the dev server is running.** Check `launch.json` for the port.

2. **Navigate and screenshot.** Use `playwright-cli` to open the relevant pages:
   ```
   playwright-cli open http://localhost:<PORT>/relevant-path
   playwright-cli screenshot
   ```

3. **Check console for errors:**
   ```
   playwright-cli console
   ```
   Fix any console errors before continuing the visual review.

4. **Test states.** Don't just look at the happy path. Click through, tab through, try edge cases:
   ```
   playwright-cli snapshot          # see element refs
   playwright-cli click e5          # interact
   playwright-cli fill e3 "text"   # fill forms
   playwright-cli screenshot        # capture result
   ```

5. **Evaluate.** For each page/view, answer two questions:

   **What do I like about this?**
   Be specific. "The spacing between cards feels right" not just "looks good".

   **What could be improved?**
   Be specific. "The delete button has no hover state" not just "needs polish".

6. **Produce a numbered list** of improvements. For each item, decide:
   - **Act on it** - clear improvement, low risk, worth doing now
   - **Skip** - subjective, high-effort, would need rethinking, or not worth the cost

7. **Implement** all "act on it" items.

8. **Re-screenshot** to verify fixes didn't break anything.

## Rounds

- **Round 1:** Always runs.
- **Round 2:** If round 1 acted on 3+ items, do another pass. Fresh eyes catch things fixes revealed.
- **Round 3:** Only if round 2 still acted on 3+ items. Stop after 3 rounds regardless.

Each round should find fewer issues than the last. If it's not converging, the approach may need rethinking. Stop and flag it.

## Output format

After the critique, present a summary:

```
## Critique Summary

### What's working well
- [Specific things that look good]

### Changes made
1. [What was changed and why]
2. [...]

### Skipped (not worth doing now)
- [What was left and why]

### Could still improve
- [Things worth considering but not critical]
```

When called by another skill (e.g. `/build`), return this summary for inclusion in the build report.
