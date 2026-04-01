---
name: spec-interview
description: "Interview the user in detail about a feature they want to build, then write a complete spec to docs/specs/. Use when the user says 'spec interview', 'interview me', 'create a spec', 'write a spec', 'let's spec this out', or asks to define requirements for a feature."
user-invocable: true
argument-hint: [brief description of what to build]
---

# Feature Spec Interview

The user wants to build: **$ARGUMENTS**

## Phase 1: Deep Interview

Use the AskUserQuestion tool to interview the user in detail about this feature. Your goal is to uncover everything needed to write a complete, unambiguous spec.

**Interview strategy:**
- Start with the hard questions first. Skip anything obvious from CLAUDE.md or existing code.
- Focus on UI/UX decisions, edge cases, error states, and tradeoffs the user might not have considered.
- Ask about interactions with existing features and data model implications.
- Dig into the "what happens when..." scenarios.
- Challenge assumptions. If something seems underspecified, probe it.
- Each round should have 1-4 focused questions. Don't repeat ground already covered.
- Use option-based questions when there are clear alternatives. Use open-ended when exploring.

**Topics to cover (not necessarily in order):**
- Core user flow and interaction model
- Edge cases and error states
- Data model changes (new tables, fields, relations)
- API surface (endpoints, payloads, validation)
- UI layout and component hierarchy
- Loading, empty, and error states
- Accessibility considerations
- Integration with existing features
- What's explicitly out of scope

**Keep interviewing until** you've covered all the above and have no remaining ambiguity. Don't rush - thoroughness now prevents rework later.

## Phase 2: Write the Spec

Once the interview is complete, write the spec to `docs/specs/YYYY-MM-DD-<feature-name>.md` (today's date + kebab-case filename derived from the feature name). Create the `docs/specs/` directory if it doesn't exist.

**Spec structure:**

Every spec has these **required sections** (always present):

```markdown
# [Feature Name]

## Overview
One-paragraph summary of what we're building and why. Include a guiding principle if one emerged.

## User Stories
- As a [role], I want [action] so that [benefit].

## Acceptance Criteria
Grouped by logical area (e.g., "### Setup & Template", "### Core Algorithm", "### Validation").
- [ ] Testable criterion 1
- [ ] Testable criterion 2
- [ ] All existing tests still pass

## User Flow
Step-by-step walkthrough of the primary user journey. Multiple flows if the feature has distinct paths (e.g., "### Primary Flow", "### Re-run Flow", "### Latecomer Flow").

## Constraints
- Tech stack constraints (from CLAUDE.md and existing code)
- Design constraints (consistency with existing UI)
- Scope boundaries

## Edge Cases
| Scenario | Handling |
Table format preferred for scanning 10+ cases.

## Out of Scope
- What we're explicitly not building. Split into "Deferred to [milestone]" vs "Not MVP" if useful.

## Open Questions
- Anything still unresolved (should be empty if interview was thorough)
```

Beyond these, **add whatever sections the feature demands.** The spec should capture every concept, decision, and nuance that emerged from the interview. Common additional sections (add any that apply):

- **Glossary and Concepts** - when the feature introduces domain terms, structures, or rules that readers must understand before the rest of the spec makes sense. Define each term with examples. This section goes right after Overview if needed.
- **UI Design** - layout, component hierarchy, interactions, states. Include ASCII mockups for table/grid layouts. Add per-section details (e.g., "### Journey Groups Tab", "### Designer Tab").
- **Data Model** - new/modified tables with Prisma-style schemas. Include caching strategy if relevant.
- **API** - endpoints, payloads, response shapes. Include long-running operation strategy (SSE, polling, etc.).
- **Algorithm / Logic** - when the feature has non-trivial computation. Describe inputs, steps, scoring functions, performance budgets. Note what should be pure functions.
- **Key Decisions from Interview** - table of decisions + rationale from the interview. Prevents future re-debating.

Don't pad the spec with empty sections. If the feature has no algorithm, don't add an Algorithm section. If there's no new data model, skip it. But when a section IS needed, go deep - a thorough spec prevents rework.

**Writing tips:**
- User stories should cover each distinct persona/scenario, not just the happy path.
- Acceptance criteria must be **testable** - a QA tester or e2e test should be able to verify each one with a pass/fail. Write them as checkboxes so they can be ticked off during review. Group by area when there are 15+ criteria.
- Constraints ground the spec in reality - pull from CLAUDE.md, existing code patterns, and what the user said during the interview.
- **Key Decisions** is one of the most valuable sections. Record every notable decision with its rationale so future sessions don't re-debate them.

## Phase 3: Present the Spec

After writing the spec, read it back and display its full contents in the chat so the user can review it inline.
