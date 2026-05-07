# Global Agent Instructions

Universal rules for AI coding agents. `CLAUDE.md` symlinks here.

## Token Delegation

Use `ask-intern` to offload high-token/low-reasoning work to a cheap model (~$0.002/call). This preserves Pro limits for actual reasoning.

Check the exceptions first. If an exception applies, read directly even when the file is over 400 lines.

### Use `ask-intern` when

You MUST use `ask-intern` when any rule below applies and no direct-read exception applies.

- A non-exception file is over 400 lines.
- You need broad context from multiple medium/large files.
- You are reading long logs, diffs, transcripts, generated output, or non-exception documentation for a summary.
- You are drafting boilerplate: tests, config, docstrings, fixtures, sample data, repetitive code, or format conversions.

Build the file list from actual paths (`rg --files` is fine), then use the summary instead of reading those files yourself. If `ask-intern` reports `Cannot read`, correct the paths and retry.

### Read directly instead when

- Exact instructions, ordering, checkboxes, or wire formats matter.
- The file is durable control or project documentation: `PROGRESS.md`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, or anything under a `docs/` directory.
- The user explicitly asks to read a file verbatim.
- You need exact line numbers, exact text, verification, or edit snippets after an `ask-intern` overview.
- The task is under ~2000 tokens total and delegation overhead is not worth it.
- The work requires careful reasoning from conversation context, architecture judgment, debugging, or safety-critical code.

For arbitrary queue/plan files outside `docs/`, put `<!-- agent-control: direct-read -->` near the top when agents should read them directly. If the user explicitly asks to read a file verbatim and the guard blocks it, run `ask-intern-guard --allow-next <path> "verbatim user request"` and then read it directly.

Claude Code has a PreToolUse hook that routes broad direct reads to `ask-intern` when they cross the line budget. If that conflicts with a direct-read exception, use the guard/allow-next path rather than summarizing the file.

Do not use `ask-intern` to print exact/verbatim code, full source, or line-numbered snippets. Use it to identify relevant files, functions, contracts, risks, and approximate ranges; exact text for edits must come from direct small-file reads or narrow `Read`/`sed` snippets.

When dispatching code-reading or code-editing subagents, copy the relevant Token Delegation instructions into each subagent prompt **verbatim**: the `Use ask-intern when` rules, the `Read directly instead when` exceptions, the `ask-intern -t` draft-write examples when tests/fixtures/docs/repetitive code may be generated, the narrow-snippet-after-summary rule, and the exact/verbatim-code prohibition. Do not paraphrase. This applies even when a workflow skill such as `superpowers:subagent-driven-development` supplies the rest of the prompt; append the Token Delegation block before the `spawn_agent` / Task call. Subagents often rebuild context from scratch, and paraphrases lose the thresholds after long context.

Stop signals — if you think any of these, delegate instead:
"let me read these files", "let me check", "I'll look at a few", "let me explore".

### Usage

```bash
# Bulk reading (returns summary — use instead of reading files yourself)
ask-intern -f src/models.py -f src/api.py "how does auth work?"

# Write-to-file mode (output goes directly to disk, never enters your context)
ask-intern -t tests/test_user.py -f src/user.py "write pytest tests for all public methods"
ask-intern -t src/types.ts -f schema.prisma "generate TypeScript interfaces for each model"

# Piped input
git diff HEAD~5 | ask-intern "summarize these changes"

# Usage dashboard
ask-intern --stats
```

Full reference for maintenance/troubleshooting only: `docs/ai/ask-intern.md`. Do not load it just to decide whether to delegate.

## Graph Navigation

If `graphify-out/graph.json` exists and the task is codebase orientation, architecture, or cross-module tracing, use Graphify before broad raw search. Start broad with `graphify-out/wiki/index.md` and `graphify-out/GRAPH_REPORT.md`. Use `graphify explain "<exact node>"` for known symbols/files, e.g. `graphify explain "cascadeLegTimes()"`, `graphify explain "useOptimisticMutation()"`, or `graphify explain "message-compiler.ts"`. Use `graphify query "<terms>"` only for concrete symbols/files/domain terms, e.g. `graphify query "cascadeLegTimes timing recalculation"` or `graphify query "message-compiler.ts resolveStopMessages"`, not open-ended prose questions.

Then use `ask-intern` for bulk summaries or low-reasoning drafts from selected files, and read narrow snippets yourself only for exact edits: `ask-intern -f src/a.ts -f src/b.ts "summarize the contract and risky callers"` or `ask-intern -t /tmp/tests-draft.md -f src/foo.ts "draft tests for the public behavior"`.

Before dispatching code-reading or code-editing subagents in a repo with `graphify-out/`, use Graphify at the orchestrator level to identify likely owners, source-of-truth files, and shared functions. Put those concrete files/functions in the subagent prompt so workers preserve DRY instead of rediscovering context. Only copy this Graph Navigation section into a subagent prompt when that subagent's task is itself orientation, ownership tracing, or cross-module analysis.

Usage dashboard: `graphify-stats`.

When the user types `/graphify`, invoke the `graphify` skill before doing anything else.

## Before Work

