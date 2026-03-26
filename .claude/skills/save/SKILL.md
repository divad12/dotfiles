---
name: save
description: "Save session progress: update PROGRESS.md coordination board, route learnings to docs, update TECH_DEBT.md."
user-invocable: true
---

# Save

Update PROGRESS.md as a coordination board, route any learnings to the right documentation, and update TECH_DEBT.md if relevant.

## Steps

### 1. Update PROGRESS.md

PROGRESS.md is a **coordination board** for tracking work across agents, sessions, and worktrees. It answers: what's being worked on, what's next, and what's done recently.

Read the existing PROGRESS.md. Update it in place following this format:

```markdown
# Progress

## Last Updated
[Date]

## Current State
One-liner about where things are overall.

## In Progress
- [ ] [worktree: branch-name] Task description (spec: docs/specs/foo.md)
- [ ] [worktree: other-branch] Another task

## Up Next
- [ ] Next task to pick up
- [ ] Another upcoming task

## Recently Done
- [x] Completed task (spec: docs/specs/bar.md)
- [x] Another completed task

## Blockers
None.
```

#### Update rules
- **Check off** items you completed this session (move from In Progress to Recently Done)
- **Add** your current worktree to In Progress if not already listed
- **Add** any new tasks discovered during the session to Up Next
- **Remove** your worktree from In Progress when done
- **Tag worktree name** on In Progress items so other sessions see what's being worked on
- **Link specs** where they exist (`docs/specs/foo.md`)
- **Cap Recently Done at ~7 items.** When it gets longer, remove the oldest. The spec file + git log have the permanent record.
- **Keep the whole file under 30 lines.** This is loaded at session start - every line costs instruction budget.

#### What does NOT go in PROGRESS.md
- Architecture decisions (those go in `docs/ai/` files)
- Problems & solutions (non-obvious ones belong as "why" comments in the code; git history is the backstop)
- Key files (those are in `docs/ai/README.md` or the relevant doc)
- Implementation details (those are in the code)
- Verbose descriptions of completed work (one line per item is enough)

### 2. Update TECH_DEBT.md (if relevant)

If this session introduced, resolved, or affected any tracked debt, update TECH_DEBT.md:
- **Delete** items that were fixed entirely (don't leave them crossed out)
- **Add** new items that were deferred (code smells, shortcuts, deliberate trade-offs)
- **Update** items whose scope or priority changed
- If an item turns out to be a non-issue, delete it with a brief note in the commit message

If nothing changed, skip this step.

#### TECH_DEBT.md format

Organize by priority:
- **P1** - Fix before current milestone ships (security, data integrity, broken UX)
- **P2** - Fix before next milestone (scaling issues, architectural debt)
- **P3** - Nice to have (optimization, polish)

Each entry should have: **Where** (file path + line if relevant), **Issue** (what's wrong), **Fix** (how to resolve).

#### When to add entries (not just at save time)
- When you notice a code smell or shortcut during implementation but it's not worth fixing in the current scope
- When a code review (human or AI) flags an issue that's deferred
- When you make a deliberate trade-off (e.g. "this works for M1 but won't scale")

#### When to consult TECH_DEBT.md
- **Before starting a new feature** - check if any P1 items affect the area you're working in
- **Before each milestone ships** - review all P1 items and resolve them
- **During refactoring passes** - work through P2/P3 items

### 3. Capture learnings in documentation

**Goal: never fix the same thing twice.** Every bug fix, gotcha, pattern discovery, or "oh that's how this works" moment should be captured so future sessions don't repeat the work. The adaptive docs system (docs/ai/) ensures learnings only load when relevant, so there's no cost to capturing aggressively.

**Review the session and capture:**

- Bug fixes: what went wrong, why, and the fix - as a "why" comment in the code AND as a pattern/gotcha in the relevant docs/ai/ file
- Conventions discovered or established
- Architecture decisions with rationale
- "We tried X and it didn't work" insights
- Validation rules, edge cases, or integration patterns
- Workflow improvements or tool usage patterns

**Where each learning goes:**

- **Code comments** - Non-obvious fixes get a "why" comment right next to the code. This is the primary home for problem-solution knowledge.
- **`docs/ai/` files** - Patterns, conventions, and gotchas that apply to a topic area. Route to the specific file (e.g., testing gotcha → `docs/ai/testing.md`, form pattern → `docs/ai/form-guidelines.md`).
- **Root `CLAUDE.md`** - Only if it applies to ALL tasks regardless of context (hard rules, writing style, commands). Very rare.
- **Nested `AGENTS.md`** - Only if it's a new non-negotiable guardrail for a specific source directory. Also rare.

**Present findings to the user:**

```
Save complete. PROGRESS.md updated.

Learnings from this session to capture:

1. [docs/ai/testing.md] Added: when mocking Prisma, must also mock the $transaction method (hit this debugging the cascade test)
2. [src/lib/timing/recalculate.ts:45] Added code comment: midnight crossover check needed because naive subtraction wraps negative

Want me to apply these?
```

Options: "Yes, update the docs", "No, skip it"

If the user approves and the target is CLAUDE.md, run the `/claude-md-management:revise-claude-md` skill. Otherwise, edit the target files directly.

If the session was genuinely trivial (one-line typo fix, config change) with nothing to capture, skip this step.

### 4. Check skill trigger coverage (if docs/ai/ exists)

If the project has a `docs/ai/` directory and `.claude/skills/` (or `.agents/skills/`), quickly check: did this session create any new directories or file patterns that aren't covered by existing skill descriptions? If so, note it in the save output so the user can decide whether to update skill triggers.

## Rules

- **PROGRESS.md is a coordination board, not a history log.** Keep under 30 lines. Cap Recently Done at ~7 items.
- **Convert relative dates to absolute dates.** "Yesterday" or "Thursday" becomes "2026-03-19" or "2026-03-20".
- **Capture aggressively, route precisely.** Every fix and discovery is worth documenting. The adaptive docs system ensures it only loads when relevant - no instruction budget cost.
- **Tag worktree names.** Other sessions need to see what's being worked on where.
- **Code comments are the primary home for problem-solution knowledge.** Docs/ai/ files capture patterns and conventions. Both should be updated.
