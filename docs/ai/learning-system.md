> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: learning-system.md (re-using from earlier)". If no, read it and announce "Context loaded: learning-system.md".**

# Learning System

## Contract

- Make the learning system feel like a product, not a CLI. Only three user-facing front doors are normal: `/learn`, `/dashboard`, and `/learn-init`.
- Treat the global `learn --repo <repo>` command as hidden glue for agents and automations. Do not assume every participating repo has repo-local `bin/learn`, and do not teach the user to operate `capture`, `promote`, `execute`, or `check-merge` unless they ask for internals.
- Keep the canonical store in `docs/learnings/`. Raw evidence can be noisy; hot context and promoted guidance must stay curated.
- Use agents for judgment: clustering, abstraction, calibration, destination choice, and deciding whether a prevention artifact is clear enough to implement.
- Use binaries only for boring glue: initializing files, appending structured entries, assigning row IDs, serving the dashboard, recording decisions, safe markdown moves, and checks.
- Store prevention work as one readable list: `Prevention artifacts: docs (required), test (required), skill (proposed)`. Required artifacts describe the prevention work needed; proposed artifacts are worthwhile ideas to consider. The executor decides what is executable now.
- Fingerprint matching is not semantic dedupe. It is only a row identity and exact replay guard. Agents do all meaningful duplicate detection, semantic clustering, and pattern formation.
- Daily agentic automation should sweep participating repos, cluster new evidence, autopick the top one or two obvious high-leverage prevention actions, execute or prototype low-risk/high-clarity work, regenerate dashboards, and report only true product tradeoffs or review needs.
- Code, tests, helpers, skills, architecture, and global guidance still require TDD/review discipline. Automation may implement focused, high-clarity fixes only when it can write the failing test or structural check first and verify the result.
- Do not make the user choose micro-targets for broad learning patterns. Use evidence recency, repetition, user-facing impact, and reversibility to choose the next target yourself; ask the user only when the decision changes product behavior or priority.
- task-observer is the ambient sensor, not a second memory system. The learning store is the durable system; observation files are fallback/session audit only.

## User Front Doors

`/learn` captures. The agent should:

1. Identify the durable learning from the user's note, recent QA/review/bugfix evidence, or session context.
2. Climb one rung higher than the specific incident when the higher principle is still actionable.
3. Check `docs/learnings/` for an existing matching or related entry.
4. Use the CLI capture glue to write or merge the entry.
5. Regenerate the dashboard.
6. Announce the result as one session-visible line: `🧠 Captured learning: <plain-English summary>`.

Before writing, check the last five active learnings and same-session capture memory. If the learning is already covered, do not create a duplicate. Update the existing entry only when the new evidence, source, confidence, or technical refs add value, and announce `🧠 Learning already captured: <plain-English summary>`.

### The Abstraction Ladder

Before writing to `docs/learnings/`, climb one rung higher than the first principle that comes to mind. If the next rung is still actionable, capture that higher principle.

Start with what happened, then ask why repeatedly until you find the durable rule:

```text
Specific fix:   Walk time number picker allowed negative values
     -> Why?
Class of bug:   Form inputs lacked min/max constraints
     -> Why?
Pattern:        Validate at the boundary by constraining inputs to valid values
     -> Why?
Principle:      Make invalid user-facing input states unrepresentable
```

Write the principle as the main learning. Use the specific incident as evidence, the user-facing consequence as the ramification, and list the prevention artifacts that would stop the issue from recurring.

When the bug involves a removed field, renamed type, changed response shape, modified helper behavior, changed component props, or another shared surface, climb to the contract level:

```text
Specific fix:   Save payload still sent a removed field as null
     -> Why?
Class of bug:   Client payload drifted from the route schema
     -> Why?
Pattern:        A model/API contract changed without every consumer moving
     -> Why?
Principle:      When a shared contract changes, own every consumer of that contract
```

The sweet spot is the highest level that still tells a future agent what to do. "Be careful" is too vague. "Trace every caller and fixture after changing a shared contract" is actionable.

Treat "this should happen" as a warning sign, not a learning. Climb from the specific missing instruction or hook to the class: required behavior must be verified against actual wiring. The learning should name the enforcement surface: trigger phrase, skill text, automation prompt, hook, test, structural check, or code path.

After choosing the principle, ask what would enforce it next time: a regression test, lint rule, schema/contract scan, shared helper, checklist, docs update, skill tweak, or automation. Mark each prevention artifact as required or proposed. If the code surface does not exist yet, docs, skill, or nested-AGENTS updates may be the only executable prevention artifact for now; record the code/test artifact as required and let the executor mark it blocked or follow-up. Triage automation uses this ladder to cluster raw evidence into patterns; executor automation uses the enforcement idea to decide whether a prevention artifact is clear enough to implement.

### Skill and Doc Enforcement

When a learning is a repeatable habit for a task class, promote it into the
activation path for that task instead of leaving it only in candidates. Use an
existing skill and its referenced `docs/ai` file when possible: frontend or
button rules belong behind frontend/design/component triggers; merge rules
belong behind merge/git triggers; directory-local invariants belong in nested
`AGENTS.md` files that point to a reference doc.

Keep trigger text narrow and put the actual rule in reference docs. The goal is
that a future agent making the relevant thing, such as a button, form, dashboard
control, or merge decision, automatically loads the rule before implementation.

`/dashboard` reviews. The agent should:

