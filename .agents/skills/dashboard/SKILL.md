---
name: dashboard
description: "Use when the user says '/dashboard', 'open the learning dashboard', 'show learning dashboard', or wants to review project learnings."
user-invocable: true
argument-hint: "[optional repo path]"
---

# Dashboard

Read `docs/ai/learning-system.md`, then open the repo's learning dashboard as the review control center.

Use the served finish loop by default:

```bash
learn --repo "$PWD" dashboard --serve --execute-on-finish --host 127.0.0.1 --port 0
```

Open the URL in the available browser tool when possible; otherwise give the user the URL. Wait for them to review, and when they click Finish or say they are done, make sure decisions are executed, regenerate the dashboard, and summarize what changed.

If this dashboard was opened by daily triage and the user says `done`, run the executor phase immediately for the relevant repo, append a same-day `manual-executor-ran: YYYY-MM-DD` audit marker to `docs/learnings/auto-actions.md`, and tell the user the scheduled 9pm executor can skip that repo.

Do not expose lower-level CLI verbs unless the user asks for internals.
