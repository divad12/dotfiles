# Archived Learning

### 08c2d3bc8cf3-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: 08c2d3bc8cf3
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: Daily learning automation prompts were still reading the global learning-system contract from /Users/david/.codex/worktrees/20dc/dotfiles even after the work was being landed to master.
- Technical refs: None
- Ramification: Scheduled runs can follow stale or disappearing feature-worktree instructions instead of the current canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout and use repo-local docs only as cwd-specific supplements.
- Prevention artifacts: docs (required)
- Confidence: medium
- Decision note: triage 2026-05-06: duplicate of b1ade9e50ec0 with less complete refs; merged as duplicate evidence into canonical-doc-path cluster
- Status: archived
