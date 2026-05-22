> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: writing-docs.md (re-using from earlier)". If no, read it and announce "Context loaded: writing-docs.md".**

# Writing & Editing Project Documentation

Read this before changing root `AGENTS.md`, `.agents/skills/`, nested `AGENTS.md`, or `docs/ai/` - in any project, including this dotfiles repo itself.

## Contract

- Keep always-loaded text small. Every root instruction competes with the task.
- Keep root `AGENTS.md` under 100 lines unless the user explicitly approves growth.
- Keep activation text separate from reference content so agents load the source doc instead of guessing from summaries.
- Write contracts as action + reason + verification. Models follow direct instructions better when the why is visible.
- Lead with the positive action. Use negative wording for known cliff edges, then immediately state the safe path. Reserve `NEVER` or all-caps wording for data-loss, security, or guardrail-bypass risks.
- Keep one source of truth per concept. Point to it instead of restating it.
- Move enforceable rules into tooling. Docs are for judgment calls and routing.
- Keep reference docs free of session history, one-off fixes, and stale examples.
- Preserve lint rules, contract tests, allowlists, and nested guardrails unless the user explicitly approves a weaker contract.

## Layers

| Layer | Files | Purpose |
|---|---|---|
| Always loaded | `AGENTS.md` | Universal rules and routing table only |
| Activation | `.agents/skills/*/SKILL.md`, nested `AGENTS.md` | Decide which reference docs load, plus directory guardrails |
| Reference | `docs/ai/*.md` | Topic contracts, canonical files, verification |
| Drafts | Anything under draft/scratch directories | Not referenced by root files, skills, or nested `AGENTS.md` |

Draft compression directories may exist while experimenting. Keep activation paths pointed only at canonical docs.

## Global vs Per-Project

Two scopes share this contract:

- **Global** (`~/dotfiles/docs/ai/`): topic contracts that apply across every project (e.g. this file). Loaded contextually when the task matches, regardless of which project is active.
- **Per-project** (`<project>/docs/ai/`): topic contracts specific to one codebase (domain rules, schema notes, project-specific patterns). Loaded only when working in that project.

The same writing principles apply to both. Don't restate a global contract in a per-project doc - link to the global one and add only the project-specific delta.

## Context Probes

The `Context loaded: <file>` line at the top of each `docs/ai` file is intentional. It verifies which docs the harness actually loaded.

- Keep probes short and consistent.
- Treat probes as load markers, not content.
- If probes are removed later, move visibility into the skill or harness first.

## Skill Files

Skill frontmatter is routing metadata, not a mini-doc.

- `description` describes when the skill applies.
- `description` starts with "Use when..." and names triggering conditions only.
- `description` avoids workflow summaries that let an agent skip reading the body.
- Body should usually be one or two lines: read the relevant `docs/ai` file, plus conditional extra docs.
- If a skill needs heavy details, put them in a referenced file and load them conditionally.

Good:

```yaml
description: "Use when editing UI data reads, UI data writes, React Query hooks, mutation logic, cache updates, shared pure functions, timing, stops, or data-mutating API routes."
```

Bad:

```yaml
description: "Use for optimistic updates - use onMutate, update cache, rollback on error, invalidate on settled."
```

The bad version tempts the agent to follow the summary instead of reading the source doc.

## Nested AGENTS.md

Nested `AGENTS.md` files are both activation hooks and hard guardrails.

- Keep them under 10 lines when possible.
- State only non-negotiable directory rules.
- Point to `docs/ai` for details.
- Keep examples in the reference doc instead of duplicating them here.

Use nested guardrails for directories where missing context causes real bugs - e.g. API routes, data-mutation logic, shared cross-cutting code, components, and tests.

## Reference Docs

Use this shape unless a doc has a clear reason to differ:

```md
# Topic

## Contract
- Do ...
- Use ...
- Keep ...
- Do not ...; do ... instead.

## Canonical Files
- `path/to/file.ts` - purpose

## Verification
- test, lint rule, or grep command

## Notes
- durable context and rationale only
```

Keep examples only when they prevent a known repeat bug. Put the rule and reason first, then the example.
Use negative rules when a specific shortcut has caused bugs or bypasses; pair each one with the replacement pattern.

## Compression

When tightening or compressing existing agent instructions:

- **Preserve corrective guardrail strength.** Imperative phrases such as "stop immediately", "no rationalizing", and explicit fallback options exist because softer wording has caused repeated agent failures. Remove redundancy; do not reduce enforcement force. If a phrase is a guardrail against a known failure mode, keep the force even when cutting characters.
- **Keep rationale for judgment-heavy rules.** Rules that require the agent to choose how to frame output — not merely follow a mechanical command — need a short explanation of why. Without it, the model satisfies the literal surface form of the rule while missing the intent. A one-sentence "because" is part of the instruction, not padding.
- **Keep compact failure-mode rationale for safety-critical rules.** For rules that prevent correctness bugs or data loss, preserve three things alongside the imperative: what goes wrong, what thought pattern is a stop signal, and what action is allowed instead. This triples the character cost but prevents the model from rationalizing exceptions under context pressure.
- **Lead with the positive action.** Phrase tradeoff guidance as the desired behavior, not as a prohibition. "If a scope/correctness tradeoff is needed, ask the user" is more reliably followed than "never make scope/correctness tradeoffs silently."

## Enforcement

When a rule can be checked, add or reference the check.

- Lint restrictions for forbidden APIs.
- Contract tests for architectural boundaries.
- Grep checks for constants, direct field access, TODO/FIXME markers, and raw fetches.
- Propagation tests for invariants that span layers.

Escape hatches must be loud. New lint disables, allowlist entries, skipped contract tests, or weakened assertions are architecture changes. Review them before accepting them.

## Where Instructions Go

| Instruction type | Location |
|---|---|
| Applies to every task in every project | `~/dotfiles/.claude/AGENTS.md` |
| Applies to a topic across every project | `~/dotfiles/docs/ai/<topic>.md` |
| Applies to every task in one project | `<project>/AGENTS.md` |
| Applies to a topic in one project | `<project>/docs/ai/<topic>.md` |
| Applies to a directory | Nested `AGENTS.md` |
| Controls automatic loading | `.agents/skills/<skill>/SKILL.md` |
| Is enforceable mechanically | Lint, tests, or grep check |
| Is a one-off note | Nowhere |

## Maintenance

When adding, removing, or renaming a `docs/ai` file, update:

1. Root `AGENTS.md` routing table (global or per-project, whichever scope owns the doc).
2. `.agents/skills/*/SKILL.md` pointers.
3. Nested `AGENTS.md` pointers.
4. `docs/ai/README.md` if the project keeps an inventory there.
