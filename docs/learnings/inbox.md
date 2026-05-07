# Learning Inbox

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
- Status: inbox
### 02b34308afad-successful-learning-automations-must-not-leave-branches-dirty
- Fingerprint: 02b34308afad
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Successful learning automations must not leave branches dirty
- Evidence: The Journology daily learning automations wrote docs/learnings and docs guidance directly to the m3 branch without committing, leaving the integration branch dirty after the scheduled run.
- Technical refs: docs/ai/learning-system.md, .codex/automations/daily-learning-triage/automation.toml, .codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: The user has to manually clean up after supposedly hands-off automation, and later agents may mix automation output with unrelated session changes.
- Suspected pattern: Unknown
- Recommended fix: Daily automations should check git status before writing, stop on unrelated pre-existing dirt, verify their own changes, and create one local no-push commit when successful.
- Prevention artifacts: automation (required), docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
