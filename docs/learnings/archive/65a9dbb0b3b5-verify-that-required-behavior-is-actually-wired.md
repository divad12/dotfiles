# Archived Learning

### 65a9dbb0b3b5-verify-that-required-behavior-is-actually-wired
- Fingerprint: 65a9dbb0b3b5
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Verify that required behavior is actually wired
- Evidence: User asked whether triage and executor actually read the learning-system doc and explicitly apply the abstraction ladder, revealing that "should do X" language is not enough unless the system is checked for actual wiring.
- Technical refs: /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: Users cannot trust a system when agents say it should behave a certain way but no prompt, hook, test, automation, or structural check makes that behavior happen.
- Suspected pattern: Claims about expected behavior drift from actual wiring.
- Recommended fix: When a workflow depends on a behavior, verify the actual trigger, prompt, hook, test, or structural check that enforces it; add one if it is missing.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: already covered by automation prompts plus structural check; cluster: workflow guarantees must be wired and verified
- Status: archived
