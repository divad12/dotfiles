# Draft Plan

- Fingerprint: e4ffe1d2e3a0
- User-facing summary: Batch automations produce artifacts; the user owns the live server
- Evidence: The daily learning triage used to call learn dashboard --serve, but Codex's sandbox blocks binding 127.0.0.1, so every cron run spat 'live server could not start' before falling back to the static HTML. The clean split landed in this branch: automations regenerate dashboard.md and dashboard.html, and the user runs learn live in a terminal tab when they want to review.
- Ramification: When a batch automation tries to spin up an interactive surface, either the sandbox refuses and you get a confusing fallback, or the cron job holds open a process nobody is going to use — and the daily report turns into noise you have to read past to find the real status.
- Recommended fix: Keep automation prompts file-only. End each report with a one-liner pointing at the user-owned interactive command (e.g. learn live). Audit other batch automations (daily-bug-scan, update-docs) for the same anti-pattern.
- Technical refs: docs/ai/learning-system.md, .codex/automations/daily-learning-triage/automation.toml
- Prevention artifacts: docs (required), automation (proposed)
- Dashboard note: Prototype executor parity: add a failing structural check that the executor prompt says not to serve a live dashboard, then add the file-only dashboard sentence to the canonical/live executor automation. Blocked this run because sandbox denied writes to .agents and .codex files.

