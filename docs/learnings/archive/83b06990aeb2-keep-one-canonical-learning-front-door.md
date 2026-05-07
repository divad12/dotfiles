# Archived Learning

### 83b06990aeb2-keep-one-canonical-learning-front-door
- Fingerprint: 83b06990aeb2
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Keep one canonical learning front door
- Evidence: You pointed out that an old capture wrapper and a repo-local README were both duplicating /learn behavior — and duplicate docs always drift apart over time.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, docs/learnings/README.md
- Ramification: When the setup feels like a CLI toolkit with parallel docs, you stop trusting it as a product.
- Suspected pattern: Unknown
- Recommended fix: Move useful capture reasoning into /learn and docs/ai/learning-system.md; keep repo-local READMEs as pointer-only files.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: capture reasoning lives in /learn and docs/ai/learning-system.md; docs/learnings/README is pointer-only.
- Status: archived
