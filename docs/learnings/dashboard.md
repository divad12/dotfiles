# Learning Dashboard

## inbox.md

# Learning Inbox
### 071d9b93b060-dashboard-cards-need-action-status--not-raw-audit-logs
- Fingerprint: 071d9b93b060
- Sources: user-feedback
- Captured: 2026-05-07
- Source events: None
- Scope: global
- User-facing summary: Dashboard cards need action status, not raw audit logs
- Evidence: You were reviewing Journology learn live and the Shared counts/CSV cards showed Previous decisions full of old triage/follow-up notes while hiding the Executor note that said what automation actually completed.
- Technical refs: bin/learn, setup/tests/test_learn_cli.py, docs/ai/learning-system.md
- Ramification: If dashboard cards show log history instead of Done/Next/Blocked, you cannot tell whether automation already acted, what remains, or whether you need to unblock anything.
- Suspected pattern: Review surfaces should summarize current action state from evidence instead of exposing internal workflow logs.
- Recommended fix: Render decision, follow-up, draft, and executor notes as Action status buckets: What changed, Next, Blocked, and Notes. Keep raw audit wording out of the primary card copy.
- Prevention artifacts: test (required), docs (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox


## candidates.md

# Learning Candidates

