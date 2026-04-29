# Per-Session Plan File Format (multi-session only)

Each `plan-N.md` is a self-contained plan file for one fly session. Only produced when total tasks > `single_file_cap`.

```markdown
# <Feature name> - Session N: <phase names>

## What we're building (overall)
<2-3 sentences from plan's Goal paragraph. If design.md exists, blend in its summary.>

## This session's scope
<1-2 sentences describing what this session's phases accomplish>

## Conventions
<extracted from plan's Conventions section if present: TDD rules, mock patterns, test env, run commands, commit cadence>

## Key references
<extracted imports, shared types, file structure summaries relevant to this session's phases>

## Tasks

### Task N.M: <task title>
<full task content verbatim from plan: files, steps, code blocks, everything>

### Task N.M+1: ...
...
```

## Rules

- "What we're building" and "Conventions" are duplicated in each plan-N.md. Around 10 lines each. Trivial cost, makes each file self-contained.
- "This session's scope" varies per file.
- "Key references" extracted per-phase (only imports/types relevant to this session).
- Task content is verbatim from plan.md - no paraphrasing.
- If design.md exists, incorporate a brief architectural context note in the "What we're building" section.
- "Conventions" is present only if the plan has a Conventions, Setup, or similar section. Omit entirely if the plan has no such content.
- "Key references" is present only if the plan references specific imports, shared types, or file structure that implementers need. Omit if none are relevant to this session's phases.
