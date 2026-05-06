# Self-Learning Project System Design

## Purpose

Build a lightweight project learning system that captures QA findings, review findings, bug reports, agent discoveries, failed-command gotchas, and user feedback, then turns the durable parts into prevention artifacts. The system should recover the useful parts of the old long `PROGRESS.md` habit without making every future session load a giant notebook.

The design optimizes for three outcomes:

- preserve raw evidence before it is forgotten;
- keep always-loaded context small and high-signal;
- make repeated mistakes harder to recreate through tests, lint checks, shared helpers, skills, nested `AGENTS.md` files, small docs, code comments, or automation.

## Prior Art

The system borrows ideas rather than adopting a full external stack.

- Journology's historical `PROGRESS.md` proved that close-to-the-work problem-solution notes are valuable, but it mixed durable lessons with status bookkeeping.
- Journology's M3 shakedown loop proved a stronger shape: symptom -> root cause -> pattern -> enforcement. Its limitation is that it is scoped to one bug-bash program.
- `task-observer` already captures durable user/agent workflow patterns, but its centralized log can grow into another backlog unless project learnings route into the repo and get promoted or archived.
- The older capture workflow had the right abstraction ladder, but often stayed too close to the specific incident. `/learn` now owns that ladder with stricter evidence, destination, enforcement, and "climb higher" gates.
- Superpowers Optimized, Reflexion, Voyager, ClawMem, and memory-backed agent systems all validate parts of the idea: raw memory, reflection, reusable skills, decay, and retrieval. The first version should stay file-first and git-native because the hard problem here is routing and judgment, not storage.

## Scope

Version 0 creates a project-local learning loop, with dotfiles/global promotion only when a learning changes agent behavior across projects.

In scope:

- a repo-local `docs/learnings/` store;
- structured inbox entries with plain-English decision support;
- promotion and archive flow;
- dashboard markdown and generated HTML;
- calibration records from user feedback;
- review/QA closeout and commit/merge checkpoints;
- an explicit `/learn` workflow that owns all capture triggers and abstraction logic;
- conservative auto-promotion for low-risk, high-confidence actions;
- TDD and review requirements for any code-producing decision.

Out of scope for version 0:

- vector memory as the canonical store;
- fully autonomous architecture changes;
- global docs or root `AGENTS.md` edits without explicit review;
- treating the HTML dashboard as the source of truth.

## Core Principle

Capture broadly, promote sparingly, enforce aggressively.

Raw evidence is allowed to be noisy because it lives in cold storage. Hot context and automatic changes must be curated. A learning is not resolved until it is either archived as non-durable or attached to a prevention artifact.

## Product Experience Correction — 2026-05-05

The user-facing system should feel hands-off and productized, not like a CLI toolkit. Normal users should only need three front doors:

- `/learn` — capture a durable learning in the current repo through an agentic workflow.
- `/dashboard` — open the review dashboard for the current repo, let the user review, then execute the approved actions when they finish.
- `/learn-init` — initialize the learning system in a new repo. This may also be called by adaptive-docs initialization when a project opts into project learnings.

Everything else is implementation detail. Binaries may exist for safe file writes, dashboard serving, and structured glue, but the reasoning loop should be agentic: agents read evidence, cluster findings into durable patterns, apply calibration, update markdown/docs/skills/tests when safe, and leave review-required changes as explicit follow-up tasks.

The default cadence should be automation-first:

- Daily agentic maintenance sweeps every participating repo with `docs/learnings/`.
- Triage runs around 5pm and surfaces a live dashboard/app link for review.
- Executor runs around 9pm, unless the user says `done` after triage and executor runs immediately.
- Early usage should bias toward daily user review until enough calibration exists.
- The daily sweep should cluster new learnings, merge duplicate evidence, archive obvious non-durable entries, update low-risk docs, and implement focused high-clarity prevention artifacts when it can do so with TDD and verification.
- Daily work should be split into a triage automation and an executor automation. Triage clusters and prepares actions; executor acts only on high-confidence, narrow work.
- Executor automation should use subagents when there are independent implementation, review, or verification slices with disjoint file ownership.
- Risky code, broad architecture, shared skills, global instructions, or uncertain product decisions stay review-required.
- Weekly review remains useful as a digest, but it is not the only automation.

