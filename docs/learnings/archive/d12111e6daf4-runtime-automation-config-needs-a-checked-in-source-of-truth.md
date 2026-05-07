# Archived Learning

### d12111e6daf4-runtime-automation-config-needs-a-checked-in-source-of-truth
- Fingerprint: d12111e6daf4
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: project
- User-facing summary: Runtime automation config needs a checked-in source of truth
- Evidence: User asked whether the live daily learning executor and triage automation.toml files under ~/.codex/automations were checked into dotfiles or should be symlinked. The live files were local-only plain files, so prompt fixes could drift or disappear outside this machine.
- Technical refs: /Users/david/.codex/automations/daily-learning-executor/automation.toml, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/Dropbox (Personal)/code/dotfiles/.codex/automations/daily-learning-executor/automation.toml, /Users/david/Dropbox (Personal)/code/dotfiles/symlink.sh, /Users/david/Dropbox (Personal)/code/dotfiles/.agents/skills/learn/tests/structural-check.sh
- Ramification: The scheduled learning system can quietly regress after setup, machine migration, or local edits, and the user cannot trust that corrected automation behavior will persist.
- Suspected pattern: Unknown
- Recommended fix: Keep canonical automation.toml files in dotfiles, symlink the live ~/.codex/automations files to them via symlink.sh, and verify the wiring with structural checks.
- Prevention artifacts: automation (required), test (required), docs (proposed)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: .codex/automations/*.toml are tracked in dotfiles, symlink.sh wires ~/.codex/automations -> dotfiles, and structural-check.sh verifies the prompts.
- Status: archived
