# Archived Learning

### 23031c089efa-multi-cwd-automations-must-be-repo-scoped-per-run
- Fingerprint: 23031c089efa
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Multi-cwd automations must be repo-scoped per run
- Evidence: User noted that Codex spawns one executor per cwd, so the Journology executor should not inspect or report on dotfiles.
- Technical refs: /Users/david/.codex/automations/daily-learning-executor/automation.toml, /Users/david/.codex/automations/daily-learning-triage/automation.toml, docs/ai/learning-system.md
- Ramification: A repo-scoped automation becomes noisy and may hit sandbox/write failures if each run loops across sibling configured repos.
- Suspected pattern: Unknown
- Recommended fix: Automation prompts and contracts should state that each cron invocation operates only on its current working directory and must not touch sibling configured repos.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: repo-scoped automation is already in triage/executor prompts and structural check; cluster: workflow guarantees must be wired and verified
- Status: archived