The dashboard is the control center. The user should be able to review visually, click Finish, or tell the agent "done" / "I'm done processing now." The system should then run the safe executor path immediately, write a same-day executor audit marker, skip the scheduled 9pm executor for that repo, regenerate the dashboard, and report what changed.

## Storage And Routing

Each participating project owns its learning store:

```text
docs/learnings/
  inbox.md
  candidates.md
  dashboard.md
  dashboard.html
  calibration.md
  auto-actions.md
  archive/
```

Project-specific QA bugs, review findings, testing commands, cache gotchas, and codebase patterns stay in the project repo. Agent-system behavior, skill failures, hook improvements, and capture workflow issues go to dotfiles. Cross-project principles become global candidates only after repeated evidence or a clearly universal rule.

The routing rule is:

> If the lesson would still matter after cloning this repo on another machine, keep it in the project. If it changes how agents should behave everywhere, promote it to dotfiles. If it is only personal preference or transient state, keep it cold or archive it.

## Learning Entry Contract

Every dashboard-facing entry must help the user make a decision while context-switching. Plain English is mandatory.

```md
### 2026-05-04-short-title
- Sources: QA | review | bugfix | agent-discovery | user-feedback | failed-command | before-merge | task-observer | learn
- Source events: Session, PR, commit, command, screenshot, review pass, or dashboard decision identifiers when available.
- Scope: project | dotfiles | global-candidate
- User-facing summary: Plain-English one-liner for scanning.
- Evidence: Plain-English description of what happened.
- Technical refs: File names, functions, tests, logs, screenshots, PR comments.
- Ramification: What the user sees, loses, feels, or risks.
- Suspected pattern: The reusable mistake class, if known.
- Recommended fix: One-line proposed action.
- Candidate artifact: test | lint | helper | skill | docs | nested-AGENTS | automation | archive
- Confidence: low | medium | high
- Status: inbox | candidate | promoted | archived | blocked | needs-evidence
```

Technical jargon is allowed in `Technical refs`, but `User-facing summary`, `Evidence`, `Ramification`, and `Recommended fix` must be scan-friendly plain English.

## Architecture

The system has six parts.

1. **Learning Store**: project-local markdown files are canonical. They hold raw evidence, candidates, calibration, dashboard summaries, auto-action logs, and archives.
2. **Capture Adapters**: existing workflows append entries from QA, deep review, bugfixes, failed commands, task-observer, merge checks, git checks, and user notes.
3. **Promotion Engine**: reads inbox and calibration, dedupes related entries, classifies the learning, chooses a destination, and emits a proposed action or low-risk auto-action request. It does not directly mutate code or durable guidance.
4. **Dashboard Generator**: produces `dashboard.md` and `dashboard.html` from canonical files. The HTML is a scan/review/calibration surface, not canonical storage.
5. **Decision Executor**: executes both dashboard decisions and approved/eligible promotion-engine requests, then archives, revises, promotes, defers, asks a question, updates docs/skills, or creates a TDD/review task.
6. **Calibration Memory**: stores user feedback about abstraction level, artifact placement, autonomy, rejected promotions, and preferred wording.

Capture can be noisy. Promotion must be careful. Execution must be disciplined: the same executor rules apply whether an action came from the promotion engine, the dashboard, a cron, or a manual `/learn` session.

## Data Flow

