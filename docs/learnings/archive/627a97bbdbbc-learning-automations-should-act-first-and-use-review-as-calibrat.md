# Archived Learning

### 627a97bbdbbc-learning-automations-should-act-first-and-use-review-as-calibrat
- Fingerprint: 627a97bbdbbc
- Sources: user-feedback
- Captured: 2026-05-07
- Source events: None
- Scope: agent-system
- User-facing summary: Learning automations should act first and use review as calibration
- Evidence: You said you don't have time to process a massive learning dashboard every day. You want the automations to use their judgment, make the clear changes, and tell you what happened so you can calibrate later.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, .codex/automations/daily-learning-triage/automation.toml, .codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the learning system waits on daily human review, it turns into another chore and stops being the hands-off product you asked for.
- Suspected pattern: Unknown
- Recommended fix: Make daily triage and executor act by default, cluster from sample-backed evidence, commit successful changes locally, and ask only for true product decisions or risky/blocked work.
- Prevention artifacts: automation (required), docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: docs, learn skill, executor prompt, and structural check now require act-by-default/autopick behavior, local commits, and true-product-choice escalation only.
- Status: archived
