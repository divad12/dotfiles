# Archived Learning

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
- Decision note: Done: both triage and executor automation.toml now run git diff --check + create one local commit + 'do not leave a successful run dirty'.
- Status: archived
