---
name: learn-init
description: "Use when the user says '/learn-init', 'initialize learnings', 'set up the learning system', or wants to add project learnings to a repo."
user-invocable: true
argument-hint: "[optional repo path]"
---

# Learn Init

Read `docs/ai/learning-system.md`, then initialize the repo-local learning store.

Use the CLI only as setup glue:

```bash
learn --repo "$PWD" learn-init
learn --repo "$PWD" dashboard
```

Tell the user the three front doors: `/learn` captures, `/dashboard` reviews, and `/learn-init` initializes. If this is part of adaptive docs setup, keep the learning system optional but recommended for repos with recurring QA/review findings.
