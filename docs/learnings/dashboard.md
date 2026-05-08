# Learning Dashboard

## inbox.md

# Learning Inbox

### 8d3cf8846396-don-t-put-backslash-escapes-inside-f-string-expressions
- Fingerprint: 8d3cf8846396
- Sources: agent-discovery
- Captured: 2026-05-06
- Source events: None
- Scope: project
- User-facing summary: Don't put backslash escapes inside f-string expressions
- Evidence: While rewriting render_dashboard_html, an inline fallback like {value or "<span class=\"muted\">…</span>"} inside an f-string tripped Python 3.11's 'f-string expression part cannot include a backslash' rule and bin/learn stopped importing — the dashboard couldn't regenerate at all until the syntax was traced and fixed.
- Technical refs: bin/learn
- Ramification: If a backslash-escaped quote sneaks into a {...} part of an f-string, Python 3.11+ refuses to import the file. The dashboard stops regenerating, learn live won't boot, and the daily automations write empty reports until you read the SyntaxError and fix it.
- Suspected pattern: Unknown
- Recommended fix: Compute fallback HTML in a regular variable above the f-string, then drop the variable name inside {...}. Keep the {} expression part free of backslash escapes.
- Prevention artifacts: docs (proposed)
- Confidence: high
- Status: inbox
### e4ffe1d2e3a0-batch-automations-produce-artifacts--the-user-owns-the-live-serv
- Fingerprint: e4ffe1d2e3a0
- Sources: agent-discovery
- Captured: 2026-05-06
- Source events: None
- Scope: project
- User-facing summary: Batch automations produce artifacts; the user owns the live server
- Evidence: The daily learning triage used to call learn dashboard --serve, but Codex's sandbox blocks binding 127.0.0.1, so every cron run spat 'live server could not start' before falling back to the static HTML. The clean split landed in this branch: automations regenerate dashboard.md and dashboard.html, and the user runs learn live in a terminal tab when they want to review.
- Technical refs: docs/ai/learning-system.md, .codex/automations/daily-learning-triage/automation.toml
- Ramification: When a batch automation tries to spin up an interactive surface, either the sandbox refuses and you get a confusing fallback, or the cron job holds open a process nobody is going to use — and the daily report turns into noise you have to read past to find the real status.
- Suspected pattern: Unknown
- Recommended fix: Keep automation prompts file-only. End each report with a one-liner pointing at the user-owned interactive command (e.g. learn live). Audit other batch automations (daily-bug-scan, update-docs) for the same anti-pattern.
- Prevention artifacts: docs (required), automation (proposed)
- Confidence: high
- Follow-up task: Draft plan requested: Prototype executor parity: add a failing structural check that the executor prompt says not to serve a live dashboard, then add the file-only dashboard sentence to the canonical/live executor automation. Blocked this run because sandbox denied writes to .agents and .codex files.
- Draft plan: drafts/e4ffe1d2e3a0-plan.md
- Status: inbox
### 88d602ab001f-automation-reports-need-context--not-corporate-shorthand
- Fingerprint: 88d602ab001f
- Sources: user-feedback
- Captured: 2026-05-07
- Source events: None
- Scope: project
- User-facing summary: Automation reports need context, not corporate shorthand
- Evidence: You showed a daily executor report that said things like 'Added the shared-count/source-boundary rule to optimistic-architecture.md' and said it was too dry to understand after context-switching. The useful version explains the idea first, like making every UI counter use the same shared calculation, then uses the technical label only as a receipt.
- Technical refs: .claude/AGENTS.md, docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, .codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the daily automation reports only list terse file changes, you have to reverse-engineer what happened instead of quickly seeing whether the system helped and whether anything needs your decision.
- Suspected pattern: Unknown
- Recommended fix: Make automation reports friendly plain-English summaries that explain the problem, the change, why it matters, where it landed, and what was verified before listing technical receipts.
- Prevention artifacts: docs (required), automation (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox


## candidates.md

# Learning Candidates

