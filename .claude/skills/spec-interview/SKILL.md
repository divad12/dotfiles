---
name: spec-interview
description: Interview the user in detail about a feature they want to build, then write a complete spec to docs/specs/
disable-model-invocation: true
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

Once the interview is complete, write the spec to `docs/specs/<feature-name>.md` (kebab-case filename derived from the feature name). Create the `docs/specs/` directory if it doesn't exist.

**Spec format:**

```markdown
# [Feature Name]

## Overview
One-paragraph summary of what we're building and why.

## User Stories
- As a [role], I want [action] so that [benefit].
- As a [role], I want [action] so that [benefit].

## Acceptance Criteria
- [ ] Testable criterion 1
- [ ] Testable criterion 2
- [ ] All existing tests still pass

## User Flow
Step-by-step walkthrough of the primary user journey.

## UI Design
- Layout and component hierarchy
- Key interactions and state transitions
- Loading, empty, and error states

## Data Model
- New or modified tables/fields
- Relations and constraints
- Migration notes

## API
- New or modified endpoints
- Request/response shapes
- Validation rules

## Constraints
- Tech stack constraints (from CLAUDE.md and existing code)
- Design constraints (consistency with existing UI)
- Scope boundaries

## Edge Cases
- Enumerate each edge case and how it's handled

## Out of Scope
- What we're explicitly not building

## Open Questions
- Anything still unresolved (should be empty if interview was thorough)
```

**Writing tips:**
- User stories should cover each distinct persona/scenario, not just the happy path.
- Acceptance criteria must be **testable** - a QA tester or e2e test should be able to verify each one with a pass/fail. Write them as checkboxes so they can be ticked off during review.
- Constraints ground the spec in reality - pull from CLAUDE.md, existing code patterns, and what the user said during the interview.

## Phase 3: Present the Spec

After writing the spec, read it back and display its full contents in the chat so the user can review it inline.
