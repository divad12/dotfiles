---
name: close-session
description: "Use when the user asks to close, end, clean up, tear down, or finish a worktree/session after work is landed."
user-invocable: true
---

# Close Session

Cleanly shut down the current worktree session. Ensures work is merged into the
target branch before removing anything.

## Prerequisites

You must be inside a worktree, not the target repo/worktree. If you're already
in the target repo, tell the user there's nothing to close.

## Steps

### 1. Gather session info (single command)

Set `TARGET_BRANCH` to the branch being landed into, then run this to collect
everything needed for the session file and teardown:
```bash
WORKTREE_PATH=$(git rev-parse --show-toplevel) && \
BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
git worktree list && \
TARGET_BRANCH="<target branch>" && \
TARGET_REPO=$(git worktree list | awk -v target="[$TARGET_BRANCH]" 'index($0, target) {print $1; exit}') && \
test -n "$TARGET_REPO" && \
PORT=$(grep -o '"port": [0-9]*' .claude/launch.json 2>/dev/null | head -1 | grep -o '[0-9]*') && \
UNCOMMITTED=$(git status --porcelain) && \
echo "WORKTREE_PATH=$WORKTREE_PATH" && \
echo "BRANCH=$BRANCH" && \
echo "TARGET_BRANCH=$TARGET_BRANCH" && \
echo "TARGET_REPO=$TARGET_REPO" && \
echo "PORT=$PORT" && \
echo "UNCOMMITTED=$UNCOMMITTED" && \
if [ "$WORKTREE_PATH" = "$TARGET_REPO" ]; then echo "ERROR: You are in the target repo, not a worktree."; exit 1; fi && \
if [ -n "$UNCOMMITTED" ]; then echo "WARNING: Uncommitted changes exist"; fi && \
git log "$TARGET_BRANCH"..$BRANCH --oneline 2>/dev/null && \
echo "---FILES---" && \
git diff --name-only "$TARGET_BRANCH"..$BRANCH 2>/dev/null
```

If the target branch is unclear, ask the user. If you're in the target repo,
stop. If there are uncommitted changes, ask the user what to do.

### 2. Ensure work is merged into the target

```bash
git -C "$TARGET_REPO" merge-base --is-ancestor "$BRANCH" "$TARGET_BRANCH"
```
If this fails (exit code non-zero), run the `/merge` skill first. Wait for it to complete.

### 3. Write the session file (MANDATORY)

This is the most important step. Use the **Write tool** to create a session file at `$TARGET_REPO/.claude/sessions/<descriptive-name>.md`.

**File naming:** Name the file based on what the session actually did, NOT the branch name. Use kebab-case. Examples:
- `horizontal-designer-gantt-bars.md` (not `claude-objective-kilby.md`)
- `venue-duration-override-feature-flag.md` (not `claude-keen-darwin.md`)
- `fix-cascade-timing-on-delete.md` (not `claude-amazing-turing.md`)

Include:
- **Date** - today's date
- **Branch** - the branch name
- **Summary** - what was worked on (1-3 sentences)
- **Key changes** - bullet list of primary additions/changes/fixes
- **Commits** - from step 1's git log output
- **Decisions and rationale** - every notable decision, what was chosen over what, and why
- **Discussion context** - user feedback, rejected approaches, "we tried X but it didn't work because Y"
- **Gotchas** - edge cases, surprising behaviors, things that look wrong but are intentional
- **Unfinished / follow-up** - incomplete work, pre-existing issues discovered
- **Files touched** - from step 1's git diff output

Be generous with detail in Decisions and Discussion - these prevent future sessions from re-debating.

After writing, verify with `ls -la "$TARGET_REPO/.claude/sessions/<BRANCH_SLUG>.md"`.

### 4. Tell the user, then tear down (single command)

Report what will happen: branch name, worktree path, port being freed.

Then run the **entire teardown as one bash command**:

```bash
TARGET_REPO="<absolute path>" && \
WORKTREE_PATH="<absolute path>" && \
BRANCH="<branch name>" && \
PORT="<port number>" && \
(lsof -ti:$PORT 2>/dev/null | xargs kill 2>/dev/null; true) && \
rm -rf "$WORKTREE_PATH/.playwright-mcp" && \
find "$WORKTREE_PATH" -maxdepth 1 -name '*.png' -delete 2>/dev/null; \
cd "$TARGET_REPO" && \
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
