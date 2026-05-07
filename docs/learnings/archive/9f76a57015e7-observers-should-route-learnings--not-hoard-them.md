# Archived Learning

### 9f76a57015e7-observers-should-route-learnings--not-hoard-them
- Fingerprint: 9f76a57015e7
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Observers should route learnings, not hoard them
- Evidence: You asked whether a different Journology session would remember to capture learnings if only the /learn skill header mentioned the triggers — and whether task-observer's old observation log is still pulling its weight now that durable learnings route through the learning system.
- Technical refs: .agents/skills/task-observer/SKILL.md, .agents/skills/learn/SKILL.md, .claude/AGENTS.md
- Ramification: If the ambient observer keeps its own backlog instead of routing through /learn, durable feedback ends up split across two stores or lost entirely.
- Suspected pattern: Ambient sensors drift into parallel memory systems.
- Recommended fix: Keep task-observer as the trigger and sensor, route durable learnings through /learn into docs/learnings/, and use observation files only as session audit fallback.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: Done: task-observer SKILL declares the learning store is the durable destination and routes through /learn; observation files are fallback only.
- Status: archived
