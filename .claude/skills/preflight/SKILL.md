---
name: preflight
description: "Use when preparing an implementation plan for disciplined execution, typically after /superpowers:writing-plans and before /fly. Triggers: 'preflight', 'checklist the plan', 'prep for execution', or when given a plan file path to process."
argument-hint: [path to plan file]
user-invocable: true
---

# Preflight

Transform a plan file into a checklist contract that `/fly` executes.

## Purpose

Transform a plan into a preflight checklist with all execution decisions encoded. The checklist becomes the contract `/fly` executes.

Runs before `/fly`. Does not modify the plan - writes a sibling checklist file and prints a terminal summary.

## Triggers

- User invokes `/preflight <plan-path>` on any plan file (fresh from `/superpowers:writing-plans`, or mid-flight on a pre-existing plan).
- Not auto-chained from writing-plans - user reviews plan first, then explicitly invokes preflight.

## Input

Path to plan file (typically `docs/specs/plans/YYYY-MM-DD-<feature>.md`). Works on any markdown plan with task and phase sections.

## Output

1. Sibling file: `docs/specs/plans/YYYY-MM-DD-<feature>-checklist.md` (same directory as input plan, with `-checklist` suffix appended to basename).
2. Original plan is untouched (audit trail).
3. Terminal summary printed at end (see "Terminal Summary" section below).

## Overwrite Behavior

If the checklist file already exists, warn and ask for explicit overwrite confirmation before proceeding. An existing checklist may contain in-progress `/fly` state (ticked checkboxes, filled slots). Clobbering loses work.

If the user confirms overwrite, preserve any fills from the existing file only if the plan hasn't changed (same task list). If the plan changed, produce a fresh checklist and tell the user their previous progress is in the file they're overwriting.
