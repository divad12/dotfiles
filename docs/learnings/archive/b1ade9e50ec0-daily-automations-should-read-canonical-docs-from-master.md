# Archived Learning

### b1ade9e50ec0-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: b1ade9e50ec0
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: Daily learning automation prompts were still reading the global learning-system contract from /Users/david/.codex/worktrees/20dc/dotfiles even after the work was being landed to master.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: Scheduled runs can follow stale or disappearing feature-worktree instructions instead of the current canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout and use repo-local docs only as cwd-specific supplements.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: canonical durable master checkout path is already in automation prompts and structural check; cluster: workflow guarantees must be wired and verified
- Additional evidence: Duplicate lower-confidence row 08c2d3bc8cf3 captured the same worktree-to-master canonical-doc-path incident without the later technical refs.
- Status: archived
