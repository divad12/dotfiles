# Archived Learning

### 08c2d3bc8cf3-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: 08c2d3bc8cf3
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: The daily learning automation prompts were still pointing at /Users/david/.codex/worktrees/20dc/dotfiles even after the work had landed on master — they were reading from a feature worktree that could disappear.
- Technical refs: None
- Ramification: Scheduled runs end up following stale or vanished feature-worktree instructions instead of the canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout, and treat repo-local docs as cwd-specific supplements only.
- Prevention artifacts: docs (required)
- Confidence: medium
- Decision note: Done: both automations read /Users/david/Dropbox (Personal)/code/dotfiles/docs/ai/learning-system.md (the master worktree path).
- Status: archived
