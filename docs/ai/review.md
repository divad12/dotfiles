> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: review.md (re-using from earlier)". If no, read it and announce "Context loaded: review.md".**

# Review

## Contract

- Orchestration skills say **how** to run a review workflow; this doc and project review docs say **what** to review.
- Global contracts live here and apply across projects. A project `docs/ai/review.md` holds only project-specific deltas (additional lenses, de-scoped concerns, project conventions) and points to this file.
- If a project explicitly de-scopes a concern (e.g. "No ARIA work yet", "single-user only", "desktop-only"), that exclusion is as authoritative as an inclusion. Reviewers must check for de-scoped concerns before raising findings in those areas.
- Findings that target capabilities the project explicitly de-scoped are **inadmissible**. Check AGENTS.md / project `docs/ai/` for "No X yet", "X is not needed", or "out of scope" before raising a finding.
- De-scope rules apply to automated reviewers and orchestrators alike. The orchestrator's finding-triage step must re-read AGENTS.md once and skip findings that contradict declared exclusions.

## Review Scope

Before computing a diff, read project coordination docs (`PROGRESS.md`, `AGENTS.md`) for an explicit target branch. Use that branch as the review base. Fall back to `main` / `master` only when no project-specific base is declared.

Uncommitted diff scope must include untracked new files, not only modified files:

```bash
git diff --cached
git diff
git ls-files --others --exclude-standard  # untracked new files
```

For each untracked file, include it as an added-file patch: `git diff --no-index -- /dev/null "$file"`. Review scope summaries should state the untracked file count.

## Reviewer Independence

The value of an independent reviewer is a second reasoning engine with different defaults and blind spots. The independent reviewer must receive:
- The diff being reviewed
- Relevant project rules (AGENTS.md or an excerpt covering the changed areas)
- Any explicitly de-scoped concerns, so the reviewer does not raise them

Omitting project rules from the independent reviewer prompt turns independent review into industry-convention enforcement, which often conflicts with deliberate project decisions.

## Bug Learning Layers

Fixed bugs form an abstraction ladder, not competing ledgers:

- **Incident**: what broke, what test guards it, what commit fixed it.
- **Pattern**: the class of bug, the contract that was violated.
- **Guardrail**: the mechanical prevention artifact (test, lint rule, shared helper, docs/ai rule).

A bug is fully learned when the class has a guardrail, not just when the incident is closed. See `bugfix-tdd` for the per-bug workflow.

## Notes

- When a review finding targets an area explicitly de-scoped by AGENTS.md, flag it to the orchestrator rather than auto-fixing it.
- Reviewer prompts should include AGENTS.md (or a relevant excerpt) alongside the diff so reviewers can check both inclusions and exclusions.