1. A learning-worthy event happens: QA finding, review comment, bugfix, failed command, agent discovery, user correction, or repeated confusion.
2. A capture adapter proposes a structured inbox entry with plain-English summary, evidence, ramification, recommended fix, technical refs, candidate artifact, confidence, and status.
3. The capture layer checks for an existing matching entry before writing. If task-observer, `/learn`, review closeout, and merge checks all notice the same issue, they should update one entry's `Sources` and evidence trail instead of creating parallel entries.
4. The promotion engine clusters and classifies inbox entries as one-off, repeated bug class, architecture gap, tooling gotcha, agent-system improvement, or global candidate.
5. The promotion engine chooses an action: archive, ask for review, update candidates, add or update a skill, draft a test, update a small doc line, add a nested guardrail, add a lint/grep check, or propose architecture work.
6. The autonomy gate decides whether to hand the action to the decision executor automatically or route it to review.
7. The dashboard surfaces decisions in plain English.
8. The user approves, revises, changes artifact target, asks a question, archives, defers, changes confidence, or adds calibration.
9. The decision executor acts on saved dashboard decisions or eligible auto-action requests.
10. The auto-action log records exactly what changed and why.
11. The learning entry points to its prevention artifact or archive reason.

An entry can promote to multiple artifacts, but one artifact should be marked primary so the system does not keep reopening the same issue.

### Idempotency And Dedupe

Overlapping capture is expected. A single session may include task-observer notes, an explicit `/learn` capture, review closeout, failed-command capture, and a before-merge check. Those sources should not create five user-facing dashboard rows for the same problem.

Each proposed learning gets a stable fingerprint from its plain-English summary, suspected pattern, technical refs, and source event when available. Before appending, the capture layer searches active inbox, candidates, promoted entries, and recent archives for the same fingerprint or a close match.

If it finds a match, it updates the existing entry:

- add the new source to `Sources`;
- append new evidence or technical refs;
- raise confidence only when the new evidence is stronger;
- preserve the original user-facing summary unless the new entry is clearer;
- record a short audit note such as "also seen during before-merge check."

If the match is plausible but not certain, the system links the entries as possible duplicates and surfaces one dashboard row with expandable related evidence. It should not silently delete evidence.

## Trust And Autonomy

The system starts conservative and earns autonomy in narrow lanes.

- **Level 0: Capture only.** Always allowed. Raw evidence goes into cold storage.
- **Level 1: Draft proposal.** The system proposes a pattern and destination for review.
- **Level 2: Auto-promote low-risk.** Allowed for obvious archive/dedupe, command gotchas, tiny project-local notes, and status updates.
- **Level 3: Auto-enforce with log.** After calibration, allowed for focused tests, lint checks, nested guardrails, or skill tweaks in known lanes.
- **Level 4: Review-required.** Architecture changes, global instructions, root `AGENTS.md`, broad docs, or behavior changes across callers need explicit review.

Every auto-action is logged in `auto-actions.md` and summarized in the dashboard. Rejected or revised actions update calibration so future passes learn the user's taste.

## Dashboard

The dashboard has two outputs:

- `dashboard.md` for git-native review;
- `dashboard.html` for interactive scanning, expansion, notes, and decisions.

The dashboard should show:

- needs review;
- auto-done;
- raw inbox count;
- candidates;
- aging/stale items;
- likely duplicates;
- calibration learned;
- blocked decisions;
- ask-agent prompts.

Each visible item leads with what the user sees, loses, feels, or risks. Technical refs, raw notes, logs, screenshots, previous decisions, and other captured details are expandable even when they are not shown in the summary row. The primary human review surface is interactive: the dashboard should let the user record notes and decisions in the same place they review the item. The decision executor applies saved decisions to the canonical learning files.

Static generated views are still useful as read-only snapshots for git diffs, automation artifacts, and environments where no local server is running. They are not sufficient for normal dashboard review because the user needs a way to capture notes, calibration, and decisions while scanning.

### Dashboard Invocation And Execution

The dashboard can reach the user through two main paths:

