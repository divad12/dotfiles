# Archived Learning

### bd3fb5f75282-don-t-dress-fingerprints-up-as-semantic-judgment
- Fingerprint: bd3fb5f75282
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Don't dress fingerprints up as semantic judgment
- Evidence: You pointed out that exact fingerprint matching almost never dedupes probabilistic agent wording — real duplicate detection and clustering need agent judgment, not a hash.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, bin/learn
- Ramification: If the docs sell fingerprints as semantic dedupe, you'll trust dead plumbing and miss that the real work happens during agentic triage.
- Suspected pattern: Unknown
- Recommended fix: Treat fingerprints as row IDs and exact-replay guards only; make the docs, tests, and automation prompts say semantic dedupe and clustering belong to the agent.
- Prevention artifacts: docs (required)
- Confidence: high
- Decision note: Done: learning-system.md and learn SKILL both say fingerprint matching is row-id only and semantic dedupe is agent-owned.
- Status: archived
