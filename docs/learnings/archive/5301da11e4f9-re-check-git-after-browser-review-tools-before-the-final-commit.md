# Archived Learning

### 5301da11e4f9-re-check-git-after-browser-review-tools-before-the-final-commit
- Fingerprint: 5301da11e4f9
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Re-check git after browser/review tools before the final commit
- Evidence: During a Journology merge the review server/browser wrote another comment-JSON change after the commit you thought was the final clean docs one.
- Technical refs: docs/ai/git.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: If we don't re-check, the target branch can land without the latest review-comment state — the agent believes everything is captured, but it isn't.
- Suspected pattern: Unknown
- Recommended fix: After any browser or review-server tool runs, re-run git status before the final commit or branch advance, and fold any generated review state into the right commit.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: docs/ai/git.md 'Before-Landing Learning Check' explicitly requires re-running git status --short after browser/review-server tools.
- Status: archived
