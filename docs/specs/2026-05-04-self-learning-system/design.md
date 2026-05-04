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
- `capture-learning` has the right abstraction ladder, but needs stricter evidence, destination, and enforcement gates.
- Superpowers Optimized, Reflexion, Voyager, ClawMem, and memory-backed agent systems all validate parts of the idea: raw memory, reflection, reusable skills, decay, and retrieval. The first version should stay file-first and git-native because the hard problem here is routing and judgment, not storage.

## Scope

Version 0 creates a project-local learning loop, with dotfiles/global promotion only when a learning changes agent behavior across projects.

In scope:

- a repo-local `docs/learnings/` store;
- structured inbox entries with plain-English decision support;
- promotion and archive flow;
- dashboard markdown and generated HTML;
- calibration records from user feedback;
- commit/merge/review/QA checkpoints;
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
- Source: QA | review | bugfix | agent-discovery | user-feedback | failed-command
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
3. **Promotion Engine**: reads inbox and calibration, dedupes related entries, classifies the learning, chooses a destination, and either drafts or applies a low-risk change.
4. **Dashboard Generator**: produces `dashboard.md` and `dashboard.html` from canonical files. The HTML is a scan/review/calibration surface, not canonical storage.
5. **Decision Executor**: reads dashboard decisions and notes, then archives, revises, promotes, defers, asks a question, or creates a TDD/review task.
6. **Calibration Memory**: stores user feedback about abstraction level, artifact placement, autonomy, rejected promotions, and preferred wording.

Capture can be noisy. Promotion must be careful.

## Data Flow

1. A learning-worthy event happens: QA finding, review comment, bugfix, failed command, agent discovery, user correction, or repeated confusion.
2. A capture adapter writes a structured inbox entry with plain-English summary, evidence, ramification, recommended fix, technical refs, candidate artifact, confidence, and status.
3. The promotion engine clusters and classifies inbox entries as one-off, repeated bug class, architecture gap, tooling gotcha, agent-system improvement, or global candidate.
4. The promotion engine chooses an action: archive, ask for review, update candidates, draft a test, update a small doc line, edit a skill, add a nested guardrail, add a lint/grep check, or propose architecture work.
5. The autonomy gate decides whether to auto-apply or route to review.
6. The dashboard surfaces decisions in plain English.
7. The user approves, revises, changes artifact target, asks a question, archives, defers, changes confidence, or adds calibration.
8. The decision executor acts on the dashboard decision.
9. The auto-action log records exactly what changed and why.
10. The learning entry points to its prevention artifact or archive reason.

An entry can promote to multiple artifacts, but one artifact should be marked primary so the system does not keep reopening the same issue.

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

Each visible item leads with what the user sees, loses, feels, or risks. Technical refs are expandable. The HTML can record local decisions such as approve, revise, archive, defer, change confidence, add note, or ask agent. The decision executor applies those decisions to the canonical learning files.

## Invocation

The primary checkpoints are not `/save`, because that workflow fell out of use when it only updated `PROGRESS.md`.

Preferred invocation points:

- QA, review, deep-review, and bugfix closeout;
- before commit;
- before merge or landing;
- task-observer when it notices durable agent/user workflow patterns;
- failed-command capture when the command lesson is project-relevant;
- weekly dashboard automation;
- an optional manual command such as `/learn` or `/learning-dashboard`.

Before commit and merge, the learning check should ask whether any new bug/review finding needs a prevention artifact before landing. The user-facing ramification is that bugs do not quietly land with only a chat memory of why they happened.

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

For version 0, it may automatically edit learning files and low-risk docs. Code changes must go through the code path below.

## Code Path

Any decision that creates or changes code must follow TDD and review.

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
- A code-related decision creates a TDD/review task rather than silently editing code.
- The always-loaded docs stay tiny.

## Open Design Choices For Implementation Planning

- Exact file format: markdown-only, markdown with embedded YAML, or JSONL plus generated markdown.
- Whether `dashboard.html` is a static generated file, a tiny local app, or both.
- How dashboard decisions are recorded for the executor: JSONL events, markdown notes, or form submissions to a local helper.
- Whether the first repo implementation starts in Journology, dotfiles, or both.
- Which checkpoint to implement first: review closeout, before commit, before merge, or weekly dashboard.
