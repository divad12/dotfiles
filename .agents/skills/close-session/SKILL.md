---
name: close-session
description: "Use when the user asks to close, end, clean up, tear down, or finish a worktree/session after work is landed."
user-invocable: true
---

# Close Session

Close the current worktree after confirming its work is merged. This skill is a
narrow git cleanup only; it does not write summaries or clean runtime state.

## Prerequisites

You must be inside a worktree, not the target repo/worktree. If you're already
in the target repo, tell the user there's nothing to close.

## Steps

### 1. Gather session info

Set `TARGET_BRANCH` to the branch being landed into, then run this to collect
the worktree and merge-safety details:
```bash
WORKTREE_PATH=$(git rev-parse --show-toplevel) && \
BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
git worktree list && \
TARGET_BRANCH="<target branch>" && \
TARGET_REPO=$(git worktree list | awk -v target="[$TARGET_BRANCH]" 'index($0, target) {print $1; exit}') && \
test -n "$TARGET_REPO" && \
UNCOMMITTED=$(git status --porcelain) && \
echo "WORKTREE_PATH=$WORKTREE_PATH" && \
echo "BRANCH=$BRANCH" && \
echo "TARGET_BRANCH=$TARGET_BRANCH" && \
echo "TARGET_REPO=$TARGET_REPO" && \
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

### 3. Tell the user, then tear down

Report what will happen: branch name and worktree path.

Then run the teardown as one bash command:

```bash
TARGET_REPO="<absolute path>" && \
WORKTREE_PATH="<absolute path>" && \
BRANCH="<branch name>" && \
cd "$TARGET_REPO" && \
git worktree remove "$WORKTREE_PATH" --force && \
git branch -d "$BRANCH" && \
echo "SESSION_CLOSED"
```

Substitute the actual values collected in step 1. Use `-d` (not `-D`) so git refuses if unmerged.

**CRITICAL: This is the absolute last action. After running this command:**
- **DO NOT run any more bash commands.** The original CWD no longer exists. Shell errors like `shell-init: error retrieving current directory` are **expected and harmless**.
- **DO NOT try to verify** the branch was deleted or the worktree was removed.
- **DO NOT try to "fix" CWD errors** by cd-ing, using absolute paths, or spawning shells.
- Just tell the user "Session closed" and **stop completely**.

## Rules

- **Do not write session files.** Closeout notes belong in the conversation or a user-requested artifact, not automatic teardown.
- **Do not manage port files.** Port assignment belongs to `new-session`; close-session must not create, edit, or remove port metadata.
- **Only remove the git worktree and branch.** Do not kill dev-server ports, delete screenshots, or clean incidental runtime artifacts.
- **Never delete unmerged work.** The merge check in step 2 is the safety gate.
- **Never use `-D` (force delete).** Always `-d` so git validates the merge.
- **Minimize bash calls.** Steps 1 and 3 should each be one bash command.
