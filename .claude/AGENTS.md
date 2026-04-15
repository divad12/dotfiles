# Global Agent Instructions

Agent-agnostic rules that apply to any AI coding agent (Claude Code, Codex, Cursor, Windsurf, Aider) working on my projects. Mirrors `CLAUDE.md` for agents that read `AGENTS.md` as their primary configuration file.

## Documentation Lookups

Use context7 (or the agent's equivalent documentation MCP) when you need code generation, setup/configuration steps, or library/API documentation. Resolve library IDs and fetch docs without the user having to explicitly ask.

## Session Management

- **When starting a new session:** Read `PROGRESS.md` at the project root first to understand current state.
- **Saving progress:** Use the `save` skill / `/save` command. It updates `PROGRESS.md`, `TECH_DEBT.md`, and checks for learnings to route into the docs.
- **Committing:** Always run `save` before committing (the `ship` skill does this automatically).

## Tech Debt Tracking

Consult `TECH_DEBT.md` at:
- **Before starting a new feature** - check if any P1 items affect the area
- **Before each milestone ships** - review all P1 items and resolve them
- **During refactoring passes** - work through P2/P3 items

## Adaptive Docs System

If a project has a `docs/ai/` directory at its root, treat it as the source of truth for topic-specific guidelines. The root `AGENTS.md` (and `CLAUDE.md` if present) will contain a reference table pointing from task types to the relevant `docs/ai/` file. Read the matching file BEFORE starting work on that topic.

Before diving into a task, state which `docs/ai/` files you're loading in this format:

```
📖 Loading context: docs/ai/<file>.md
```

To install this system in a project: `/adaptive-docs-init`. To refactor an existing bloated root instructions file into it: `/adaptive-docs-extract`.

## Superpowers Directory Overrides

The superpowers skills (brainstorming, writing-plans, etc.) default to saving under `docs/superpowers/`. In any of my projects, override these defaults:

| Superpowers artifact | Default | **Use instead** |
|---|---|---|
| Specs / design docs | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` | `docs/specs/YYYY-MM-DD-<topic>-design.md` |
| Plans | `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` | `docs/specs/plans/YYYY-MM-DD-<feature>.md` |

This applies to brainstorming, writing-plans, and any other superpowers skill that writes a file under `docs/superpowers/`. Always save under `docs/specs/` (specs) or `docs/specs/plans/` (plans) instead.
