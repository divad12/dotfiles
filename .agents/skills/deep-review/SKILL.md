---
name: deep-review
description: "Use when the user says 'deep review', 'thorough review', 'full review', 'triple review', or 'ultra review'."
user-invocable: true
---

# Deep Review

Run multiple independent review passes in parallel, consolidate findings, auto-fix what's safe, verify the fixes, and present the rest for user decision.

The value of multi-agent review is that each reviewer has a different perspective and catches different things. An independent reviewer from the other agent family doesn't share the blind spots of the agent that wrote the code. A UI reviewer catches usability issues that a code-focused review misses. Running them in parallel costs no extra wall-clock time.

## Overview

This skill orchestrates a comprehensive review by combining up to six perspectives:

1. **Collateral change audit** - flag changes to existing behavior that aren't required by the feature
2. **Orchestrator review** - diff analysis, correctness, conventions, code quality
3. **Rule compliance audit** - re-read project rules (CLAUDE.md, docs/ai/) with fresh eyes and systematically verify the diff obeys them. This catches shortcuts the coding agent took under context pressure.
4. **Simplify pass** - code reuse opportunities, unnecessary complexity, efficiency, dead code
5. **Independent cross-agent review** - fresh eyes from the other agent family (no shared context with the coding agent)
6. **UI review** - usability, accessibility, and design quality (only when frontend files are changed)

After all reviews complete, findings are consolidated, deduplicated, and categorized for action.

## Steps

### 1. Determine the review scope

Figure out what to review based on the current state:

```bash
# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')

# Check how many commits ahead of local main
AHEAD=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
```

- If there are uncommitted changes, review those (the common case during development).
- If working tree is clean but the branch has commits ahead of local main, review the branch diff against main.
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

#### Review 1: Orchestrator's own review (run inline)

Analyze the diff yourself. Focus on:

- **Correctness** - logic errors, edge cases, off-by-one, null handling, race conditions
- **Type safety** - type errors, unsafe casts, missing types
- **Security** - input validation, auth checks, exposed secrets, XSS/injection
- **Conventions** - naming, file structure, patterns established in CLAUDE.md
- **Data integrity** - schema alignment, missing validations, cascade issues

Use `git diff` (for uncommitted) or `git diff main...HEAD` (for branch) to read the actual changes.

#### Review 1.5: Rule compliance audit (run inline, CRITICAL)

**Why this exists:** The agent that wrote the code and the agent reviewing it share the same context window. Rules read at session start fade as context fills. This review step re-reads project rules with fresh eyes and systematically checks the diff against them.

**Step 1: Re-read the project rules.** Read CLAUDE.md (or AGENTS.md) and any docs it references that are relevant to the changed files. Don't rely on what you "remember" from earlier in the session - actually re-read them now. If the project has a reference table mapping topics to docs (e.g. "forms -> docs/ai/form-guidelines.md"), read the docs that match the changed file types.

