# Archived Learning

### 755a268f4869-do-not-present-deterministic-ids-as-semantic-judgment
- Fingerprint: 755a268f4869
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Do not present deterministic IDs as semantic judgment
- Evidence: User pointed out that exact fingerprint matching will almost never dedupe probabilistic agent wording; meaningful duplicate detection and clustering require agent judgment.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, bin/learn
- Ramification: Users may trust dead plumbing and miss that the real system behavior depends on agentic triage.
- Suspected pattern: Unknown
- Recommended fix: Use fingerprints only as row IDs and exact replay guards; make docs, tests, and automation prompts state that semantic dedupe/clustering is agent-owned.
- Prevention artifacts: docs (required)
- Confidence: high
- Decision note: triage 2026-05-06: semantic dedupe vs fingerprint identity is already stated in docs and skill contract; cluster: agent-owned clustering
- Status: archived
