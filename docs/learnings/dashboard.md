# Learning Dashboard

## inbox.md

# Learning Inbox

### 04e0529e5585-verify-that-required-behavior-is-actually-wired
- Fingerprint: 04e0529e5585
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Verify that required behavior is actually wired
- Evidence: You asked whether triage and executor actually read the learning-system doc and apply the abstraction ladder, surfacing that "should do X" in prose is empty unless something concrete enforces it.
- Technical refs: /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If we say a behavior is required but no prompt, hook, test, automation, or structural check makes it happen, you can't trust the system to do what we promise.
- Suspected pattern: Claims about expected behavior drift from actual wiring.
- Recommended fix: When a workflow depends on a behavior, point at the trigger, prompt, hook, test, or structural check that enforces it — and add one if it's missing.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 8d3cf8846396-don-t-put-backslash-escapes-inside-f-string-expressions
- Fingerprint: 8d3cf8846396
- Sources: agent-discovery
- Captured: 2026-05-06
- Source events: None
- Scope: project
- User-facing summary: Don't put backslash escapes inside f-string expressions
- Evidence: While rewriting render_dashboard_html, an inline fallback like {value or "<span class=\"muted\">…</span>"} inside an f-string tripped Python 3.11's 'f-string expression part cannot include a backslash' rule and bin/learn stopped importing — the dashboard couldn't regenerate at all until the syntax was traced and fixed.
- Technical refs: bin/learn
- Ramification: If a backslash-escaped quote sneaks into a {...} part of an f-string, Python 3.11+ refuses to import the file. The dashboard stops regenerating, learn live won't boot, and the daily automations write empty reports until you read the SyntaxError and fix it.
- Suspected pattern: Unknown
- Recommended fix: Compute fallback HTML in a regular variable above the f-string, then drop the variable name inside {...}. Keep the {} expression part free of backslash escapes.
- Prevention artifacts: docs (proposed)
- Confidence: high
- Status: inbox
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
- Status: inbox
### 627a97bbdbbc-learning-automations-should-act-first-and-use-review-as-calibrat
- Fingerprint: 627a97bbdbbc
- Sources: user-feedback
- Captured: 2026-05-07
- Source events: None
- Scope: agent-system
- User-facing summary: Learning automations should act first and use review as calibration
- Evidence: You said you don't have time to process a massive learning dashboard every day. You want the automations to use their judgment, make the clear changes, and tell you what happened so you can calibrate later.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, .codex/automations/daily-learning-triage/automation.toml, .codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the learning system waits on daily human review, it turns into another chore and stops being the hands-off product you asked for.
- Suspected pattern: Unknown
- Recommended fix: Make daily triage and executor act by default, cluster from sample-backed evidence, commit successful changes locally, and ask only for true product decisions or risky/blocked work.
- Prevention artifacts: automation (required), docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox


## candidates.md

# Learning Candidates

