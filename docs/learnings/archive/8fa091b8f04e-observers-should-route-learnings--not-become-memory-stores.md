# Archived Learning

### 8fa091b8f04e-ambient-capture-belongs-in-the-observer--not-the-destination-ski
- Fingerprint: 8fa091b8f04e
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Observers should route learnings, not become memory stores
- Evidence: User asked whether a different Journology session would remember to capture learnings if only the /learn skill header mentioned capture triggers.
- Additional evidence: User questioned whether task-observer's old observation log is still useful now that durable learnings should route through the learning system.
- Technical refs: .agents/skills/task-observer/SKILL.md, .agents/skills/learn/SKILL.md, .claude/AGENTS.md
- Ramification: Durable feedback can be missed or split across two backlogs when the ambient observer keeps its own memory instead of routing to the learning store.
- Suspected pattern: Ambient sensors drift into parallel memory systems.
- Recommended fix: Keep task-observer as the trigger/sensor, route durable learnings through /learn, and use observation files only as fallback or session audit notes.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Decision note: triage 2026-05-06: task-observer now routes durable learnings to the learning store and reserves observations for fallback; cluster: observer as sensor
- Status: archived
