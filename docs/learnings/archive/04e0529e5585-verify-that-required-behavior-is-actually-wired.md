# Archived Learning

### 04e0529e5585-verify-that-required-behavior-is-actually-wired
- Fingerprint: 04e0529e5585
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Verify that required behavior is actually wired
- Evidence: You asked whether triage and executor actually read the learning-system doc and apply the abstraction ladder, surfacing that "should do X" in prose is empty unless something concrete enforces it.
- Technical refs: /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If we say a behavior is required but no prompt, hook, test, automation, or structural check makes it happen, you can't trust the system to do what we promise.
- Suspected pattern: Claims about expected behavior drift from actual wiring.
- Recommended fix: When a workflow depends on a behavior, point at the trigger, prompt, hook, test, or structural check that enforces it — and add one if it's missing.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: required learning-system wiring is enforced by canonical docs, live automation prompts, and the learn structural check; remaining executor dashboard-serving parity is tracked as a draft plan.
- Status: archived
