# Archived Learning

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
- Decision note: Done: the learning structural check now runs python3 -m py_compile bin/learn, so syntax mistakes like backslash escapes inside f-string expressions fail before the dashboard glue ships.
- Status: archived
