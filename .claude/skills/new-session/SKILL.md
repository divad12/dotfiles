---
name: new-session
description: "Set up a worktree session with env files and a unique dev server port. Use when the user says 'new session', 'start a session', 'new worktree', or wants to work on a feature in isolation. Also use when the user asks to 'start fresh' or 'spin up a workspace'."
user-invocable: true
---

# New Session

Set up a worktree with everything needed to run the dev server - env files copied from the main repo and a unique port that won't conflict with other worktrees.

## Steps

1. **Check if you're already in a worktree.**
   ```bash
   git rev-parse --show-toplevel
   ```
   If the current working directory is already inside `.claude/worktrees/`, you're in a worktree that was created externally (e.g. by Claude Code desktop). Skip to step 3.

   If you're in the main repo, use the `EnterWorktree` tool to create one. Let it generate a name (or use one the user provides).

2. **Identify the main repo root.**
   The main repo is always the entry in `git worktree list` with `[main]`:
   ```bash
   MAIN_REPO=$(git worktree list | grep '\[main\]' | awk '{print $1}')
   ```

3. **Copy env files.**
   These files aren't git-tracked but are required for the dev server and Prisma:
   ```bash
   cp "$MAIN_REPO/.env" ./ 2>/dev/null
   cp "$MAIN_REPO/.env.local" ./ 2>/dev/null
   ```
   Don't fail if `.env` doesn't exist (`.env.local` is the important one).

4. **Check if `launch.json` already exists.**
   If `.claude/launch.json` exists in the current worktree and already has a port assigned, use that port. Skip to step 7.

5. **Find the next available port.**
   **Port 3000 is permanently reserved for the main repo. NEVER use 3000 for a worktree session, even if it appears free.** Worktrees always start at 3001.

   Check which ports are already claimed by looking for lock files:
   ```bash
   PORTS_DIR="$MAIN_REPO/.claude/ports"
   mkdir -p "$PORTS_DIR"
   USED_PORTS=$(ls "$PORTS_DIR" 2>/dev/null | grep -o '[0-9]*')
   ```
   Starting from 3001, pick the first port not in `USED_PORTS` and not currently bound by a running process (`lsof -ti:<port>`).

6. **Claim the port and create `.claude/launch.json`.**
   Create a lock file to claim the port. The filename is the port number, the content is the branch name. File creation is near-atomic, avoiding race conditions with parallel sessions:
   ```bash
   PORTS_DIR="$MAIN_REPO/.claude/ports"
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   echo "$BRANCH" > "$PORTS_DIR/<PORT>"
   ```

   Then create `.claude/launch.json` in the worktree:
   ```json
   {
     "version": "0.0.1",
     "configurations": [
       {
         "name": "next-dev",
         "runtimeExecutable": "npm",
         "runtimeArgs": ["run", "dev", "--", "--port", "<PORT>"],
         "port": <PORT>
       },
       {
         "name": "prisma-studio",
         "runtimeExecutable": "npx",
         "runtimeArgs": ["prisma", "studio"],
         "port": 5555
       }
     ]
   }
   ```

7. **Symlink node_modules** from the main repo if not already present:
   ```bash
   [ -d node_modules ] || ln -s "$MAIN_REPO/node_modules" ./node_modules
   ```
   This is much faster than running `npm install` and shares the same dependency versions. If the symlink breaks later (e.g. main repo ran `npm install` and moved the folder), just recreate it.

8. **Read PROGRESS.md** from the main repo to understand current project state.

9. **Report** to the user:
   - Worktree path and branch name
   - Dev server port assigned
   - URL: `http://localhost:<PORT>`
   - Remind them to start the server with: `npm run dev -- --port <PORT>`

## Important: Always use the assigned port

For the rest of this session, whenever you start a dev server (e.g. `npm run dev`, or any command that launches Next.js), always use the port from `launch.json`. That means `npm run dev -- --port <PORT>`, not bare `npm run dev`. Running bare `npm run dev` defaults to port 3000, which belongs to the main repo and will conflict. Same for any `open` or `playwright-cli` URLs - use `http://localhost:<PORT>`, not `:3000`.

## Notes

- The main repo always owns port 3000. Never assign 3000 to a worktree.
- If all ports 3001-3010 are taken, something is probably wrong. Flag it to the user rather than going higher.
- Port lock files live in `$MAIN_REPO/.claude/ports/` (e.g. `.claude/ports/3001` contains the branch name). Both `new-session` and `close-session` maintain these.
- **Stale entries:** If a session crashed without running `close-session`, its lock file stays. The `lsof` check in step 5 handles this - if a claimed port has no process on it, it's safe to reuse. Delete the stale lock file and create a new one for your branch.

## Test data isolation

Multiple worktrees share the same database. To avoid conflicts (e.g. one worktree re-seeds while another is testing), **create worktree-specific test data** instead of relying on the shared seed.

- When you need test data, create a new top-level entity (e.g. an Event in Journology) named after the branch: `"WT: fervent-goodall"` or `"WT: <branch-name>"`.
- Build all your test data under that entity. Never modify or depend on shared seed data.
- When testing in the browser or writing e2e tests, filter to your worktree's entity.
- This way multiple worktrees can test concurrently without stepping on each other.

**Schema migrations are the exception.** If your feature requires `prisma db push` with breaking changes, coordinate with other active sessions. Check `git worktree list` to see if other worktrees exist and warn the user before pushing schema changes.
