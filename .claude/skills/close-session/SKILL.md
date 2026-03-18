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

1. **Confirm you're in a worktree.**
   ```bash
   WORKTREE_PATH=$(git rev-parse --show-toplevel)
   MAIN_REPO=$(git worktree list | grep '\[main\]' | awk '{print $1}')
   ```
   If `WORKTREE_PATH` equals `MAIN_REPO`, you're in the main repo. Stop and tell the user.

2. **Capture the branch name and worktree path** before doing anything destructive:
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   ```

3. **Check for uncommitted changes.**
   ```bash
   git status --porcelain
   ```
   If there are uncommitted changes, stop and ask the user what to do. Don't silently discard work.

4. **Ensure work is merged into main.**
   Check if main already points to the same commit (or a descendant):
   ```bash
   git -C "$MAIN_REPO" merge-base --is-ancestor "$BRANCH" main
   ```
   - If this succeeds (exit code 0), main already contains all the worktree's commits. Skip to step 5.
   - If it fails, the work hasn't been merged yet. Run the `/merge` skill to rebase onto main and fast-forward. Wait for it to complete before continuing.

5. **Save session context.**
   Write a summary of this session to the main repo's `.claude/sessions/` directory so the context can be picked up later if needed. The file should be named after the branch (e.g., `claude-jovial-mayer.md`).
   ```bash
   mkdir -p "$MAIN_REPO/.claude/sessions"
   ```
   Write the file to `$MAIN_REPO/.claude/sessions/<BRANCH_SLUG>.md` (replace `/` with `-` in the branch name). Include:
   - **Date** - today's date
   - **Branch** - the branch name
   - **Summary** - what was worked on this session (1-3 sentences)
   - **Key changes** - bullet list of the main things that were added, changed, or fixed
   - **Commits** - list of commits on this branch (from `git log main..<BRANCH> --oneline`)
   - **Decisions and rationale** - every notable decision made during the session. Include what was chosen, what alternatives were considered, and why. These are the most valuable part of the session file - they prevent future sessions from re-debating resolved questions.
   - **Discussion context** - important back-and-forth from the conversation that informed the implementation. User feedback, rejected approaches, "we tried X but it didn't work because Y", stakeholder input. This is the nuance that gets lost if you only capture the final result.
   - **Gotchas and non-obvious things** - anything a future developer (or Claude session) touching this code would benefit from knowing. Edge cases discovered, surprising behaviors, things that look wrong but are intentional.
   - **Unfinished / follow-up** - anything that was started but not completed, pre-existing issues discovered, next steps discussed
   - **Files touched** - list of files added or significantly modified (from `git diff --name-only main..<BRANCH>`)

   Pull this from the conversation context, git history, and PROGRESS.md. Be generous with detail in the Decisions and Discussion sections - these are the highest-value parts that make session files actually useful for future context.

6. **Stop the Next.js dev server and deregister the port.**
   Read the port from `.claude/launch.json` and kill any process on it:
   ```bash
   PORT=$(grep -o '"port": [0-9]*' .claude/launch.json 2>/dev/null | head -1 | grep -o '[0-9]*')
   if [ -n "$PORT" ]; then
     lsof -ti:$PORT | xargs kill 2>/dev/null
   fi
   ```
   Leave Prisma Studio alone (port 5555) - it's shared and harmless.

   Remove the port lock file:
   ```bash
   rm -f "$MAIN_REPO/.claude/ports/$PORT"
   ```

7. **Tell the user what you're about to do** before the final step. Report the branch name, worktree path, and port that will be freed. The next command will destroy the session's working directory, so nothing can run after it.

8. **Remove worktree and delete branch in a single command.**
   This MUST be one chained bash command run from the main repo:
   ```bash
   cd "$MAIN_REPO" && git worktree remove "$WORKTREE_PATH" --force && git branch -d "$BRANCH"
   ```
   Use `-d` (not `-D`) so git refuses if the branch isn't fully merged.

   **CRITICAL: This is the absolute last action. After running this command:**
   - **DO NOT run any more bash commands.** The original CWD no longer exists, so the Bash tool's shell will emit errors like `shell-init: error retrieving current directory` or `No such file or directory`. These errors are **expected and harmless** - they come from the shell trying to check a directory that was just deleted. The actual git commands above almost certainly succeeded.
   - **DO NOT try to verify** whether the branch was deleted, whether the worktree was removed, or anything else. Just tell the user "Session closed" and stop.
   - **DO NOT try to "fix" the CWD errors** by cd-ing somewhere else, using absolute paths, or spawning new shells. There is nothing to fix. The session is over.
   - The branch deletion succeeds ~90% of the time. If it didn't, the user can clean it up manually. Do not spend tokens investigating.

## Rules

- **Never delete unmerged work.** The merge check in step 4 is the safety gate. If merging fails or the user has uncommitted changes, stop and ask.
- **Never use `-D` (force delete) on the branch.** Always `-d` so git validates the merge.
- **Don't kill Prisma Studio.** Only kill the Next.js dev server on the worktree's assigned port.
