---
name: deep-review
description: "Run a thorough five-way code review: collateral change audit, Claude's own diff analysis, a simplification/code-quality pass, Codex review, and a UI usability review (if frontend changes are present) - all in parallel. Consolidates findings, auto-fixes must-fix and easy-win items, flags collateral changes for user decision, runs a verification round, then presents remaining suggestions. Use when the user says 'deep review', 'thorough review', 'full review', 'triple review', or 'ultra review'."
user-invocable: true
---

# Deep Review

Run multiple independent review passes in parallel, consolidate findings, auto-fix what's safe, verify the fixes, and present the rest for user decision.

The value of multi-agent review is that each reviewer has a different perspective and catches different things. An independent reviewer (like Codex) doesn't share the blind spots of the agent that wrote the code. A UI reviewer catches usability issues that a code-focused review misses. Running them in parallel costs no extra wall-clock time.

## Overview

This skill orchestrates a comprehensive review by combining up to five perspectives:

1. **Collateral change audit** - flag changes to existing behavior that aren't required by the feature
2. **Claude review** - diff analysis, correctness, conventions, code quality
3. **Simplify pass** - code reuse opportunities, unnecessary complexity, efficiency, dead code
4. **Codex review** - independent AI review with fresh eyes (no shared context with the coding agent)
5. **UI review** - usability, accessibility, and design quality (only when frontend files are changed)

After all reviews complete, findings are consolidated, deduplicated, and categorized for action.

## Steps

### 1. Determine the review scope

Figure out what to review based on the current state:

```bash
# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')

# Check how many commits ahead of origin/main
AHEAD=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
```

- If there are uncommitted changes, review those (the common case during development).
- If working tree is clean but the branch has commits ahead of main, review the branch diff against main.
- If neither, tell the user there's nothing to review.

Also check whether frontend files are in the diff (`.tsx`, `.jsx`, `.css`, `.scss`, component files, layout files). This determines whether the UI review runs.

### 2. Launch all reviews in parallel

Run these simultaneously. Do NOT wait for one to finish before starting the next.

#### Review 0: Collateral change audit (run inline, in parallel with other reviews)

Examine every changed file in the diff and ask: "Is this change strictly required for the feature being reviewed, or does it modify existing working behavior?"

For each hunk in pre-existing files, check:
- **Styling changes** - colors, spacing, borders, fonts that aren't part of the feature
- **Logic changes** - conditionals, data flow, API calls that aren't needed for the feature
- **Removed code** - imports, props, state, functions removed but not replaced by the feature
- **Renamed/restructured code** - refactors bundled into feature work
- **Config/docs changes** - CLAUDE.md, package.json, tsconfig changes unrelated to the feature
- **Leaked worktree changes** - modifications from other branches that got picked up

Flag each collateral change with the file path and a brief explanation of what it changes and why it's unrelated to the feature. These go into a dedicated **Collateral Changes** section in the consolidated review (not auto-fixed - always presented for user decision on whether to keep or revert).

#### Review 1: Claude's own review (run inline)

Analyze the diff yourself. Focus on:

- **Correctness** - logic errors, edge cases, off-by-one, null handling, race conditions
- **Type safety** - type errors, unsafe casts, missing types
- **Security** - input validation, auth checks, exposed secrets, XSS/injection
- **Conventions** - naming, file structure, patterns established in CLAUDE.md
- **Data integrity** - schema alignment, missing validations, cascade issues

Use `git diff` (for uncommitted) or `git diff origin/main...HEAD` (for branch) to read the actual changes.

#### Review 2: Simplify pass (run inline)

Review the same diff with a different lens. Focus on:

- **Code reuse** - duplicated logic that should be extracted into shared functions
- **Unnecessary complexity** - over-engineered abstractions, premature optimization, unnecessary indirection
- **Dead code** - unused imports, unreachable branches, commented-out code
- **Efficiency** - N+1 queries, unnecessary re-renders, redundant API calls, oversized bundles
- **API surface** - functions/components doing too much, unclear interfaces
- **Dependencies** - unnecessary new dependencies when existing ones suffice

#### Review 3: Codex review (run as background task)

Launch Codex in the background while you do reviews 1 and 2:

```bash
# For uncommitted changes:
codex review --uncommitted

# For branch changes:
codex review --base main
```

Use the `run_in_background` option so it runs concurrently with your own analysis.

#### Review 4: UI review (run as subagent, only if frontend files changed)

If the diff includes frontend files (`.tsx`, `.jsx`, `.css`, `.scss`, or component/layout/page files), launch a subagent in the background to do a UI-focused review. The subagent uses **Playwright MCP** to actually interact with the running app - not just read code. It should:

1. Read the changed frontend files to understand what was modified
2. If a dev server is running, use Playwright MCP to navigate to affected pages:
   - `browser_navigate` to the relevant URL
   - `browser_take_screenshot` for visual layout assessment
   - `browser_snapshot` for accessibility tree / content verification
3. **Interact with the UI** - click buttons, fill forms, hover over elements, tab through:
   - `browser_click`, `browser_type`, `browser_hover`, `browser_press_key`
   - Take snapshots/screenshots after interactions to verify behavior