- Read root `PROGRESS.md` at session start.
- At session start, before broad codebase exploration, check whether the first context-gathering step is `ask-intern`-shaped: large files, multiple medium/large files, long logs, diffs, transcripts, or repetitive draft generation. Use the `ask-intern` skill if helpful.
- Use context7, or the agent's equivalent docs MCP, for code generation, setup/configuration, and library/API docs. Resolve and fetch docs without waiting for an explicit ask.
- After completing requested file changes and verification, commit your own changes without asking unless the user explicitly says not to. Stage only files changed for the current task and leave unrelated dirty files alone.
- **Adaptive docs.** Read the matching file BEFORE relevant work and announce `📖 Loading context: <path>.md`.
  - Per-project: if the project has `docs/ai/`, treat it as source of truth.
  - Global (`~/dotfiles/docs/ai/`):

  | Task | Doc |
  |---|---|
  | Git operations, committing, rebasing, merging | git.md |
  | Editing AGENTS.md, .agents/skills/, docs/ai/ | writing-docs.md |
  | Maintaining or troubleshooting ask-intern | ask-intern.md |
  | Operating or changing the learning system | learning-system.md |
- Re-read the hard rules before implementation.

## Session Tools

- **MANDATORY for interactive parent sessions: invoke `task-observer` BEFORE your first tool call** when tools will produce deliverables. Delegated/non-interactive subagents, review-only workers, verify-only workers, and Codex/Claude print-mode reviewers skip it; the parent agent owns observation logging.
- `task-observer` is the ambient sensor for durable feedback, not the durable store. Route project learnings through `/learn` into `docs/learnings/`; route global agent-system learnings through `/learn` in dotfiles. Use observation files only as fallback/session audit notes when a learning cannot yet be routed cleanly.
- If fallback observation files are needed, store them centrally:

| Default | Use instead |
|---|---|
| `<workspace>/skill-observations/log.md` | `~/.agents/observations/<project-slug>/log.md` |
| `<workspace>/skill-observations/archive/log-<date>.md` | `~/.agents/observations/<project-slug>/archive/log-<date>.md` |
| `<workspace>/skill-observations/cross-cutting.md` | `~/.agents/observations/<project-slug>/cross-cutting.md` |

`<project-slug>` is the git toplevel basename, or `_meta` outside git. These files are not a parallel durable learning backlog; promote durable items into the learning system.

## Superpowers Paths

Never write Superpowers artifacts under `docs/superpowers/`. Use:

| Artifact | Path |
|---|---|
| Specs/design docs | `docs/specs/YYYY-MM-DD-<feature>/design.md` |
| Plans | `docs/specs/YYYY-MM-DD-<feature>/plan.md` |

Keep the feature folder together: `design.md`, `plan.md`, `checklist.md`, `deferred.md`, and `reviews/`.

## Writing

- Comment the why, not the what.
- When tightening docs, remove redundancy without softening corrective guardrails.

## Surfacing to the User

For any recommendation, decision, deferred item, review finding, blocker, or question, use plain English and include the user-facing ramification.

Why: without the ramification, findings read like engineering todos and I cannot weigh them against product priorities. With it, they become decisions I can make.

- Lead with what the user sees, loses, feels, or risks.
- Translate jargon into product framing: "unsafe cast" becomes "custom field edits could crash on save."
- File:line citations are references, not the explanation.
- If there is no product impact, say: "No user-facing impact - this is internal."
- If you cannot state the impact, re-read before surfacing.
- When user input is needed, brief like a CEO decision memo: the decision needed, the recommended choice, the user/business impact, the tradeoff or risk, and what happens if we wait or do nothing.
- Include only context that changes the decision. Leave out internal taxonomy, raw logs, implementation trivia, and low-value options.
- If the evidence makes one path clearly useful and reversible, take it instead of asking. Ask only when the choice changes product behavior, priority, cost, risk, or user experience.

## Code Hard Rules

These rules prevent the common agent failure mode: making a small, plausible shortcut under context pressure and leaving the user with a hidden regression.

- Preserve existing working behavior unless the user approves the change. Self-check: if reverting the feature would change anything else, ask first.
- Search before writing any function, helper, utility, or computation. Reuse existing code instead of recreating it. Stop signals: "I need a helper", "simplest approach", "let me add a utility", or "I'll compute this by".
- Trace callers before changing a function. Most regressions happen when a caller two levels up depended on behavior that looked local.
- Keep one source of truth. No duplicate logic, duplicate data, copy-pasted components, parallel parameters, or lighter duplicate functions. They will diverge, so extend the existing mechanism instead.
- Make contracts unbreakable. Shared shapes, values, cleanup, sequences, and coupled operations belong in shared helpers, wrappers, builders, types, or tests. A new call site should not be able to silently get the contract wrong.
- Fix visible violations in the touched area: duplication, hardcoded values, missing boundary tests, and bypassed guardrails are part of the task. Leaving them in place means the next change starts from a known broken pattern.
- Prefer fixing weak infrastructure over working around it. Hard fixes usually mean the abstraction is missing or the data flow needs simplifying.
- Ask before assuming deployment context, geography, scale, or user base. Scope guesses become product decisions if they land in code.
- Correctness over laziness. Most bugs come from taking the easy path under context pressure, not from missing requirements. If a scope/correctness tradeoff is needed, ask the user so they can choose deliberately.
- No silent shortcuts. If correctness cannot fit right now, only two options are allowed: break the work into smaller `PROGRESS.md` subtasks and tell the user, or mark the incomplete spot with `FIXME:` explaining what is wrong and what the correct fix is. Unmarked shortcuts are bugs.
- Stop immediately if you think: "for now", "MVP", "only one user", "I'll come back", "this is fine", or "let me just". Do it correctly, ask the user, or write the `FIXME:`.

## Testing

- TDD always: write the failing test first, run it, then implement without changing that test. No rationalizing. If code comes first, stop immediately, back it out, and write the test.
- For user-reported bugs, first write a test that reproduces the report from the user's perspective.
- If a project legitimately does not warrant TDD, its `AGENTS.md` must override this with rationale.
