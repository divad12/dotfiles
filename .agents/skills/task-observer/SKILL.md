---
name: task-observer
description: "Use when starting an interactive parent task session, when the user gives feedback about agent behavior, or when the user asks about observations, skill improvements, or observation logs. Skip delegated/non-interactive subagents, review-only workers, verify-only workers, Codex/Claude print-mode reviewers, and sessions that only report back to a parent agent."
---

# Task Observer

<SUBAGENT-STOP>
If this is a delegated/non-interactive subagent, reviewer, verifier, or print-mode worker, stop using this skill now. Do not read observation logs, do not write observation logs, and do not mention this skill. The parent interactive session owns observation logging.
</SUBAGENT-STOP>

## Contract

- Run only in interactive parent sessions where user feedback can shape future behavior.
- Stay quiet during normal work. Surface observations only when useful, when blocked, or when the user asks.
- Act as the ambient sensor for durable feedback; route durable learnings to `/learn`.
- The learning store is the durable destination.
- Do not maintain a parallel durable backlog in observation files.
- Preserve user/project confidentiality. Strip client names, secrets, proprietary details, and transient file paths unless the observation is specifically about that path.
- Prefer tightening an existing skill or `docs/ai` contract over creating a new skill.
- Keep always-loaded observer text small. If this file starts growing, move detail into a narrower topic doc or delete it.

## Observation File Fallback

Use observation files only as a fallback or session audit trail when there is no
available learning store yet, when the note is too raw to route, or when you
need a temporary breadcrumb while actively resolving the issue. Do not write the
same durable learning to both systems as separate backlog items.

Use the git toplevel basename as `<project-slug>`, or `_meta` outside git.

| Purpose | Path |
|---|---|
| Active log | `~/.agents/observations/<project-slug>/log.md` |
| Archive | `~/.agents/observations/<project-slug>/archive/log-YYYY-MM-DD.md` |
| Cross-cutting principles | `~/.agents/observations/<project-slug>/cross-cutting.md` |

Create files only when there is something real to write and it cannot yet be
routed cleanly through `/learn`.

### Project Learning Routing

If the observation is about the current project's codebase, QA/review pattern,
test command, cache behavior, architecture guardrail, or repo-specific workflow,
invoke `/learn` and capture it in the current repo's `docs/learnings/` store
instead of only writing to `~/.agents/observations/<project-slug>/log.md`.
Do this without waiting for the user to say `/learn`; user feedback about a
durable project pattern is already the trigger.

Keep agent-system observations in dotfiles when they concern skills, hooks,
global docs, task-observer itself, or cross-project agent behavior. If the
dotfiles learning store is available, invoke `/learn` there and capture the
durable learning in dotfiles `docs/learnings/`. The central observation log can
still hold a raw session note when useful, but the durable learning belongs in
the learning store.

Before writing any learning, use the `/learn` semantic duplicate check against
active inbox, candidates, promoted entries, recent archives, and same-session
captures. Multiple sources for the same issue should update one learning entry's
`Sources` and evidence trail.

## What To Notice

- The user corrects agent behavior, wording, priorities, or workflow.
- A skill or doc caused extra work, confusion, token waste, or wrong activation.
- A repeated workflow would benefit from a reusable skill, script, or reference doc.
- A tool limitation or repo convention should be captured for future sessions.
- A guardrail belongs in tooling instead of prose.

Do not log observations just because a task completed. Do not create observation
entries for durable learnings that were already captured through `/learn`.

## Observation Format

Only append open observations in this shape when using the fallback/audit path:

```md
### Observation N: Short title
- Date: YYYY-MM-DD
- Status: OPEN
- Scope: skill:<name> | docs:<path> | cross-cutting | tool:<name>
- Trigger: Brief user-facing event that revealed the pattern.
- Ramification: What the user loses, risks, or gains if this is fixed.
- Recommendation: Concrete change to make later.
```

When resolved, change `Status` to `RESOLVED` and add a short `Resolution:` line.

## Acting On Observations

- Small, obvious improvements: apply directly when they are in scope for the current task.
- Larger changes: propose or create a focused follow-up plan.
- Cross-cutting rules: add them to `cross-cutting.md` only when they apply across multiple skills or projects.
- If no observation is worth logging, do nothing.
