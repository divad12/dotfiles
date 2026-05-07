# Archived Learning

### 053992e19e3d-prevention-plans-usually-need-more-than-one-artifact
- Fingerprint: 053992e19e3d
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Prevention plans usually need more than one artifact
- Evidence: Journology candidates kept showing prevention plans that needed more than one piece — a test plus docs, or a helper plus a test. You also clarified you wanted one readable list with required/proposed markers, not separate primary/secondary fields.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, setup/tests/test_learn_cli.py
- Ramification: If the system reads only one prevention artifact, an agent can auto-promote a docs-shaped entry and silently skip the test, helper, skill, or automation work that actually prevents the bug from coming back.
- Suspected pattern: Unknown
- Recommended fix: Store Prevention artifacts as one list with explicit required/proposed markers, and gate any required code-risk artifact behind TDD/review.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: bin/learn stores prevention work as one list with required/proposed markers; learning-system.md and learn SKILL teach the same shape.
- Status: archived
