# Archived Learning

### 29b7632b5c3b-learning-automations-should-work-around-baseline-dirt
- Fingerprint: 29b7632b5c3b
- Sources: user-feedback
- Captured: 2026-05-07
- Source events: None
- Scope: agent-system
- User-facing summary: Learning automations should work around baseline dirt
- Evidence: You clarified that your repos will often have dirty files, so daily automations should not stop just because the checkout is dirty. They should leave pre-existing dirty files untouched, do non-overlapping work, and commit only their own changes.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, .codex/automations/daily-learning-triage/automation.toml, .codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the automation stops on normal local dirt, the hands-off workflow stalls; if it stages the dirt, it can accidentally commit unrelated work you were still editing.
- Suspected pattern: Unknown
- Recommended fix: Snapshot baseline dirty paths, avoid touching or staging them, fix verification failures caused by automation changes, and commit the clean automation-owned delta.
- Prevention artifacts: automation (required), docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: docs, learn skill, triage/executor prompts, and structural check now require baseline dirty snapshots, untouched baseline paths, and staging only automation-owned changes.
- Status: archived
