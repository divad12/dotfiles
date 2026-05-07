# Archived Learning

### 83b06990aeb2-keep-one-canonical-learning-front-door
- Fingerprint: 83b06990aeb2
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Keep one canonical learning front door
- Evidence: User questioned why an old capture wrapper and repo-local README duplicated /learn behavior and warned that duplicate docs drift.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, docs/learnings/README.md
- Ramification: Users have to reason about multiple learning surfaces and lose trust when the setup feels like a command-line toolkit instead of a product.
- Suspected pattern: Unknown
- Recommended fix: Move useful capture reasoning into /learn and the canonical learning-system guide; keep repo-local READMEs pointer-only.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: already covered by canonical /learn front-door contract, pointer-only README, and structural check; cluster: productized learning front door
- Status: archived
