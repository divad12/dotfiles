---
name: close-session
description: "Tear down the current worktree session: merge into main, stop the dev server, delete the branch and worktree folder. Use when the user says 'close session', 'end session', 'clean up', 'tear down', or 'done with this worktree'."
user-invocable: true
---

# Close Session

Cleanly shut down the current worktree session. Ensures work is merged into main before removing anything.

## Prerequisites

You must be inside a worktree (not the main repo). If you're in the main repo, tell the user there's nothing to close.

## Steps

### 1. Gather session info (single command)

Run this to collect everything needed for the session file and teardown:
```bash
WORKTREE_PATH=$(git rev-parse --show-toplevel) && \
MAIN_REPO=$(git worktree list | grep '\[main\]' | awk '{print $1}') && \
BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
PORT=$(grep -o '"port": [0-9]*' .claude/launch.json 2>/dev/null | head -1 | grep -o '[0-9]*') && \
UNCOMMITTED=$(git status --porcelain) && \
echo "WORKTREE_PATH=$WORKTREE_PATH" && \
echo "MAIN_REPO=$MAIN_REPO" && \
echo "BRANCH=$BRANCH" && \
echo "PORT=$PORT" && \
echo "UNCOMMITTED=$UNCOMMITTED" && \
if [ "$WORKTREE_PATH" = "$MAIN_REPO" ]; then echo "ERROR: You are in the main repo, not a worktree."; exit 1; fi && \
if [ -n "$UNCOMMITTED" ]; then echo "WARNING: Uncommitted changes exist"; fi && \
git log main..$BRANCH --oneline 2>/dev/null && \
echo "---FILES---" && \
git diff --name-only main..$BRANCH 2>/dev/null
```

If you're in the main repo, stop. If there are uncommitted changes, ask the user what to do.

### 2. Ensure work is merged into main

```bash
git -C "$MAIN_REPO" merge-base --is-ancestor "$BRANCH" main
```
If this fails (exit code non-zero), run the `/merge` skill first. Wait for it to complete.

### 3. Write the session file (MANDATORY)

This is the most important step. Use the **Write tool** to create `$MAIN_REPO/.claude/sessions/<BRANCH_SLUG>.md` (replace `/` with `-` in branch name).

Include:
- **Date** - today's date
- **Branch** - the branch name
- **Summary** - what was worked on (1-3 sentences)
- **Key changes** - bullet list of main additions/changes/fixes
- **Commits** - from step 1's git log output
- **Decisions and rationale** - every notable decision, what was chosen over what, and why
- **Discussion context** - user feedback, rejected approaches, "we tried X but it didn't work because Y"
- **Gotchas** - edge cases, surprising behaviors, things that look wrong but are intentional
- **Unfinished / follow-up** - incomplete work, pre-existing issues discovered
- **Files touched** - from step 1's git diff output

Be generous with detail in Decisions and Discussion - these prevent future sessions from re-debating.

After writing, verify with `ls -la "$MAIN_REPO/.claude/sessions/<BRANCH_SLUG>.md"`.

### 4. Tell the user, then tear down (single command)

Report what will happen: branch name, worktree path, port being freed.

Then run the **entire teardown as one bash command**:

```bash
MAIN_REPO="<absolute path>" && \
WORKTREE_PATH="<absolute path>" && \
BRANCH="<branch name>" && \
PORT="<port number>" && \
(lsof -ti:$PORT 2>/dev/null | xargs kill 2>/dev/null; true) && \
rm -f "$MAIN_REPO/.claude/ports/$PORT" && \
cd "$MAIN_REPO" && \
git worktree remove "$WORKTREE_PATH" --force && \
git branch -d "$BRANCH" 2>/dev/null; \
echo "SESSION_CLOSED"
```

Substitute the actual values collected in step 1. Use `-d` (not `-D`) so git refuses if unmerged.

**CRITICAL: This is the absolute last action. After running this command:**
- **DO NOT run any more bash commands.** The original CWD no longer exists. Shell errors like `shell-init: error retrieving current directory` are **expected and harmless**.
- **DO NOT try to verify** the branch was deleted or the worktree was removed.
- **DO NOT try to "fix" CWD errors** by cd-ing, using absolute paths, or spawning shells.
- Just tell the user "Session closed" and **stop completely**.

## Rules

- **Always write the session file.** Step 3 is not optional. If you reach step 4 without it, go back.
- **Never delete unmerged work.** The merge check in step 2 is the safety gate.
- **Never use `-D` (force delete).** Always `-d` so git validates the merge.
- **Don't kill Prisma Studio** (port 5555). Only kill the worktree's dev server port.
- **Minimize bash calls.** Steps 1 and 4 should each be ONE bash command. Only the session file write (step 3) uses a different tool.
