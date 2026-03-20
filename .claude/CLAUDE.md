
Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.

## Session Management

- **When starting a new session:** Read PROGRESS.md first to understand current state before continuing work.
- **Saving progress:** Use the `/save` skill. It updates PROGRESS.md, TECH_DEBT.md, and checks for CLAUDE.md learnings.
- **Committing:** Always run `/save` before committing (the `/ship` skill does this automatically).

## Tech Debt Tracking

Consult `TECH_DEBT.md` at these key moments:
- **Before starting a new feature** - check if any P1 items affect the area you're working in
- **Before each milestone ships** - review all P1 items and resolve them
- **During refactoring passes** - work through P2/P3 items

The `/save` skill handles TECH_DEBT.md updates (format, priorities, housekeeping).
