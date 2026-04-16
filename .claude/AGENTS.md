# Global Agent Instructions

Agent-agnostic rules for any AI coding agent (Claude Code, Codex, Cursor, Windsurf, Aider) working on my projects. `CLAUDE.md` is a symlink to this file - one source of truth.

## Documentation Lookups

Use context7 (or the agent's equivalent documentation MCP) for code generation, setup/configuration steps, or library/API documentation. Resolve library IDs and fetch docs without the user having to explicitly ask.

## Session Management

- **When starting a new session:** Read `PROGRESS.md` at the project root first to understand current state.
- **Saving progress:** Use the `/save` skill. It updates `PROGRESS.md`, `TECH_DEBT.md`, and routes learnings into the docs.
- **Committing:** Always run `/save` before committing (the `/ship` skill does this automatically).

## Tech Debt Tracking

Consult `TECH_DEBT.md` at:
- **Before starting a new feature** - check if any P1 items affect the area
- **Before each milestone ships** - review all P1 items and resolve them
- **During refactoring passes** - work through P2/P3 items

The `/save` skill handles `TECH_DEBT.md` updates (format, priorities, housekeeping).

## Adaptive Docs System

If a project has a `docs/ai/` directory at its root, treat it as the source of truth for topic-specific guidelines. The root `AGENTS.md` (and `CLAUDE.md` if present) contains a reference table pointing from task types to the relevant `docs/ai/` file. Read the matching file BEFORE starting work on that topic.

Before diving into a task, state which `docs/ai/` files you're loading:

```
📖 Loading context: docs/ai/<file>.md
```

To install this system in a project: `/adaptive-docs-init`. To refactor existing bloated root instructions into it: `/adaptive-docs-extract`.

## Superpowers Directory Overrides

The superpowers skills (brainstorming, writing-plans, etc.) default to saving under `docs/superpowers/`. In any of my projects, override these defaults:

| Superpowers artifact | Default | **Use instead** |
|---|---|---|
| Specs / design docs | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` | `docs/specs/YYYY-MM-DD-<topic>-design.md` |
| Plans | `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` | `docs/specs/plans/YYYY-MM-DD-<feature>.md` |

This applies to brainstorming, writing-plans, and any other superpowers skill that writes under `docs/superpowers/`. Always save under `docs/specs/` (specs) or `docs/specs/plans/` (plans) instead.

## Writing

- **Never use em dashes.** Use " - " (spaced hyphen), a period, or restructure.

## Code Hard Rules

These apply on every project. Individual project `AGENTS.md` files may add concrete examples or override with explicit rationale.

- **Comment the "why", not the "what".** Only comment where a future reader would ask "why?"

- **Don't change existing working behavior without asking first.** When adding a feature, only change what is strictly necessary. Self-check: "If I reverted my feature code, would any other behavior be different from main?" If yes, those are unauthorized changes.

- **SEARCH before you write.** Before writing ANY function, helper, utility, or computation: grep the codebase for existing implementations. Every time, not just when convenient. **Stop signals** - if you catch yourself thinking any of these, STOP and search first:
  - "I need a helper function to..." → Search. It probably exists.
  - "The simplest approach is..." → The simplest approach is to reuse what exists.
  - "Let me add a utility for..." → Search. Someone already added it.
  - "I'll compute this by..." → Search for existing computation first.
  - "This is essentially the same as..." → Then USE the same code. Don't rewrite it.
  - "Given the rule about X, this should be Y. But for now let me just..." → No. Do Y. That's what the rule says.

- **Map the call path before modifying.** Before changing a function, trace every caller. Changes that break a caller two levels up are the most common class of regression.

- **One source, one truth (DRY).** If two places compute the same thing, extract a shared function. If two entities store the same content, pick one as the source and derive everywhere else - never store a copy. **Copy-pasting is not reuse.** If you're about to copy a pattern from component A to component B, stop - extract into a shared component/hook/function first, then use it in both places. **Extend, don't duplicate mechanisms.** If an existing system handles a concern, extend it - don't add a parallel prop/parameter that achieves the same goal differently. **Never create a "lighter version" of an existing function.** Add optional parameters instead. Two functions producing the same output type WILL diverge. Consolidation overrides "don't change working behavior" - if two components do the same thing, consolidate first, then change once.

- **Fix violations when you see them.** If you notice existing code that violates project rules (duplication, hardcoded values, missing tests at a wiring boundary), fix it immediately as part of the current task. Never say "I'll note this for later" or "let me focus on X first and come back." The violation is blocking correctness NOW.

- **Correctness over laziness.** Every shortcut becomes a bug. This is the #1 source of bugs - not missing requirements, not wrong logic, but taking the easy path when context pressure mounts. **Pre-flight check before EVERY implementation:** re-read the applicable rules. If you catch yourself thinking "this is fine for now," "for MVP this works," "only one user so no need," or "I'll fix it later" - STOP. Either write it correctly, or ask with `AskUserQuestion`. Never make scope/correctness tradeoffs silently. **If doing the right thing feels hard, that's a signal the infrastructure needs fixing** (extract a hook, add a shared function, simplify the data flow) - not a reason to take a shortcut. **Ask before assuming.** Don't bake scope assumptions into code (deployment context, geography, scale, user base). If you're about to make one, ask first with `AskUserQuestion`.

- **No silent shortcuts.** If you can't do something correctly right now, you have exactly two options: (1) Break the work into smaller subtasks, track them in `PROGRESS.md`, and tell the user - then do each correctly. (2) If you absolutely must leave something incomplete, mark it with a `FIXME:` comment explaining what's wrong and what the correct fix is. Review tools (grep for FIXME/TODO/XXX) will surface them. Unmarked shortcuts are the ones that become bugs. **Deferral stop signals:**
  - "But for now let me just..." → No. Do it correctly or mark it FIXME.
  - "I'll come back to this..." → You won't. Fix it now or FIXME.
  - "For now this works..." → It won't. Do it right.
  - "This is fine for MVP..." → Ask the user, don't decide silently.

- **Make contracts unbreakable.** If the same value, shape, or sequence is constructed in more than one place, extract it into a shared function so callers can't get it wrong. This applies to coupled operations that must happen together, cleanup that must happen (try/finally or wrapper functions), step ordering (builder patterns, chained calls), and object shapes that must match. The test: "can a new call site silently get this wrong?" If yes, the abstraction is wrong.

## Testing

- **TDD always: write a failing test BEFORE writing production code.** If you catch yourself writing a fix before a test, STOP IMMEDIATELY, delete the fix, and write the test first. No rationalizing ("it's just a UI change", "it's simple", "I'll add tests after"). Every single time this rule is skipped, it causes bugs that a test would have caught.

- **When the user reports a bug, the FIRST thing you do is write a test that reproduces it.** Only then fix the code. Write the test from the user's perspective (input → expected output), run it, watch it fail, THEN investigate.

If a project legitimately does not warrant TDD (throwaway script, one-off migration, spike), the project's `AGENTS.md` should explicitly override this rule with rationale.