1. Run the dashboard server with finish execution enabled.
2. Open or present the dashboard URL.
3. Let the user review visually.
4. When the user clicks Finish or says they are done, execute saved decisions if the server did not already do so.
5. Regenerate the dashboard and summarize what changed.

`/learn-init` initializes. The agent should:

1. Initialize `docs/learnings/` in the current repo.
2. Regenerate the dashboard.
3. Mention the three front doors.
4. If adaptive docs are being initialized, include the learning store as part of the same setup when the project wants learnings.

## Automation

Daily maintenance is split into focused automations so one agent does not become a giant context soup.

Use a frontier reasoning parent model for daily learning automations. Triage and
executor parents make clustering, abstraction, safety, and calibration
decisions, so prefer `gpt-5.5` with high reasoning while calibration is young.
Executor-dispatched coding subagents may use focused coding models such as
`gpt-5.3-codex` for bounded implementation, review, or verification slices.

Each cron invocation is repo-scoped. When an automation has multiple `cwds`,
the scheduler starts separate runs, one per working directory. A run must operate
on the current working directory only; it must not inspect, report on, write to,
or regenerate dashboards for sibling configured repos.

Do not leave successful automation runs dirty. At the start of each run, inspect
`git status --short`; if unrelated changes are already present, report the
dirty paths and stop before writing. The executor may consume explicit dashboard
decision files such as `docs/learnings/decisions.jsonl`, but it must not stage
unrelated pre-existing work. After a successful run with changes, verify, stage
only files changed by the automation, create one local commit, and report the
commit hash. Do not push.

Daily automations should read the canonical global learning-system contract
from the durable dotfiles master checkout, not from a temporary feature
worktree. They may also read a repo-local `docs/ai/learning-system.md` as a
supplement for the current cwd.

### Triage automation

Triage automation runs daily around 5pm. It clusters and prepares work. It should not edit product code.

For the current repo:

1. Read the local repo guidance and `docs/learnings/` store.
2. Inspect new or changed raw evidence referenced by inbox entries.
3. Cluster related entries into pattern-level candidates when the connection is clear.
4. Merge duplicates by appending evidence instead of creating more dashboard rows.
5. Archive obvious test-data-only, stale, or non-durable entries.
6. Create candidate action notes or draft plans for clear prevention artifacts.
7. Append plain-English audit lines to `docs/learnings/auto-actions.md`.
8. Start or refresh the dashboard app when possible and surface the clickable URL/path so the user can review immediately.
9. Tell the user they can say `done` after review to run executor automation now and skip the scheduled 9pm executor.

### Executor automation

Executor automation runs daily around 9pm unless it already ran after the user said `done`. It acts on triaged, high-confidence, narrow work.

1. Read candidates, auto-action notes, calibration, and any explicit dashboard decisions.
2. Autopick the top one or two next actions from high-confidence evidence. Prefer items that are repeated, recent, user-visible, reversible, and able to prevent several candidate patterns at once.
3. Execute low-risk docs updates directly when the destination and wording are clear.
4. For focused tests, lint checks, helper guardrails, or skill tweaks, write the failing test or structural check first, implement the smallest fix, verify, and log the prevention artifact.
5. When a useful fix is too broad for safe code changes, create the smallest concrete prototype, draft plan, characterization test, grep check, or harness checklist that names the owner surface and next verification command. This counts as progress; do not block on asking the user to pick the surface.
6. Execute required prevention artifacts when they are clear; consider proposed artifacts when they fit the task. If they are code/test/skill/automation work, keep the TDD/review gate.
7. Use subagents for independent implementation, review, or verification work when there are disjoint files or clearly separable questions.
8. Ask the user only for true product choices, such as whether a warning should block an action, whether a behavior should change, or which business priority wins. Do not ask the user to choose routine test targets, owner files, or implementation sequence when the evidence makes one path obviously useful.
9. Leave broad code, architecture, product decisions, global docs, ambiguous evidence, or cross-caller behavior changes for dashboard review only after recording the clearest next prototype or testable slice.
10. Append plain-English audit lines to `docs/learnings/auto-actions.md`.
11. Regenerate the dashboard and report execution results grouped by outcome: executed, prototyped, verified, and needs product decision.

If the user says `done` in a dashboard/triage thread, run the executor immediately against the current repo, append a same-day audit marker, and skip the scheduled 9pm executor for that repo.

Weekly review can summarize the daily work, but daily maintenance is the default while calibration is young.

## Canonical Files

- `docs/learnings/inbox.md` - raw and active learnings.
- `docs/learnings/candidates.md` - reviewed/promoted candidate prevention work.
- `docs/learnings/dashboard.md` and `docs/learnings/dashboard.html` - generated review surfaces.
- `docs/learnings/calibration.md` - user taste about abstraction, automation, artifact choice, and wording.
- `docs/learnings/auto-actions.md` - audit trail for automation and executor actions.
- `.agents/skills/learn/SKILL.md` - capture front door.
- `.agents/skills/dashboard/SKILL.md` - review front door.
- `.agents/skills/learn-init/SKILL.md` - initialization front door.
- global `learn` command - hidden glue for safe file operations and dashboard serving; implemented by dotfiles `bin/learn`, invoked with `--repo <repo>`.

## Verification

- `python3 -m pytest setup/tests/test_learn_cli.py -q`
- `.agents/skills/learn/tests/structural-check.sh`
