#!/usr/bin/env bash
# Codex worktree environment setup.
#
# Safe to paste into Codex's worktree environment shell field, or run from a
# Codex-created worktree. Delegates to the shared new-session setup script so
# Codex worktrees get the same env files, launch.json, node_modules link, and
# graphify-out snapshot as Claude/new-session worktrees.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
main_repo=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

if [[ "$repo_root" == "$main_repo" ]]; then
  echo "Codex worktree setup: main repo detected; nothing to do."
  exit 0
fi

setup_candidates=(
  "$main_repo/.claude/skills/new-session/setup.sh"
  "$main_repo/.agents/skills/new-session/setup.sh"
  "$HOME/.claude/skills/new-session/setup.sh"
  "$HOME/.agents/skills/new-session/setup.sh"
  "$HOME/dotfiles/.claude/skills/new-session/setup.sh"
  "$HOME/dotfiles/.agents/skills/new-session/setup.sh"
)

for setup_script in "${setup_candidates[@]}"; do
  if [[ -x "$setup_script" ]]; then
    exec bash "$setup_script"
  fi
done

echo "Codex worktree setup: could not find new-session/setup.sh" >&2
exit 1
