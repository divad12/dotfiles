# Archived Learning

### b27c9463bf75-multi-cwd-automations-must-stay-in-their-own-repo-per-run
- Fingerprint: b27c9463bf75
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Multi-cwd automations must stay in their own repo per run
- Evidence: You noticed Codex spawns one executor per cwd, which means the Journology executor shouldn't be inspecting or reporting on dotfiles — but the prompts didn't say so.
- Technical refs: /Users/david/.codex/automations/daily-learning-executor/automation.toml, /Users/david/.codex/automations/daily-learning-triage/automation.toml, docs/ai/learning-system.md
- Ramification: Without explicit scoping, a repo-scoped automation gets noisy and can hit sandbox or write failures when one run reaches into sibling configured repos.
- Suspected pattern: Unknown
- Recommended fix: State in the automation prompts and contracts that each cron invocation operates only on its own current working directory — never on sibling configured repos.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: both automation TOMLs say 'operate on the current working directory only' and refuse to touch sibling configured repos.
- Status: archived