- **Manual session:** the user starts a session and says `/learn dashboard`, `/dashboard`, or "open the learning dashboard." The agent generates or opens the interactive dashboard, waits for decisions, then runs the decision executor in the same session unless the user says to only review.
- **Daily triage automation:** a scheduled run clusters new evidence, merges duplicate entries, archives obvious non-durable items, prepares candidate actions, writes `auto-actions.md`, and updates the dashboard.
- **Daily executor automation:** a later scheduled run executes high-confidence narrow actions, updates low-risk docs, performs focused TDD-backed tests/lint/helper/skill guardrails, writes `auto-actions.md`, and updates the dashboard. If the user records dashboard decisions, the executor applies safe decisions and leaves risky items as follow-ups.

Review closeout and before-merge checks can also invoke a focused dashboard view filtered to the current branch/session. After the user records decisions, the default behavior is to run the executor immediately for learning-file updates and low-risk docs, then create TDD/review tasks for code, skill, enforcement, or architecture changes.

## Invocation

The primary checkpoints are not `/save`, because that workflow fell out of use when it only updated `PROGRESS.md`.

Preferred invocation points:

- QA, review, deep-review, and bugfix closeout;
- before commit;
- before merge or landing;
- task-observer when it notices durable agent/user workflow patterns;
- failed-command capture when the command lesson is project-relevant;
- daily triage and executor automations;
- an optional manual command such as `/learn` or `/learning-dashboard`.

Before commit and merge, the learning check should ask whether any new bug/review finding needs a prevention artifact before landing. The user-facing ramification is that bugs do not quietly land with only a chat memory of why they happened.

### Checkpoint Enforcement

Version 0 enforces checkpoints through skills and docs before adding hard shell hooks.

- Review, deep-review, QA, and bugfix skills add a closeout step that writes or confirms learning entries for durable findings.
- Merge and git guidance add a before-landing learning check. The check should surface unresolved high-confidence learnings and ask whether a prevention artifact is required before landing.
- The optional `/learn` workflow can be run manually when the user says "capture this", "learn this", "open the learning dashboard", or "what did we learn?"
- Daily triage automation updates the dashboard and auto-action log. It summarizes and proposes; it does not block work.
- Daily executor automation performs safe high-confidence actions after triage. It must follow TDD/review for any code, test, helper, skill, or enforcement change and leave broad or risky work for dashboard review.
- Optional repo hooks can come later for teams or projects that want hard blocking. Hooks should call a small script and print plain-English ramifications, not dump raw markdown.

The first implementation should include review closeout and before-merge checks. Before-commit checks are desirable, but should not block version 0 if review/merge capture is already working.

### `/learn` And Task Observer Boundary

`/learn` is the only explicit capture workflow. Older capture trigger phrases such as "document this", "capture this", "remember this for next time", and "update the docs" route directly to `/learn`; no separate compatibility skill should remain. `/learn` captures raw evidence, climbs the abstraction ladder, proposes a candidate artifact, opens the dashboard, and can run the promotion/execution loop.

`task-observer` remains the ambient session observer. It should capture durable agent/user workflow observations and route them to the same learning store when they are project-specific, or to dotfiles when they improve the agent system. It should not become the only learning interface, and `/learn` should not replace the observer's quiet background role.

Adding or modifying a skill is a valid candidate artifact. It is appropriate when the prevention needs activation behavior or repeated workflow guidance rather than a project doc line, test, lint rule, or code helper.

## Decision Executor

The decision executor turns dashboard decisions into action. It can:

- update learning files;
- archive or dedupe entries;
- revise wording;
- change artifact target;
- append calibration;
- create a follow-up task;
- start an agent answer using the relevant evidence;
- draft a patch;
- create a code-change plan.

For version 0, it may automatically edit learning files and low-risk docs. It can be invoked three ways:

- **Current session:** the user or a skill says to execute selected dashboard decisions.
- **Automation:** daily triage and executor jobs handle allowed low-risk actions and write dashboard/audit logs.
- **Delegated worker/subagent:** for approved code or broader docs work, the current agent can dispatch a bounded task with the normal TDD/review contract.

Code changes, shared skill changes, and architecture changes must go through the code path below even when the promotion engine labels them high confidence.

## Code Path