**Step 2: For each rule, grep the diff for violations.** Common patterns to check (adapt to the project's specific rules):

```bash
# Hardcoded values that should come from config or data
git diff main...HEAD -- ':!*.test.*' | grep -n '= ""' | grep -v 'class\|placeholder\|useState'
git diff main...HEAD -- ':!*.test.*' | grep -n 'fetch(' | grep -v 'test\|spec\|mock'

# Duplication - new files that mirror existing ones
git diff main...HEAD --name-only --diff-filter=A  # newly added files
# For each new file: does an existing file already handle this?

# Data fields added to types but not wired through the full chain
git diff main...HEAD | grep -A2 'interface\|type.*='  # new fields in types
# For each new field: is it in the DB select? In all callers?
```

**Step 3: Check architectural rules.** For each changed file, verify:
- If it's a component: does it use project hooks (not raw fetch, not prop-drilled config)?
- If it's a form: does it follow the form guidelines (dirty tracking, inline errors, optimistic close)?
- If it adds a new field: does the field flow from DB select -> type -> every rendering surface?
- If it duplicates logic: is there already a shared function for this?

Rule violations found here are **Must Fix**, not suggestions. They represent the exact class of bug that the coding agent is blind to because of context pressure.

#### Review 2: Simplify pass (invoke /simplify skill)

Invoke the `/simplify` skill via the Skill tool. It has its own tuned logic for finding code reuse, unnecessary complexity, dead code, efficiency issues, and API surface bloat. Do NOT replicate its logic inline - the skill is better at it.

The skill operates on recently changed code by default, which matches the deep-review scope.

### 2.5. Detect the invoking agent

Before dispatching Review 3, identify the current orchestrator:

- If the current orchestrator is Codex, the independent reviewer is Claude Code.
- If the current orchestrator is Claude Code, the independent reviewer is Codex.
- If the current orchestrator is neither, prefer Codex if available, then Claude Code. Record the fallback in the summary.

This is intentionally based on the agent running the skill, not on which agent wrote the diff. The goal is to force a second review engine with different defaults, tool behavior, and blind spots.

#### Review 3: Independent cross-agent review (run as background task)

Launch the independent reviewer in the background while you do reviews 1 and 2. Use the agent's background execution mechanism so it runs concurrently with your own analysis. **Set `timeout: 300000`** (5 minutes) - independent reviews can take longer than the default 2 minutes on large diffs.

#### When the independent reviewer is Codex

Launch Codex in the background while you do reviews 1 and 2:

```bash
# For uncommitted changes:
codex review --uncommitted

# For branch changes:
codex review --base main
```

**Important: `--base` takes a BRANCH name, NOT a SHA.** If your scope is a SHA range (e.g. `<phase-base>^..<phase-head>` from /fly's phase-gate deep-review), create a temp branch at the base SHA first - DO NOT skip codex.

```bash
git branch -f /tmp/codex-base <phase-base>^
codex review --base /tmp/codex-base
git branch -D /tmp/codex-base   # cleanup after dispatch
```

#### When the independent reviewer is Claude Code

Run Claude Code in non-interactive print mode and feed it the exact review diff. Keep staged and unstaged changes separate so it can catch index-only mistakes and unstaged follow-up edits.

```bash
# For uncommitted changes:
git diff --cached > /tmp/deep-review-staged.patch
git diff > /tmp/deep-review-unstaged.patch
{
  printf '%s\n' 'You are the independent reviewer for /deep-review.'
  printf '%s\n' 'Review only. Do not modify files. Report correctness, safety, tests, maintainability, and rule-compliance findings with file:line references.'
  printf '%s\n' 'STAGED DIFF:'
  cat /tmp/deep-review-staged.patch
  printf '%s\n' 'UNSTAGED DIFF:'
  cat /tmp/deep-review-unstaged.patch
} | claude -p

# For branch changes:
{
  printf '%s\n' 'You are the independent reviewer for /deep-review.'
  printf '%s\n' 'Review only. Do not modify files. Report correctness, safety, tests, maintainability, and rule-compliance findings with file:line references.'
  git diff main...HEAD
} | claude -p
```

If your scope is a SHA range (e.g. `<phase-base>^..<phase-head>` from /fly's phase-gate deep-review), feed that exact diff to Claude Code:

```bash
{
  printf '%s\n' 'You are the independent reviewer for /deep-review.'
  printf '%s\n' 'Review only. Do not modify files. Report correctness, safety, tests, maintainability, and rule-compliance findings with file:line references.'
  git diff <phase-base>^..<phase-head>
} | claude -p
```

The independent reviewer perspective is load-bearing for deep-review; skipping it loses one of the six sub-reviewers and degrades the review.

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

This is better than delegating UI review to the independent code reviewer because the UI subagent has direct access to the codebase, can render and interact with the actual UI, and catch behavioral issues that code-only review misses.

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

   **Fix these too** (auto-fix, but note them in the summary)
   - **Fragile code** - brittle logic, hardcoded values, implicit dependencies that will break on the next change
   - **Duplication** - same logic in two places, copy-pasted code, functions that compute the same thing differently
   - Performance optimizations with clear, low-risk fixes
   - Better naming, clearer interfaces
   - Minor UX/UI improvements that are straightforward
   - Anything a reviewer suggested that has an obvious, quick fix

   **Defer** (present for user decision - do NOT auto-fix)
   - Only defer if fixing it would take longer than the entire rest of the review combined
   - "Big effort" means genuinely big (new tables, new API endpoints, multi-file architecture change) - not "more than 5 lines"
   - When in doubt, fix it. Err heavily toward fixing.

3. **Present the consolidated review** in this format:

   ```
   ## Deep Review Summary

   Reviewed by: <orchestrator> (diff + simplify + collateral audit), <independent reviewer>[, UI review]
   Scope: [uncommitted changes / branch diff against main]
   Files changed: [count] ([N] frontend)

   ### Collateral Changes (for your decision)
   - [ ] file:line - what changed and why it's unrelated to the feature

   ### Must Fix (auto-fixing)
   - [ ] Issue description - file:line - what's wrong and how it's being fixed

   ### Easy Wins (auto-fixing)
   - [ ] Issue description - file:line - what's wrong and how it's being fixed

   ### Also Fixing (reviewer suggestions, straightforward)
   - [ ] Issue description - file:line - what's being improved

   ### Deferred (big-effort, out of scope, or debatable)

   For each deferred item, use this format - plain English, no jargon, framed in product/user terms:

   - [ ] **<plain-English title>**
     - **What's happening:** <2-3 sentences describing the issue in user/product terms. Avoid "type", "cast", "interface", "ref" unless it's the only honest framing - prefer "when a user does X, the app does Y instead of Z". Translate file:line citations into "the X feature does Y when Z".>
     - **User-facing impact:** <one sentence: what does the user actually see, feel, lose, or risk if this stays unfixed? Examples: "Users on slow connections see a flash of empty state before content loads", "If two people edit the same form at once, one set of changes silently overwrites the other", "Nothing visible today, but every new field added has to be manually wired in 4 places - one will get missed and that field will silently not save". If there's truly no user-visible impact, say so explicitly: "No user-facing impact - this is purely about <code maintainability / future-proofing>" - don't pad.>
     - **Why I'm not fixing it now:** <one short sentence: needs your decision / phase-sized work / risky-and-debatable>
     - **Where:** file:line
   ```

   **Why this format matters:** without the user-facing impact line, deferred items read as engineering todos and the user has no way to weigh them against other work. With it, they read as product decisions, which is the framing needed to actually decide. If you cannot articulate a user-facing impact (even "no user-facing impact - purely internal"), you do not understand the finding well enough to defer it - re-read the reviewer's notes.

### 3.5. Architecture drift auto-sync

Before applying other fixes, check and update the architecture diagram if drift exists.

If `docs/ai/architecture.md` exists and has a `## This diagram covers` section:

1. Parse the coverage paths
2. Check if the review diff includes structural changes (`A`/`D`/`R` file statuses) under those paths
3. Check whether `docs/ai/architecture.md` itself was already modified in this diff
4. If structural changes exist AND architecture.md wasn't already updated: **invoke `/sync-architecture`**. It edits the diagram directly (no approval gate) and leaves the update unstaged.

Note the architecture update in your consolidated summary as "Architecture diagram auto-synced (N structural changes)" so the user can spot it when reviewing the auto-fixes.

Skip this step silently if there's no `docs/ai/architecture.md`, no coverage section, or no structural changes.

### 4. Auto-fix everything except deferred items

Apply fixes for all items in "Must fix", "Easy wins", and "Fix these too":

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

1. **Re-run the same independent reviewer** on the current uncommitted state:
   ```bash
   # If the independent reviewer is Codex:
   codex review --uncommitted

   # If the independent reviewer is Claude Code:
   git diff --cached > /tmp/deep-review-staged.patch
   git diff > /tmp/deep-review-unstaged.patch
   {
     printf '%s\n' 'You are the independent reviewer for the /deep-review verification round.'
     printf '%s\n' 'Review only. Do not modify files. Report only new issues introduced by the fixes.'
     printf '%s\n' 'STAGED DIFF:'
     cat /tmp/deep-review-staged.patch
     printf '%s\n' 'UNSTAGED DIFF:'
     cat /tmp/deep-review-unstaged.patch
   } | claude -p
   ```
   Use `timeout: 300000` (5 minutes) as in step 2.
2. **Do a quick scan yourself** of the changes you just made. Look for anything the fixes might have broken or new must-fix/easy-win items that emerged.
3. **If new must-fix or easy-win items are found**, fix them. This is not an infinite loop - just one verification round. If new suggestions surface, add them to the suggestions list.
4. **If the verification round is clean**, note it in the summary ("Verification round: no new issues found").

### 6. Present deferred items and ask for direction

After auto-fixes and verification are complete, present only the deferred items. **Use the exact same plain-English / user-facing-impact format from step 3** - do not abbreviate to a one-liner here. The user is being asked to make a decision; they need the same context the consolidated review had.

> "I've auto-fixed [N] items across must-fix, easy-wins, and reviewer suggestions. Verification round: [clean / fixed X additional items].
>
> The changes are uncommitted so you can review them.
>
> [If deferred items exist:]
> These [X] items I left alone - they need your call. Each is described in plain English with the user-facing impact, so you can weigh them without digging into the code:
>
> [for each deferred item, render the full block:]
>
> **<plain-English title>**
> - **What's happening:** <2-3 sentences in user/product terms>
> - **User-facing impact:** <one sentence: what the user sees / risks / loses, or "No user-facing impact - purely internal">
> - **Why I'm not fixing it now:** <one short sentence>
> - **Where:** file:line
>
> Want me to tackle any of these?"

**Anti-pattern:** "Issue: unsafe cast at form.tsx:42 - deferred because it needs a refactor." This is the engineering framing the user just told you not to use. The right framing: "When users edit forms with custom field overrides, the app could crash on save because we're not validating the override shape. User-facing impact: rare today (only one form uses overrides), but if we add more, the crash surface grows silently. Not fixing now: needs a small schema refactor that touches the form types in 3 places. Where: form.tsx:42."

## Rules

- **Never commit during a review.** All fixes are left as uncommitted changes.
- **Fix everything. Always.** Fix every finding from every reviewer - simplify pass, independent reviewer, UI review, all of it. The only exception is genuinely massive work (new tables, new endpoints, multi-file architecture changes). "Out of scope" and "debatable" are not reasons to skip a fix. When in doubt, fix it. Collateral changes are always presented for user decision (keep or revert).
- **If the independent reviewer is unavailable or fails**, proceed with the orchestrator-side reviews. Note which independent reviewer was skipped in the summary.
- **If no frontend files changed**, skip the UI review entirely. Don't mention it in the summary.
- **Respect project conventions.** Check CLAUDE.md for project-specific rules and flag violations.
- **Be specific.** Every finding must reference a file path and ideally a line number. No vague "consider improving error handling" without saying where.
- **Disagree transparently.** If reviewers disagree on a finding, present both perspectives and let the user decide. Don't silently drop one opinion.
