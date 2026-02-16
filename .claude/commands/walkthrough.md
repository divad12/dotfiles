---
description: Walk through all code changes this session with inline commentary
allowed-tools: Bash(git:*)
---

## Context

- Recent commits: !`git log --oneline -10`
- Current branch: !`git branch --show-current`
- Staged changes: !`git diff --cached --stat`
- Unstaged changes: !`git diff --stat`
- Untracked files: !`git ls-files --others --exclude-standard`
- Full committed diff: !`git diff HEAD~${1:-1}`
- Full uncommitted diff: !`git diff`
- Staged diff: !`git diff --cached`

## Instructions

Walk me through every change above.

**For each diff chunk or new file:**

1. Show the file path as a header
2. Show the relevant hunk
3. Immediately follow with commentary:
   - **What & why** — what this change does and what motivated it
   - **How** — mechanism, data flow, design patterns used
   - **Perf** — complexity, potential bottlenecks, indexing concerns (only if relevant to this chunk)
   - **Security** — auth, validation, injection, data exposure (only if relevant to this chunk)
   - **Watch out** — anything subtle, any trade-off, any smell, anything you'd flag in PR review

Only include Perf and Security lines when there's actually something to say. Don't pad.

Group related changes across files if that tells a clearer story than going file-by-file.

**After all chunks, wrap up with:**

- **Schema / API surface changes** — migrations, new endpoints, changed contracts
- **Patterns & architecture** — design patterns introduced or changed, how new code fits into the existing structure
- **Open questions** — things you weren't sure about, places I might disagree
- **Rough edges** — TODOs, incomplete work, known jank
- **Next** — what to build from here

If $ARGUMENTS is provided, use it as the commit range (e.g. `/walkthrough HEAD~3` to review the last 3 commits). Default is any uncommitted work, or if none, last commit.
