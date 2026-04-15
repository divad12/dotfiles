---
name: adaptive-docs-extract
description: "Refactor an existing bloated CLAUDE.md or AGENTS.md into the three-layer adaptive docs system. Identifies topics that should become docs/ai/ files, suggests skill triggers, and proposes directories for nested AGENTS.md guardrails. Use when the user says 'extract docs', 'split CLAUDE.md', 'refactor the docs', 'apply adaptive docs to existing project', 'slim CLAUDE.md', or has a sprawling root CLAUDE.md they want to break up."
user-invocable: true
---

# Adaptive Docs - Extract

Refactor an existing project's `CLAUDE.md` (and/or `AGENTS.md`) into the three-layer adaptive docs system: slim root + on-demand `docs/ai/` references + auto-activating skills + nested `AGENTS.md` guardrails.

This is a **consultant skill** - it doesn't blindly extract. It interviews the user about which topics deserve their own file, which directories warrant guardrails, and which need skill triggers.

## Prerequisites

Run `/adaptive-docs-init` first if the structure isn't in place:

```bash
test -d docs/ai && test -L .claude/skills && test -f docs/ai/writing-docs.md
```

If any of those is missing, run init before proceeding.

## Steps

### 1. Read the current root files

Read `CLAUDE.md` and `AGENTS.md` (whichever exist) at the project root. Note their length and structure.

If `CLAUDE.md` is under ~100 lines and well-organized, tell the user there may not be much to extract and confirm before proceeding. Sometimes a project genuinely has little context to disclose progressively.

### 2. Identify candidate topics

Read through `CLAUDE.md` and group its content into **topics**. A topic is a coherent area where 3+ paragraphs (or one substantial section) cluster around a single concern. Common candidates:

| Topic | Often worth extracting if... |
|-------|------------------------------|
| Testing | There are TDD rules, framework choice, test patterns, fixtures |
| API patterns | There are auth patterns, route handler conventions, error handling |
| Data model | There's schema info, relationships, validation rules |
| Forms / dialogs | There are form-specific conventions or UX rules |
| UI components | There are visual standards, design system rules, component patterns |
| State management | There are caching, optimistic update, or sync patterns |
| Git workflow | There are branch/rebase/PR conventions |
| Domain glossary | There's product-specific terminology that recurs |
| Build / deploy | There are deployment-specific rules or environment notes |
| Code review | There are review-specific checklists or rules |

For each potential topic in the current CLAUDE.md, decide:
- **Extract** - clearly its own area, gets read often when working on relevant tasks
- **Keep in root** - universal, applies to ANY task (e.g. "never use em dashes", "comment the why not the what")
- **Drop** - stale, redundant, or covered by linters

### 3. Confirm the extraction plan with the user

Present the plan using the AskUserQuestion tool. For each candidate, ask:

> "I see content about **{{topic}}**. Should this become `docs/ai/{{filename}}.md`?"

Options:
- "Yes, extract it"
- "No, keep in root"
- "No, drop it (stale/redundant)"

For larger refactors, batch related questions into a single AskUserQuestion call.

