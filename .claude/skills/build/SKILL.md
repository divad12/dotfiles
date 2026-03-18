---
name: build
description: "Autonomously build a feature from a single task description. Sets up the worktree, implements, critiques UI/UX, and presents the result with a test URL. User-driven review and iteration. Use when the user says 'build [something]', 'make [something]', 'implement [something]', or gives a feature description and wants it built end-to-end."
user-invocable: true
---

# Build

Take a single task description, build it autonomously, then present the result for the user to test and iterate on. The goal is to deliver a working feature with one command, so the user can open multiple sessions in parallel, each building something different, and come back to review them.

## The flow

```
/build [task description]
    ↓
Set up worktree (via /new-session)
    ↓
Understand → Clarify (if needed) → Plan → Implement
    ↓
Critique loop (Playwright MCP: click, type, test real flows)
    ↓
Compile check (tsc + lint, ~5 seconds)
    ↓
Present: URL + summary + decisions + improvements
    ↓
User tests and gives feedback → iterate
    ↓
User says "review" → /deep-review (only when asked)
    ↓
User says "done" → /ship → /close-session
```

## Cost-conscious design

This skill is meant to run many times in parallel. Every step should justify its token cost.

- **Critique loop**: Use `model: "sonnet"` for subagents. Visual assessment doesn't need opus-level reasoning.
- **No automatic review before presenting.** Just tsc + lint (~5 seconds). Codex review, deep review, QA test are all opt-in from the feedback loop. Present early so the user can redirect if the direction is wrong.
- **Thorough feedback verification.** After every feedback change, compile-check + click through the change with Playwright MCP + check blast radius on nearby pages. The user should never have to report the same issue twice.
- **Light iterations.** Feedback rounds don't re-run full critique. Just implement, verify interactively, re-prompt.

## Steps

### 1. Set up the workspace

Run the `/new-session` skill to set up the worktree, env files, symlinked node_modules, and a unique port. **Remember the assigned port number** - you must use it for the dev server, all localhost URLs, and every `AskUserQuestion` prompt throughout the entire session.

### 2. Understand the task

Read the task description. Before writing any code:

- **Check for embedded skill references.** If the task description mentions `/spec-interview`, run the spec interview process (below) before implementing. If it mentions another skill (e.g. `/frontend-design`), read that skill's SKILL.md and follow its process inline. Note: skills can't invoke other skills via the Skill tool, so read the file directly and execute the steps yourself.

  **Spec interview process** (when `/spec-interview` is in the task description):
  Use `AskUserQuestion` to interview the user about the feature. Start with hard questions (UI/UX decisions, edge cases, error states, tradeoffs). Cover: core user flow, data model changes, API surface, component hierarchy, loading/empty/error states, integration with existing features, and what's out of scope. Each round: 1-4 focused questions, option-based when alternatives are clear. Keep going until no ambiguity remains. Then write `SPEC.md` at project root (Overview, User Flow, UI Design, Data Model, API, Edge Cases, Out of Scope, Open Questions) and display it for review before implementing.
- Read CLAUDE.md and PROGRESS.md for project context and conventions
- Identify which parts of the codebase are relevant (explore files, read existing patterns)
- Figure out if there are critical tradeoffs or ambiguities

**Decision principle:** If a tradeoff is easily reversible (UI layout choice, naming, minor architecture), just make your best call and note it. If a tradeoff is hard to reverse (database schema change, new dependency, auth model change), ask the user before proceeding. The bar for asking should be high. Most things are reversible.

### 2b. Clarify (only if needed)

After understanding the task, if you have useful questions that would help you build a better first pass, use `AskUserQuestion` to ask them before building. Keep it to 2-3 focused questions max, bundled in a single prompt. Include what you'd do by default for each question, so the user can just say "go with your defaults" and you proceed immediately.

Skip this step if the task is clear enough to just start building.

### 3. Implement

Build the feature. Follow project conventions from CLAUDE.md. This means:

- Read relevant existing code first to understand patterns
- Follow established file structure, naming, and styling conventions
- Add loading.tsx for new pages
- Run the type checker after implementation to catch errors early:
  ```bash
  npx tsc --noEmit 2>&1 | tail -30
  ```

Start the dev server after implementation:
```bash
npm run dev -- --port <PORT> &
```

### 4. Critique loop (UI/UX focused)

If the task has frontend changes, run the `/critique` skill. It uses **Playwright MCP** to actually click through the UI, fill forms, test interactions - not just take screenshots. Use `model: "sonnet"` for critique subagents to save cost.

Include the critique summary (what was acted on, skipped, and could still improve) in the build report.

### 5. Compile check

Run a quick compile check before presenting. This is fast (~5 seconds) and catches obvious breakage:

```bash
npx tsc --noEmit 2>&1 | tail -30
npm run lint 2>&1 | tail -20
```

Fix any type errors or lint failures. Do NOT run Codex or other reviews here - that delays presenting. Reviews are available as opt-in options in the feedback loop.

### 6. Present and prompt

This is the key moment. First, output a text summary with everything the user needs:

```
## Build Complete

### What I built
[1-3 sentence summary of the feature]

### Test it
URL: http://localhost:<PORT>/[relevant-path]

### How to test
- [Step-by-step testing guide]
- [Key pages/flows to try]
- [Edge cases worth poking at]

### Decisions I made
- [Decision]: [why I chose this over alternatives]
- [Decision]: [tradeoff and reasoning]

### Critique log
- Acted on: [list of UI/UX improvements made]
- Skipped: [list of things left as-is and why]

### Could still be improved
- [Things that aren't worth doing autonomously but might be worth doing manually]
- [Polish opportunities, alternative approaches considered]
```

