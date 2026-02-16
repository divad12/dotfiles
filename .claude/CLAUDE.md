
Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.

## Session Management

Maintain a PROGRESS.md file at the project root to track work across sessions.

### At the end of each session (or when asked to "save progress"):

Update PROGRESS.md with this format:
```
# Project Progress

## Last Updated
[Date/time]

## Completed
- [ ] Feature 1
- [x] Feature 2 (done)
- etc.

## Current State
What's working, what's broken, where we left off.

## Next Steps
1. Immediate next task
2. Following tasks
3. etc.

## Blockers / Open Questions
Anything unresolved.

## Recent Decisions
Any architecture or design choices made this session.
```

### When starting a new session:

Read PROGRESS.md first to understand current state before continuing work.

## Tech Debt Tracking

Maintain a `TECH_DEBT.md` file at the project root to track deferred issues, code smells, and cleanup notes.

### When to add entries:
- When you notice a code smell or shortcut during implementation but it's not worth fixing in the current scope
- When a code review (human or AI) flags an issue that's deferred
- When you make a deliberate trade-off (e.g. "this works for M1 but won't scale")

### When to consult it:
- **Before starting a new feature** — check if any P1 items affect the area you're working in
- **Before each milestone ships** — review all P1 items and resolve them
- **During refactoring passes** — work through P2/P3 items

### Format:
Organize by priority:
- **P1** — Fix before current milestone ships (security, data integrity, broken UX)
- **P2** — Fix before next milestone (scaling issues, architectural debt)
- **P3** — Nice to have (optimization, polish)

Each entry should have: **Where** (file path + line if relevant), **Issue** (what's wrong), **Fix** (how to resolve).

### Housekeeping:
- When you fix an item, delete it from TECH_DEBT.md entirely (don't leave it crossed out)
- If an item turns out to be a non-issue, delete it with a brief note in the commit message

## Commit Hygiene

When committing changes, always:
1. Update PROGRESS.md to reflect what was done
2. Update TECH_DEBT.md if the change introduces, resolves, or affects any tracked debt
3. Include these file updates in the same commit
