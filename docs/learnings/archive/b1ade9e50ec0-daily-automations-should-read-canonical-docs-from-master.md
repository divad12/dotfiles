# Archived Learning

### b1ade9e50ec0-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: b1ade9e50ec0
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: The daily learning automation prompts were still pointing at /Users/david/.codex/worktrees/20dc/dotfiles even after the work had landed on master — they were reading from a feature worktree that could disappear.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: Scheduled runs end up following stale or vanished feature-worktree instructions instead of the canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout, and treat repo-local docs as cwd-specific supplements only.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: duplicate of 08c2d3bc8cf3 — same prevention now in place via the master-path automation prompts.
- Status: archived
