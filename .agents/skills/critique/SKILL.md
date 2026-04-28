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

Use **Playwright MCP** tools for all browser interaction. These give you a real browser you can click, type, and navigate - not just screenshots.

### Tool reference

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Go to a URL |
| `browser_snapshot` | Get accessibility tree (fast, cheap - use for structure/content checks) |
| `browser_take_screenshot` | Get visual screenshot (use for layout/design checks) |
| `browser_click` | Click an element (by text, role, or ref from snapshot) |
| `browser_type` | Type into a field |
| `browser_tab_navigate_back` | Browser back button |
| `browser_press_key` | Press keys (Tab, Enter, Escape, etc.) |
| `browser_hover` | Hover over an element |
| `browser_resize` | Resize viewport |

### Steps

1. **Make sure the dev server is running.** Check `launch.json` for the port.

2. **Navigate and take a screenshot** for the visual first impression:
   ```
   browser_navigate → http://localhost:<PORT>/relevant-path
   browser_take_screenshot
   ```

3. **Get the accessibility snapshot** to understand page structure:
   ```
   browser_snapshot
   ```
   This returns the element tree with refs you can click/interact with. It's cheaper than screenshots for checking content and structure.

4. **Actually use the UI.** This is the key difference from just looking at screenshots. Click through the real flows:
   - Click buttons, open dialogs, submit forms
   - Fill in form fields with test data
   - Try the happy path end-to-end
   - Try edge cases (empty fields, very long text, special characters)
   - Tab through interactive elements to check focus order
   - Hover over elements to check hover states
   - Press Escape to dismiss dialogs
   - Use browser back to check navigation

   After each interaction, take a snapshot or screenshot to verify the result.

5. **Check console for errors** after interacting. Use `browser_console_messages` or check via snapshot for error states in the UI.

6. **Evaluate.** For each page/view, answer two questions:

   **What do I like about this?**
   Be specific. "The spacing between cards feels right" not just "looks good".

   **What could be improved?**
   Be specific. "The delete button has no hover state" not just "needs polish".

7. **Produce a numbered list** of improvements. For each item, decide:
   - **Act on it** - clear improvement, low risk, worth doing now
   - **Skip** - subjective, high-effort, would need rethinking, or not worth the cost

8. **Implement** all "act on it" items.

9. **Re-test interactively** to verify fixes. Don't just screenshot - click through the same flows again to confirm the fixes actually work.

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

For each skipped item, plain English with the user-facing impact:
- **<plain-English title>**
  - **What's happening:** <what the user sees today, in feature terms - not "the button uses a different border-radius than the cards", but "the primary action button doesn't visually match the rest of the page">
  - **User-facing impact:** <one sentence: how does this affect a real user? "Looks slightly inconsistent but no one will misuse the page", "Subtle - regular users won't notice, but reviewers/stakeholders will flag it", "Could confuse first-time users about what's clickable">
  - **Why I skipped:** <one short sentence>

### Could still improve

For each item, same plain-English / user-facing-impact format:
- **<plain-English title>**
  - **What's happening:** <2-3 sentences in user terms>
  - **User-facing impact:** <one sentence>
  - **Worth considering because:** <one sentence>
```

**Why this format matters:** UI critiques especially tend toward jargon ("inconsistent border-radius scale", "non-grid-aligned spacing"). Translating to user impact ("buttons feel mismatched", "the page feels slightly off without the user being able to say why") is what lets the user actually decide if it's worth their time. If the impact is genuinely subjective polish, say so explicitly: "User-facing impact: minimal - this is taste, not a usability issue."

When called by another skill (e.g. `/build`), return this summary for inclusion in the build report.