Any decision that creates or changes code must follow TDD and review. Shared skill changes and enforcement scripts should follow the same discipline where applicable: write or update the structural check first, make the smallest change, then verify.

1. Reproduce or specify the failure. For a bug or QA finding, write the failing test from the user-visible behavior first. For a guardrail, write the contract test, lint check, or grep check first.
2. Implement the smallest architectural fix. Prefer shared helpers, types, lint rules, tests, and contract checks over prose.
3. Self-review whether the fix makes the mistake harder to repeat, preserves existing behavior, and links the learning entry to the prevention artifact.
4. Escalate review by risk. Use local/self-review for focused fixes, normal review for shared code or broad behavior, and deep-review for architecture, cross-module contracts, optimistic/cache behavior, data model, or user-facing workflows.
5. Run focused tests and the project's standard verification command.
6. Mark the learning promoted/resolved only after tests and required review pass.

The learning system may orchestrate code fixes, but it cannot bypass TDD or review by writing code silently.

## Error Handling

- If the system cannot decide where a learning belongs, keep it in needs review.
- If a likely duplicate appears, link entries before deleting or archiving.
- If an auto-promotion is rejected, record calibration and revert or supersede through a normal change.
- If evidence is weak or unreproducible, mark it `needs-evidence` with plain-English uncertainty.
- If a dashboard decision cannot be executed safely, write a blocked entry with the reason and the user decision needed.
- If learning files grow too large, archive raw entries and keep dashboard/candidate summaries bounded.
- If calibration conflicts, prefer newer explicit user feedback and flag the contradiction.
- If a promotion touches global docs or architecture, require review.

## Testing And Quality Gates

The learning system itself should have tests or checks.

- Schema/format checks require plain-English summary, evidence, ramification, recommended fix, candidate artifact, confidence, and status.
- Routing checks verify that sample QA bugs go project-local, agent behavior goes to dotfiles, and universal principles become global candidates.
- Dedupe checks verify that task-observer, `/learn`, review closeout, and merge capture for the same event update one entry instead of creating duplicate dashboard rows.
- Promotion checks verify that noisy evidence can become a candidate, but cannot become hot context without a destination and confidence.
- Dashboard checks verify that markdown and HTML include needs-review, auto-done, calibration, and expanded technical refs.
- Decision executor checks verify approve, archive, revise, defer, confidence change, and calibration notes update canonical files correctly.
- Autonomy checks verify low-risk auto-promotions are allowed while global, architecture, and code changes require review.
- Code-decision checks require a failing test or contract check before implementation.
- Review-ladder checks require self-review or deep-review markers before resolving shared, architecture, data, cache, or user-facing changes.
- Bloat checks keep hot summaries bounded and archive raw entries by age or count.
- Plain-English checks reject dashboard-facing entries whose summary or ramification is only jargon.

## Version 0 Acceptance Criteria

- A QA finding can be captured in Journology with plain-English evidence and recommended fix.
- A promotion pass can turn an inbox entry into a candidate or archive it.
- A low-risk learning can auto-promote and be logged.
- A risky learning appears in the dashboard for review.
- A dashboard decision can be executed against canonical learning files.
- Duplicate capture sources for one issue merge into a single dashboard item with multiple sources and expandable evidence.
- A code-related decision creates a TDD/review task rather than silently editing code.
- The always-loaded docs stay tiny.

## Open Design Choices For Implementation Planning

- Exact file format: markdown-only, markdown with embedded YAML, or JSONL plus generated markdown.
- The dashboard should be interactive by default. Static markdown/HTML remains a read-only snapshot for diffs, automation artifacts, and no-server environments.
- How dashboard decisions are recorded for the executor: JSONL events, markdown notes, or form submissions to a local helper.
- The first implementation should cover both dotfiles and Journology: dotfiles owns the global skill/checkpoint machinery, and Journology exercises the project-local learning store.
- Checkpoint order: implement review closeout and before-merge first, then before-commit checks and the split daily triage/executor automations once the core loop works.
