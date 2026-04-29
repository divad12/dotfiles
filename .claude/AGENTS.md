# Global Agent Instructions

Universal rules for AI coding agents. `CLAUDE.md` symlinks here.

## Before Work

- Read root `PROGRESS.md` at session start.
- Use context7, or the agent's equivalent docs MCP, for code generation, setup/configuration, and library/API docs. Resolve and fetch docs without waiting for an explicit ask.
- If the project has `docs/ai/`, treat it as source of truth. Read matching
  docs before work and announce: `📖 Loading context: docs/ai/<file>.md`.
- Re-read the hard rules before implementation.

## Session Tools

- Invoke `task-observer` at the start of every task-oriented session: any session where tools produce deliverables.
- Store task-observer files centrally:

| Default | Use instead |
|---|---|
| `<workspace>/skill-observations/log.md` | `~/.agents/observations/<project-slug>/log.md` |
| `<workspace>/skill-observations/archive/log-<date>.md` | `~/.agents/observations/<project-slug>/archive/log-<date>.md` |
| `<workspace>/skill-observations/cross-cutting.md` | `~/.agents/observations/<project-slug>/cross-cutting.md` |

`<project-slug>` is the git toplevel basename, or `_meta` outside git. The repo
is auto-committed by launchd and reviewed M/W/F on `divad12/agent-observations`.

## Superpowers Paths

Never write Superpowers artifacts under `docs/superpowers/`. Use:

| Artifact | Path |
|---|---|
| Specs/design docs | `docs/specs/YYYY-MM-DD-<feature>/design.md` |
| Plans | `docs/specs/YYYY-MM-DD-<feature>/plan.md` |

Keep the feature folder together: `design.md`, `plan.md`, `checklist.md`,
`deferred.md`, and `reviews/`.

## Writing

- No em dashes in user-facing text: docs, specs, checklists, commit messages, or PR descriptions. Use " - ", a period, or rewrite the sentence.
- Comment the why, not the what.
- When tightening docs, remove redundancy without softening corrective guardrails.

## Surfacing to the User

For any recommendation, decision, deferred item, review finding, blocker, or
question, use plain English and include the user-facing ramification.

Why: without the ramification, findings read like engineering todos and I cannot
weigh them against product priorities. With it, they become decisions I can make.

- Lead with what the user sees, loses, feels, or risks.
- Translate jargon into product framing: "unsafe cast" becomes "custom field
  edits could crash on save."
- File:line citations are references, not the explanation.
- If there is no product impact, say: "No user-facing impact - this is internal."
- If you cannot state the impact, re-read before surfacing.

## Code Hard Rules

These rules prevent the common agent failure mode: making a small, plausible
shortcut under context pressure and leaving the user with a hidden regression.

- Preserve existing working behavior unless the user approves the change.
  Self-check: if reverting the feature would change anything else, ask first.
- Search before writing any function, helper, utility, or computation. Reuse
  existing code instead of recreating it. Stop signals: "I need a helper",
  "simplest approach", "let me add a utility", or "I'll compute this by".
- Trace callers before changing a function. Most regressions happen when a
  caller two levels up depended on behavior that looked local.
- Keep one source of truth. No duplicate logic, duplicate data, copy-pasted
  components, parallel parameters, or lighter duplicate functions. They will
  diverge, so extend the existing mechanism instead.
- Make contracts unbreakable. Shared shapes, values, cleanup, sequences, and
  coupled operations belong in shared helpers, wrappers, builders, types, or
  tests. A new call site should not be able to silently get the contract wrong.
- Fix visible violations in the touched area: duplication, hardcoded values,
  missing boundary tests, and bypassed guardrails are part of the task. Leaving
  them in place means the next change starts from a known broken pattern.
- Prefer fixing weak infrastructure over working around it. Hard fixes usually
  mean the abstraction is missing or the data flow needs simplifying.
- Ask before assuming deployment context, geography, scale, or user base. Scope
  guesses become product decisions if they land in code.
- Correctness over laziness. Most bugs come from taking the easy path under
  context pressure, not from missing requirements. If a scope/correctness
  tradeoff is needed, ask the user so they can choose deliberately.
- No silent shortcuts. If correctness cannot fit right now, only two options are
  allowed: break the work into smaller `PROGRESS.md` subtasks and tell the user,
  or mark the incomplete spot with `FIXME:` explaining what is wrong and what
  the correct fix is. Unmarked shortcuts are bugs.
- Stop immediately if you think: "for now", "MVP", "only one user", "I'll come
  back", "this is fine", or "let me just". Do it correctly, ask the user, or
  write the `FIXME:`.

## Testing

- TDD always: write the failing test first, run it, then implement without
  changing that test. No rationalizing. If code comes first, stop immediately,
  back it out, and write the test.
- For user-reported bugs, first write a test that reproduces the report from the
  user's perspective.
- If a project legitimately does not warrant TDD, its `AGENTS.md` must override
  this with rationale.
