# Archived Learning

### 9681e329c380-learning-glue-must-work-everywhere---global--not-repo-local
- Fingerprint: 9681e329c380
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Learning glue must work everywhere — global, not repo-local
- Evidence: During a Journology merge, a session reported that bin/learn was missing, so it couldn't run the before-landing learning checkpoint at all.
- Technical refs: docs/ai/git.md, .agents/skills/learn/SKILL.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the learn command isn't global, you can land branches in repos that have docs/learnings but no copy of the binary — silently skipping the checkpoint.
- Suspected pattern: Unknown
- Recommended fix: Always invoke the global learn command with --repo, and structurally guard the merge docs against assuming a repo-local bin/learn exists.
- Prevention artifacts: docs (required), test (required), skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: learn is on PATH; merge skill, git.md, and learn SKILL all use 'learn --repo "$PWD"' rather than repo-local bin/learn.
- Status: archived
