# Archived Learning

### f25da97943c6-learning-automation-parents-need-frontier-judgment-models
- Fingerprint: f25da97943c6
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Learning automation parents need frontier judgment models
- Evidence: User noted that daily learning automations were defaulting to gpt-5.2, which is too weak for clustering, abstraction, safety, and calibration decisions across many learnings.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: A weaker parent model can miscluster evidence, auto-execute the wrong prevention work, or miss when a decision needs human review.
- Suspected pattern: Unknown
- Recommended fix: Run daily learning triage and executor parents on gpt-5.5 high reasoning while using focused coding models such as gpt-5.3-codex only for bounded executor-dispatched subagents.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: triage and executor configs now use gpt-5.5 high reasoning and docs cover parent/subagent model policy; cluster: judgment-heavy automation model policy
- Status: archived
