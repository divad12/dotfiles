---
name: save
description: "Update PROGRESS.md at the project root to reflect the current session's work."
user-invocable: true
---

# Save

Update PROGRESS.md (and TECH_DEBT.md if relevant) to reflect the current session's work, then check if anything learned this session should be added to CLAUDE.md.

## Steps

### 1. Update PROGRESS.md

Read the existing PROGRESS.md at the project root. Update it **in place** (don't append per-session sections). Replace transient sections (Current State, Next Steps, Blockers) with the latest info. Accumulate entries in Decisions and Problems & Solutions.

If PROGRESS.md doesn't exist, create it with this template:

```markdown
# Project Progress

## Last Updated
[Date]

## Completed
- [x] Most recent thing
- [x] Previous thing

## Current State
What's working, what's broken, where we left off.

## Next Steps
1. Immediate next task
2. Following tasks

## Blockers / Open Questions
Anything unresolved.

## Key Files
Files Claude should read first to understand the project.
- `path/to/important/file` - why it matters

## Decisions
Cumulative log of architecture and design choices.
- [Date] Decision description and rationale

## Problems & Solutions
Cumulative log of non-obvious problems and how they were solved.
- [Date] **Problem**: description. **Fix**: what resolved it.
```

#### PROGRESS.md housekeeping
- If a decision is reversed, update or remove the old entry
- Remove Problems & Solutions entries that are no longer relevant (e.g. the tech was replaced)

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

### 3. Check for CLAUDE.md learnings

**Self-check:** Did this session produce any of the following?

- A new convention or pattern that future sessions should follow
- An architectural decision with rationale that would prevent re-debating
- A "we tried X and it didn't work" insight that would prevent re-attempting
- A new validation rule, UX standard, or integration pattern
- A workflow improvement or tool usage pattern

If **yes**, use `AskUserQuestion` to suggest the update:

```
Save complete. PROGRESS.md updated.

I noticed something this session that might be worth adding to CLAUDE.md:

[Specific suggestion - what to add and where in CLAUDE.md it belongs]

Want me to update CLAUDE.md with this?
```

Options: "Yes, update CLAUDE.md", "No, skip it"

If the user approves, run the `/claude-md-management:revise-claude-md` skill to make the change.

If **no** learnings are worth adding, skip this step silently. Most sessions won't have CLAUDE.md-worthy insights. Don't force it.

## Rules

- **Don't pad PROGRESS.md with filler.** Only record meaningful progress, decisions, and problems. If you did one small fix, the update should be one line.
- **Convert relative dates to absolute dates.** "Yesterday" or "Thursday" becomes "2026-03-19" or "2026-03-20".
- **Be concise in Decisions and Problems & Solutions.** One line per entry. The detail lives in the code and commit messages.
- **The CLAUDE.md check should be lightweight.** Spend 5 seconds thinking, not 5 minutes analyzing. If nothing jumps out, move on.