4. Review against these criteria:
   - **Visual hierarchy and layout** - spacing, alignment, clear entry points
   - **Interactive states** - loading, empty, error, hover, focus, disabled (actually trigger each one)
   - **Accessibility** - contrast ratios (WCAG AA), keyboard navigation (tab through the page), screen reader support (check snapshot roles/labels), `prefers-reduced-motion`
   - **UX patterns** - are interactions intuitive? Do forms validate clearly? Are destructive actions confirmed?
   - **Component API** - are props well-named and minimal? Is the component doing too much?
5. Be specific about findings. Reference file paths and line numbers.

This is better than delegating to Codex because the subagent has direct access to the codebase, can render and interact with the actual UI, and catch behavioral issues that code-only review misses.

Skip this review entirely if no frontend files are in the diff.

### 3. Consolidate findings

Once all reviews are complete, merge the results:

1. **Deduplicate** - if multiple reviews flag the same issue, mention it once and note that multiple reviewers caught it (higher confidence).
2. **Categorize** every finding into one of three buckets:

   **Must fix** (auto-fix these)
   - Correctness bugs (wrong logic, broken functionality)
   - Type errors (compilation failures)
   - Security issues (missing auth, injection, exposed secrets)
   - Data integrity (missing validations that could corrupt data)
   - Accessibility failures (missing alt text, broken keyboard nav, contrast failures)

   **Easy wins** (auto-fix these)
   - Dead code removal (unused imports, unreachable branches)
   - Simple code reuse (obvious extract-function opportunities)
   - Naming improvements (misleading variable/function names)
   - Missing error handling that has a clear fix
   - Convention violations (project-specific rules from CLAUDE.md)
   - Minor UI polish (missing hover states, inconsistent spacing)

   **Suggestions** (present for user decision)
   - Architectural changes (restructuring, new abstractions)
   - Subjective improvements (alternative approaches, style preferences)
   - Performance optimizations that change behavior or add complexity
   - UX redesigns or significant layout changes
   - Anything where reasonable people might disagree

3. **Present the consolidated review** in this format:

   ```
   ## Deep Review Summary

   Reviewed by: Claude (diff + simplify + collateral audit), Codex[, UI review]
   Scope: [uncommitted changes / branch diff against main]
   Files changed: [count] ([N] frontend)

   ### Collateral Changes (for your decision)
   - [ ] file:line - what changed and why it's unrelated to the feature

   ### Must Fix (auto-fixing)
   - [ ] Issue description - file:line - what's wrong and how it's being fixed

   ### Easy Wins (auto-fixing)
   - [ ] Issue description - file:line - what's wrong and how it's being fixed

   ### Suggestions (for your decision)
   - [ ] Issue description - file:line - what's suggested and why
   ```

### 4. Auto-fix must-fix and easy-win items

Apply fixes for all items in the "Must fix" and "Easy wins" categories:

- Make the changes directly. Do not ask for permission on these categories.
- After applying all fixes, run the type checker and linter to confirm nothing is broken:
  ```bash
  npx tsc --noEmit 2>&1 | tail -20
  npm run lint 2>&1 | tail -20
  ```
  Adapt these commands to the project's toolchain (e.g. `cargo check`, `go vet`, `ruff check`).
- If a fix introduces new errors, revert that specific fix and move the item to "Suggestions" instead.
- Do NOT commit the fixes. Leave them as uncommitted changes for the user to review.

### 5. Verification round

After applying all fixes from step 4, run one more review cycle to make sure the fixes didn't introduce new issues or reveal problems that were masked by the original code.

1. **Re-run Codex review** on the current uncommitted state:
   ```bash
   codex review --uncommitted
   ```
2. **Do a quick scan yourself** of the changes you just made. Look for anything the fixes might have broken or new must-fix/easy-win items that emerged.
3. **If new must-fix or easy-win items are found**, fix them. This is not an infinite loop - just one verification round. If new suggestions surface, add them to the suggestions list.
4. **If the verification round is clean**, note it in the summary ("Verification round: no new issues found").

### 6. Present suggestions and ask for direction

After auto-fixes and verification are complete, present the "Suggestions" category and ask:

> "I've auto-fixed [N] must-fix and [M] easy-win items. Verification round: [clean / fixed X additional items].
>
> The changes are uncommitted so you can review them.
>
> Here are [X] suggestions that need your input: [list suggestions]
>
> Want me to apply any of these?"

## Rules

- **Never commit during a review.** All fixes are left as uncommitted changes.
- **Never auto-fix suggestions or collateral changes.** Only must-fix and easy-win items get auto-fixed. Collateral changes are always presented for user decision (keep or revert).
- **If Codex is unavailable or fails**, proceed with the Claude-side reviews. Note that Codex was skipped in the summary.
- **If no frontend files changed**, skip the UI review entirely. Don't mention it in the summary.
- **Respect project conventions.** Check CLAUDE.md for project-specific rules and flag violations.
- **Be specific.** Every finding must reference a file path and ideally a line number. No vague "consider improving error handling" without saying where.
- **Disagree transparently.** If reviewers disagree on a finding, present both perspectives and let the user decide. Don't silently drop one opinion.
