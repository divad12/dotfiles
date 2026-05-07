#!/bin/bash
# new-session setup: symlink node_modules, copy env/graphify-out files, pick a unique port.
# Run from inside a worktree (the worktree must already exist).
#
# Usage: ./setup.sh
# Output: prints the assigned port to stdout (and writes .claude/launch.json)

set -euo pipefail

# 1. Resolve main repo root from the current worktree.
WORKTREE=$(git rev-parse --show-toplevel)
MAIN_REPO=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

if [ "$WORKTREE" = "$MAIN_REPO" ]; then
  echo "Error: $WORKTREE is the main repo, not a worktree." >&2
  exit 1
fi

cd "$WORKTREE"

# 2. Copy env files from main repo (silent if missing).
for f in .env .env.local .env.production.local; do
  [ -f "$MAIN_REPO/$f" ] && [ ! -f "$f" ] && cp "$MAIN_REPO/$f" ./
done

# 3. Copy generated Graphify output from the main repo.
#
# graphify-out is intentionally gitignored, so plain git worktrees do not get
# the wiki/report files that Graphify-aware agents look for. Copy a snapshot
# when the main repo already has it; leave any worktree-local graphify-out alone
# so parallel sessions never compete over shared mutable graph state.
if [ -d "$MAIN_REPO/graphify-out" ] && [ ! -e graphify-out ]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude 'graph.html' "$MAIN_REPO/graphify-out/" ./graphify-out/
  else
    mkdir -p graphify-out
    cp -R "$MAIN_REPO/graphify-out/." ./graphify-out/
    rm -f ./graphify-out/graph.html
  fi
fi

# 4. Symlink node_modules from main repo.
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

# 5. Pick or preserve a port in 3001-9999 (3000 reserved for main repo).
# Preserve an existing launch port so rerunning setup to refresh symlinks does
# not silently move the dev server URL.
PORT=""
if [ -f .claude/launch.json ]; then
  PORT=$(awk -F'[^0-9]+' '/"port"[[:space:]]*:/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }' .claude/launch.json || true)
fi
if [ -z "$PORT" ]; then
  # lsof check is enough at session start - HMR-induced false negatives only
  # matter for staleness detection, which we no longer do.
  for _ in $(seq 1 20); do
    PORT=$(( 3001 + RANDOM % 6999 ))
    if ! lsof -ti:"$PORT" >/dev/null 2>&1; then
      break
    fi
  done
fi

# 6. Write launch.json.
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
