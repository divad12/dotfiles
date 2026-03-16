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
Critique loop (UI/UX, uses sonnet) - what's good, what could be better
    ↓
Quick self-review (correctness, types, conventions)
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
- **No automatic deep-review.** A quick self-review (inline + Codex) catches the obvious stuff. Full `/deep-review` (5-way parallel) only runs when the user explicitly asks for it.
- **Present early.** Show the user the result after critique, not after a full review cycle. If the direction is wrong, you've saved an entire deep-review's worth of tokens.
- **Light iterations.** Feedback rounds don't re-run reviews. Just implement, screenshot, confirm.

## Steps

### 1. Set up the workspace

Run the `/new-session` skill to set up the worktree, env files, symlinked node_modules, and a unique port.

### 2. Understand the task

Read the task description. Before writing any code:

- **Check for embedded skill references.** If the task description mentions another skill (e.g. `/spec-interview`, `/frontend-design`), read that skill's SKILL.md file and follow its process inline as a pre-step before implementing. For example, `/build /spec-interview draggable pinned times` means: read the spec-interview skill, follow its interview/spec process to clarify requirements, then implement the result. Note: skills can't invoke other skills via the Skill tool, so read the file directly and execute the steps yourself.
- Read CLAUDE.md and PROGRESS.md for project context and conventions
- Identify which parts of the codebase are relevant (explore files, read existing patterns)
- Figure out if there are critical tradeoffs or ambiguities

**Decision principle:** If a tradeoff is easily reversible (UI layout choice, naming, minor architecture), just make your best call and note it. If a tradeoff is hard to reverse (database schema change, new dependency, auth model change), ask the user before proceeding. The bar for asking should be high. Most things are reversible.

### 2b. Clarify (only if needed)

After understanding the task, if there are genuinely ambiguous questions where the answer would meaningfully change your implementation, use `AskUserQuestion` to ask them before building. This is NOT a requirements interview. The bar is high:

**Ask when:**
- The task description is ambiguous in a way that leads to two very different implementations
- A hard-to-reverse decision (schema, new dependency) depends on user intent that isn't clear
- The scope is unclear enough that you might build the wrong thing entirely

**Don't ask when:**
- You can make a reasonable guess and note the decision (most cases)
- The question is about a reversible choice (layout, naming, styling)
- You'd be asking just to feel thorough. Bias toward action.

If you do ask, keep it to 2-3 focused questions max. Bundle them in a single `AskUserQuestion` prompt. Include what you'd do by default if they don't answer, so they can just say "go with your defaults" and you proceed immediately.

Most tasks won't need this step. Skip it and go straight to implementing.

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

If the task has frontend changes, run the `/critique` skill. It handles screenshots, evaluation, fixes, and multi-round iteration. Use `model: "sonnet"` for critique subagents to save cost - visual assessment doesn't need opus-level reasoning.

Include the critique summary (what was acted on, skipped, and could still improve) in the build report.

### 5. Quick review

Run two things in parallel:

**Inline checks** (yourself):
- Type errors (`npx tsc --noEmit`)
- Lint (`npm run lint`)
- Obvious bugs, missing error handling, security issues
- Convention violations from CLAUDE.md

**Codex review** (background, cheap):
```bash
codex review --uncommitted
```

Fix anything either finds. Codex is a separate API and costs very little, but catches things you might miss since it reviews with fresh eyes and no shared context from the implementation.

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

Then **always** use `AskUserQuestion` to prompt for next steps. This triggers the blue dot so the user knows this session needs attention. Present options that make sense for the current state, with your recommended next step first (append "(Recommended)" to its label):

Options to choose from (include the ones that make sense):
- **Run UI critique** - "Run another round of UI/UX critique and polish"
- **Review** - "Quick review: inline checks + Codex"
- **Deep review** - "Full 5-way deep review (collateral, code, simplify, Codex, UI)"
- **Ship** - "Commit and merge to main, keep session open"
- **Done** - "Ship + close session (commit, merge, tear down worktree)"
- **Give feedback** - "I have specific changes I want" (always include this as the last option)

For the initial presentation after building, recommend "Give feedback" or "Review" depending on complexity. After the user has already iterated and seems happy, recommend "Ship" or "Done".

### 7. Feedback loop

Based on the user's selection:

- **Give feedback** (or they type free text) - implement the feedback, then do a quick visual sanity check (screenshot the affected area, confirm the fix looks right, check nothing nearby broke). This is NOT a full `/critique` - just a fast inline screenshot + eyeball. After implementing, always re-prompt with `AskUserQuestion` again. Every prompt must include:
  1. The localhost URL (so they can click straight to it)
  2. A brief summary of what just changed and what to test now
  3. The next-step options

- **Run UI critique** - run the full `/critique` skill (all 7 sections, multi-round). This is the expensive visual review. Only when explicitly selected, re-prompt after.

- **Review** - run Codex review + inline checks, fix findings, re-prompt.

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

**Always include in the prompt text (before the options):**
- The localhost URL
- What was just done / changed
- What to test now

**Also use `AskUserQuestion` in step 2** if you hit a hard-to-reverse tradeoff and need a decision before proceeding.

## Rules

- **Bias toward action.** Don't ask for permission on reversible decisions. Build something, show it, iterate from feedback.
- **Note every decision.** The user wasn't watching you work, so they need to understand what tradeoffs you made and why. The decisions list is how they catch anything they'd do differently.
- **Always provide a test URL.** The whole point is the user can click and see it immediately.
- **Don't over-iterate autonomously.** The critique loop is about getting to "good first pass" quality. The user's feedback is what takes it to "exactly what I want".
- **Keep the dev server running.** The user needs it to test. Don't stop it until close-session.
- **Deep review is opt-in.** Never run `/deep-review` unless the user asks for it. The quick review (inline + Codex) in step 5 is the default.