Also ask:
- "What's the project name?" (only if you can't infer it)
- Tech stack details if not already obvious

### 4. For each approved extraction

For each topic the user approves:

1. **Create `docs/ai/{{topic}}.md`** with the banner header at the top:
   ```markdown
   > **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: {{topic}}.md (re-using from earlier)". If no, read it and announce "Context loaded: {{topic}}.md".**

   # {{Topic Title}}

   {{extracted content here}}
   ```

2. **Remove the extracted content from CLAUDE.md** (and AGENTS.md if it was duplicated there).

3. **Add a row to the reference table** in CLAUDE.md and AGENTS.md:
   ```markdown
   | Working on... | Read |
   | {{when this applies}} | `docs/ai/{{topic}}.md` |
   ```

4. **Update the file tables** in `docs/ai/README.md` and `docs/ai/writing-docs.md`.

### 5. Propose skills (optional per topic)

For each new doc, ask: "Should this auto-activate via a skill?"

A skill makes sense when:
- The topic has clear file/directory triggers (e.g. "anything in `src/components/`")
- The topic has user-facing action triggers (e.g. "writing tests", "creating a form")
- Forgetting to read the doc is a recurring problem

A skill doesn't make sense when:
- The topic is rarely needed
- The reference table entry is already enough

For each approved skill, copy `~/.claude/templates/adaptive-docs/skill-template/SKILL.md.template` to `.agents/skills/{{skill-name}}/SKILL.md`. Replace placeholders:
- `{{SKILL_NAME}}` → kebab-case name
- `{{DESCRIPTION}}` → a description rich in trigger keywords (file paths, action verbs, library names). The description IS the activation - write it well.
- `{{SKILL_TITLE}}` → human-readable title
- `{{ONE_LINE_PURPOSE}}` → what reading the doc lets the agent do
- `{{TRIGGERS_PROSE}}` → a sentence or two on when to invoke
- `{{DOC_FILE}}` → the docs/ai/ filename without path

Then add a row to the skill table in `docs/ai/writing-docs.md`.

### 6. Propose nested AGENTS.md files

After all docs are extracted, scan the project for high-stakes directories that might warrant guardrails. Common candidates:

- `src/api/` or `app/api/` (server routes - auth, validation, mutations)
- `src/lib/db/` or wherever DB access lives (ORM, query patterns)
- `src/components/` (UI conventions)
- `tests/` (TDD discipline)
- `migrations/` or `prisma/` (irreversible changes)

For each candidate, ask: "Add a nested `AGENTS.md` guardrail here?"

Nested AGENTS.md should be **under 10 lines** and state the rule + why. Example:

```markdown
# {{Directory}} Guardrails

- Auth check first in every route handler
- Use {{ORM}} for queries, never raw SQL
- Read `docs/ai/api-patterns.md` before editing
```

Add each created file to the "Nested AGENTS.md" table in `docs/ai/writing-docs.md`.

### 7. Slim the root files

After extraction, the root `CLAUDE.md` should:
- Be under ~100 lines
- Contain only universal rules (apply to ANY task)
- Have an intent-based reference table pointing to `docs/ai/`

Root `AGENTS.md` should:
- Mirror CLAUDE.md universal rules
- Have the FULL "if X then Y" reference table
- Include any agent-specific guidance (e.g. PR conventions for Codex)

If CLAUDE.md is still over 100 lines after extraction, ask the user which sections might still be split or compressed.

### 8. Verify and report

Run a final pass:

```bash
wc -l CLAUDE.md AGENTS.md docs/ai/*.md
ls .agents/skills/
```

Report:
- Original CLAUDE.md length vs new length
- Number of `docs/ai/` files created
- Number of skills created
- Number of nested AGENTS.md created
- Reminder: when adding new docs in the future, update all the indexes (the `writing-docs.md` checklist)

## Notes

- **Don't extract aggressively on the first pass.** Better to leave 3 things in root than to create 10 thin docs that each have one paragraph. Topics should be substantive enough to be worth a separate file.
- **Use the AskUserQuestion tool** for the extraction plan rather than presenting a long markdown list. The user wants to make decisions, not read a wall of text.
- **Preserve content semantics.** When extracting, don't paraphrase or "improve" the text - move it verbatim. Refactor the writing in a separate pass if needed.
- **Banner format is mandatory.** Every `docs/ai/` file must have the "Context loaded" banner at the top so the agent doesn't re-read it within a session.
- **One canonical location per concept.** If you find the same rule stated in two places during extraction, keep it in one and remove the other - don't duplicate.
- **The /capture-learning skill** is the long-term maintenance flow. It routes new principles into the right `docs/ai/` file. Mention this at the end so the user knows how to grow the system.
