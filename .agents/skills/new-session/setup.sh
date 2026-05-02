#!/bin/bash
# new-session setup: symlink node_modules, copy env files, pick a unique port.
# Run from inside a worktree (the worktree must already exist).
#
# Usage: ./setup.sh
# Output: prints the assigned port to stdout (and writes .claude/launch.json)

set -euo pipefail

# 1. Resolve main repo root from the current worktree.
WORKTREE=$(git rev-parse --show-toplevel)
MAIN_REPO=$(git worktree list | awk 'NR==1 {print $1}')

if [ "$WORKTREE" = "$MAIN_REPO" ]; then
  echo "Error: $WORKTREE is the main repo, not a worktree." >&2
  exit 1
fi

cd "$WORKTREE"

# 2. Copy env files from main repo (silent if missing).
for f in .env .env.local .env.production.local; do
  [ -f "$MAIN_REPO/$f" ] && [ ! -f "$f" ] && cp "$MAIN_REPO/$f" ./
done

# 3. Symlink node_modules from main repo.
[ -e node_modules ] || ln -s "$MAIN_REPO/node_modules" ./node_modules

# 4. Pick a random unused port in 3001-9999 (3000 reserved for main repo).
# lsof check is enough at session start - HMR-induced false negatives only
# matter for staleness detection, which we no longer do.
for _ in $(seq 1 20); do
  PORT=$(( 3001 + RANDOM % 6999 ))
  if ! lsof -ti:"$PORT" >/dev/null 2>&1; then
    break
  fi
done

# 5. Write launch.json.
mkdir -p .claude
cat > .claude/launch.json <<JSON
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "next-dev",
      "runtimeExecutable": "npm",
      "runtimeArgs": ["run", "dev", "--", "--port", "$PORT"],
      "port": $PORT
    },
    {
      "name": "prisma-studio",
      "runtimeExecutable": "npx",
      "runtimeArgs": ["prisma", "studio"],
      "port": 5555
    }
  ]
}
JSON

echo "$PORT"
