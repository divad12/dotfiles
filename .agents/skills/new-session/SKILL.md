---
name: new-session
description: "Use when the user says 'new session', 'start a session', 'new worktree', 'start fresh', or 'spin up a workspace'."
user-invocable: true
---

# New Session

Set up a worktree with everything needed to run the dev server: env files, `node_modules` symlink, `graphify-out` snapshot when available, and a unique port that won't conflict with the main repo or other worktrees.

## Steps

1. **Check if you're already in a worktree.**
   ```bash
   git rev-parse --show-toplevel
   ```
   If the path is inside `.claude/worktrees/`, you're in a worktree (created externally, e.g. by Claude Code desktop). Skip to step 3.

   If you're in the main repo, use the `EnterWorktree` tool to create one. Let it generate a name, or use one the user provides.

2. **Identify the worktree directory** (it should now be your CWD).

3. **Run setup.sh** from the worktree:
   ```bash
   MAIN_REPO=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
   bash "$MAIN_REPO/.claude/skills/new-session/setup.sh"
   ```
   The script copies env files (`.env`, `.env.local`, `.env.production.local`) from the main repo, symlinks `node_modules`, copies a local `graphify-out` snapshot when the main repo has generated graph output, picks a random unused port in 3001-9999, and writes `.claude/launch.json`. It prints the assigned port to stdout.

   If the script lives in `~/.claude/skills/new-session/setup.sh` instead (because this is a fresh machine without the project copy), invoke that path directly.

4. **Read PROGRESS.md** from the main repo to understand current project state.

5. **Report** to the user:
   - Worktree path and branch name
   - Dev server port (from step 3 output)
   - URL: `http://localhost:<PORT>`
   - Reminder to start the server with: `npm run dev -- --port <PORT>`

## Always use the assigned port

For the rest of this session, whenever you start a dev server or open a URL, use the port from `launch.json` - never bare `npm run dev` (defaults to 3000, which belongs to the main repo) and never `http://localhost:3000`.

## Test data isolation

Multiple worktrees share the same database. To avoid conflicts, **create worktree-specific test data** instead of relying on the shared seed.

- Name top-level test entities after the branch (e.g. `"WT: <branch-name>"`).
- Build all test data under that entity. Never modify shared seed data.
- Filter to your worktree's entity when testing in the browser or e2e tests.

**Schema migrations are the exception.** If your feature requires `prisma db push` with breaking changes, check `git worktree list` and warn the user before pushing.

## Recovery: work accidentally in the main checkout

If work has landed in the main checkout and needs to move to a worktree:

1. **Check existing worktrees first:** `git worktree list`. A clean worktree is the safest landing zone and avoids adding clutter.
2. **Verify a candidate is clean:** in that worktree, run `git log --oneline <target>..HEAD`. Zero results means no branch-only commits — safe to reuse.
3. **Fast-forward and reuse:** checkout the appropriate branch, fast-forward to the current target ref, and confirm the launch port from its `launch.json`.
4. **Only create a new worktree** when no clean candidate exists.
