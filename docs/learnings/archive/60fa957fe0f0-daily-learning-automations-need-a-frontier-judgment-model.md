# Archived Learning

### 60fa957fe0f0-daily-learning-automations-need-a-frontier-judgment-model
- Fingerprint: 60fa957fe0f0
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily learning automations need a frontier judgment model
- Evidence: You noticed daily learning automations were defaulting to gpt-5.2, which isn't strong enough to cluster, abstract, weigh safety, and calibrate across many learnings.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: A weak parent model misclusters evidence, auto-executes the wrong prevention work, or misses when a decision needed your eyes on it.
- Suspected pattern: Unknown
- Recommended fix: Run daily triage and executor parents on gpt-5.5 with high reasoning; only fall back to focused coding models like gpt-5.3-codex for bounded subagents the executor dispatches.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: both automations run on gpt-5.5 with reasoning_effort = high.
- Status: archived
