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
#
# Two ways this can go wrong with absolute paths:
#   1. $MAIN_REPO came from `git worktree list` which canonicalises paths;
#      if the script was invoked through a Dropbox symlink chain (Dropbox ->
#      Dropbox (Personal)), the resulting link target may be `/Users/x/
#      Dropbox/node_modules` which doesn't actually exist directly.
#   2. Renaming the parent dir later breaks the absolute target.
#
# Use a relative target instead: this worktree is always at
# <main>/.claude/worktrees/<name>, so ../../../node_modules from here always
# points at the main repo's node_modules. Survives renames and Dropbox
# canonicalisation quirks.
#
# `-e` follows symlinks, so a previous broken symlink (target doesn't exist)
# returns false and we recreate it. `-L` would treat a broken symlink as
# present and skip the fix, which is what bit this script in the past.
if [ ! -e node_modules ]; then
  rm -f node_modules  # clear any stale broken symlink
  ln -s ../../../node_modules ./node_modules
  if [ ! -e node_modules ]; then
    echo "warning: node_modules symlink target does not resolve. Worktree may not be at <main>/.claude/worktrees/<name>." >&2
    rm -f node_modules
  fi
fi

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
