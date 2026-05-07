# Archived Learning

### 00e184061921-learning-glue-must-be-global-across-repos
- Fingerprint: 00e184061921
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Learning glue must be global across repos
- Evidence: A Journology merge session reported that bin/learn was missing, so it could not run the before-landing learning checkpoint.
- Technical refs: docs/ai/git.md, .agents/skills/learn/SKILL.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: Agents can land branches without the learning checkpoint in repos that have docs/learnings but do not carry the hidden CLI binary.
- Suspected pattern: Unknown
- Recommended fix: Invoke the global learn command with --repo and structurally guard merge docs against repo-local bin/learn assumptions.
- Prevention artifacts: docs (required), test (required), skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: global learn --repo glue is already in git/learning docs, learn skill, and structural check; cluster: productized learning front door
- Status: archived