Then **always** use `AskUserQuestion` to prompt for next steps. This triggers the blue dot so the user knows this session needs attention.

**Critical: the `AskUserQuestion` dialog covers the conversation text behind it.** The user may not be able to read the text summary above. So the prompt text inside `AskUserQuestion` must be self-contained. Include:
- The **test URL** (so they can click it directly from the dialog)
- A **brief summary** of what was built and key decisions
- What to test

Example prompt text:
```
Build complete. Test at http://localhost:3001/events/123/guests

What I built: Guest assignment UI with drag-and-drop between legs, bulk import from CSV, and inline editing. Decisions: used dnd-kit for drag (already in deps), CSV parsing with papaparse (new dep).

Key things to test: drag guests between legs, import a CSV, edit a guest inline, try with empty state.
```

Present options that make sense for the current state. Track internally whether a review has been run (the quick review in step 5 counts, or any user-requested review/deep-review).

**HARD RULE: Never include "Ship" or "Done" as options until at least one review has been run.** Before any review, the options should be review-oriented. After a review passes, Ship/Done can appear.

**Before any review has run** - use these options (pick 3-4 that fit):
- **Give feedback** - "I have specific changes or concerns"
- **Review (Recommended)** - "Codex code review + inline checks (tsc, lint, conventions)"
- **Deep review** - "Full 5-way deep review (collateral, code, simplify, Codex, UI)"
- **Run UI critique** - "Run another round of UI/UX critique and polish"
- **Codex UI review** - "Get Codex's take on the UI/UX (cheap, fresh eyes)"
- **QA test** - "Browser-only tester clicks through all flows (for complex multi-step features)"

**After at least one review has passed** - use these options (pick 3-4 that fit):
- **Ship (Recommended)** - "Commit and merge to main, keep session open"
- **Done** - "Ship + close session (commit, merge, tear down worktree)"
- **Give feedback** - "I have specific changes or concerns"
- **Deep review** - "Full 5-way deep review (collateral, code, simplify, Codex, UI)"
- **QA test** - "Browser-only tester clicks through all flows"

### 7. Feedback loop

Based on the user's selection:

- **Give feedback** (or they type free text) - implement the feedback, then **verify it actually works** using Playwright MCP. This is the most important step and the one most likely to go wrong. Don't just make the code change and hope.

  **Verification checklist (do all of these):**
  1. **Run tsc** - does it still compile? Fix if not.
  2. **Navigate to the page** with `browser_navigate` and take a snapshot.
  3. **Click through the specific change** - if you changed a form, fill it out and submit it. If you changed a button, click it. If you changed a list, add/edit/delete items. Verify the result with a snapshot after each interaction.
  4. **Check the blast radius** - did the change break anything nearby? Navigate to related pages or components that share code with what you changed. Take snapshots. If the feedback was "change how groups display", also check the event detail page, the designer, anywhere groups appear.
  5. **Check the console** for new errors.

  If anything fails in verification, fix it before re-prompting. The user should never have to report the same issue twice.

  After verifying, re-prompt with `AskUserQuestion`. The prompt must be self-contained (URL, what changed, what you verified, what to test) since the dialog covers the conversation behind it.

- **Run UI critique** - run the full `/critique` skill (all 7 sections, multi-round). This is the expensive visual review. Only when explicitly selected, re-prompt after.

- **Codex UI review** - run Codex with UI/UX-focused prompt (same as the one in step 5). Cheap and fast. Fix what it finds, re-prompt.

- **Review** - run `codex review --uncommitted` in background + your own inline checks (tsc, lint, correctness, convention violations from CLAUDE.md). Fix findings, re-prompt.

- **QA test** - run the `/qa-test` skill. Read its SKILL.md and follow the process inline. Fix any FAILs, include CONCERNs in the re-prompt. Re-prompt after.

- **Deep review** - run the full `/deep-review` skill, fix must-fix and easy-wins, re-prompt with the suggestions list.

- **Ship** - run the `/ship` skill. Re-prompt with just "Done" and "Give feedback" options.

- **Done** - proceed to step 8.

### 8. Ship and close

When the user selects "Done":

1. Run the `/ship` skill (save progress, commit, merge to main) if not already shipped
2. Run the `/close-session` skill (stop server, save session context, remove worktree and branch)

The session is over.

## Notifications

Every time you finish a chunk of work (initial build, feedback iteration, review fixes), use `AskUserQuestion` to hand control back to the user. This is the primary notification mechanism - it triggers the blue dot in Claude Code's session list.

**The dialog covers the conversation behind it.** The user can't easily read your text output while the dialog is open. So the `AskUserQuestion` prompt must be **self-contained** - include the URL, a summary of what changed, and what to test. Don't rely on text you output before the dialog.

**Also use `AskUserQuestion` in step 2b** if you have useful clarifying questions before implementing.

## Rules

- **Bias toward action.** Don't ask for permission on reversible decisions. Build something, show it, iterate from feedback.
- **Note every decision.** The user wasn't watching you work, so they need to understand what tradeoffs you made and why. The decisions list is how they catch anything they'd do differently.
- **Always provide a test URL.** The whole point is the user can click and see it immediately.
- **Don't over-iterate autonomously.** The critique loop is about getting to "good first pass" quality. The user's feedback is what takes it to "exactly what I want".
- **Keep the dev server running.** The user needs it to test. Don't stop it until close-session.
- **Deep review is opt-in.** Never run `/deep-review` unless the user asks for it. The quick review (inline + Codex) in step 5 is the default.
