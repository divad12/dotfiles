---
name: merge
description: "Rebase the current branch onto main, resolve any conflicts, then fast-forward main to the latest commit. Use when the user says 'merge', 'merge into main', or 'land this'."
allowed-tools: Bash(git:*)
user-invocable: true
---

# Merge Workflow

Rebase the current branch onto main and fast-forward main to include the new commits.

## Steps

1. **Identify context**: Determine the current branch name and the main repo path.
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   MAIN_REPO=$(git worktree list | grep '\[main\]' | awk '{print $1}')
   ```

2. **Fetch latest main**:
   ```bash
   git fetch origin main
   ```

3. **Rebase onto main**:
   ```bash
   git rebase origin/main
   ```
   - If there are conflicts, resolve them file by file, then `git add <file>` and `git rebase --continue`.
   - Never use `git merge`. Always rebase.

4. **Fast-forward main** to the current branch tip:
   ```bash
   git -C "$MAIN_REPO" merge --ff-only "$BRANCH"
   ```

5. **Verify** both branches point to the same commit:
   ```bash
   echo "Current branch ($BRANCH): $(git rev-parse HEAD)"
   echo "Main: $(git -C "$MAIN_REPO" rev-parse HEAD)"
   ```
   Both should match.

6. **Report** the result: which commits were added, any conflicts resolved, final commit hash.

## Rules

- **Never create merge commits.** Always rebase, never `git merge` (except `--ff-only` to advance main).
- **Resolve conflicts interactively.** If a rebase conflict occurs, show the user what conflicted and fix it. Don't abort unless explicitly asked.
- **Don't push** unless the user explicitly asks. Just update local branches.
