# Archived Learning

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
- Decision note: Done: global AGENTS guidance, learning docs, learn skill, triage/executor prompts, and structural checks now require context-rich friendly plain-English reports instead of terse technical bullets.
- Status: archived
