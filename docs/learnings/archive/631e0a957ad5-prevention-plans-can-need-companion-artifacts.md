# Archived Learning

### 631e0a957ad5-prevention-plans-can-need-companion-artifacts
- Fingerprint: 631e0a957ad5
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Prevention plans can need companion artifacts
- Evidence: Journology candidates showed prevention plans often need more than one artifact, such as a test plus docs or a helper plus test.
- Additional evidence: User clarified that the system should store one readable prevention artifact list with required/proposed markers instead of primary and secondary fields.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, setup/tests/test_learn_cli.py
- Ramification: Agents can auto-promote a docs-looking entry while skipping the test, helper, skill, or automation work that actually prevents the bug.
- Suspected pattern: Unknown
- Recommended fix: Store Prevention artifacts as one list with required/proposed markers and apply TDD/review gates to required code-risk artifacts.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: readable required/proposed prevention artifact list is already in docs, skill, and structural check; cluster: prevention artifacts as enforceable contracts
- Status: archived
