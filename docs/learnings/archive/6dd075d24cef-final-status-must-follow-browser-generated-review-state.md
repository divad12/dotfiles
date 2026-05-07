# Archived Learning

### 6dd075d24cef-final-status-must-follow-browser-generated-review-state
- Fingerprint: 6dd075d24cef
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Final status must follow browser-generated review state
- Evidence: A Journology merge session saw the review server/browser write another comment JSON change after the cleaned docs commit.
- Technical refs: docs/ai/git.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: The target branch can land without the latest review textarea or comment state even though the agent believed the docs commit was clean.
- Suspected pattern: Unknown
- Recommended fix: After browser or review-server tools finish, re-run git status before the final commit or target advance and fold generated review state into the right commit.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: final git status after browser/review-server state is already in git docs and structural check; cluster: landing state must include generated review state
- Status: archived
