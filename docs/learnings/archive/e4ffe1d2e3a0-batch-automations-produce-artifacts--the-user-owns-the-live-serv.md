# Archived Learning

### e4ffe1d2e3a0-batch-automations-produce-artifacts--the-user-owns-the-live-serv
- Fingerprint: e4ffe1d2e3a0
- Sources: agent-discovery
- Captured: 2026-05-06
- Source events: None
- Scope: project
- User-facing summary: Batch automations produce artifacts; the user owns the live server
- Evidence: The daily learning triage used to call learn dashboard --serve, but Codex's sandbox blocks binding 127.0.0.1, so every cron run spat 'live server could not start' before falling back to the static HTML. The clean split landed in this branch: automations regenerate dashboard.md and dashboard.html, and the user runs learn live in a terminal tab when they want to review.
- Technical refs: docs/ai/learning-system.md, .codex/automations/daily-learning-triage/automation.toml
- Ramification: When a batch automation tries to spin up an interactive surface, either the sandbox refuses and you get a confusing fallback, or the cron job holds open a process nobody is going to use — and the daily report turns into noise you have to read past to find the real status.
- Suspected pattern: Unknown
- Recommended fix: Keep automation prompts file-only. End each report with a one-liner pointing at the user-owned interactive command (e.g. learn live). Audit other batch automations (daily-bug-scan, update-docs) for the same anti-pattern.
- Prevention artifacts: docs (required), automation (proposed)
- Confidence: high
- Decision note: Done: the learning docs, learn skill, triage prompt, executor prompt, and structural check now keep cron automations file-only; the live dashboard stays user-owned through learn live.
- Status: archived
