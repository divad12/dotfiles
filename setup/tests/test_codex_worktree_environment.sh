#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/.codex/worktree-environment.sh"
setup="$repo_root/.agents/skills/new-session/setup.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

main="$tmpdir/repo with spaces"
worktree="$main/.codex/worktrees/example"

git init -q "$main"
git -C "$main" config user.email "test@example.com"
git -C "$main" config user.name "Test User"
mkdir -p "$main/.claude/skills/new-session" "$main/graphify-out/wiki" "$main/node_modules"
cp "$setup" "$main/.claude/skills/new-session/setup.sh"
printf '{}\n' >"$main/graphify-out/graph.json"
printf '# Wiki\n' >"$main/graphify-out/wiki/index.md"
printf 'hello\n' >"$main/README.md"
git -C "$main" add README.md
git -C "$main" commit -q -m init
git -C "$main" worktree add -q -b example "$worktree"

(cd "$worktree" && bash "$script" >/tmp/codex-worktree-env.out)

if [ ! -f "$worktree/.claude/launch.json" ]; then
  echo "codex worktree environment did not create launch.json" >&2
  exit 1
fi
if [ ! -e "$worktree/node_modules" ]; then
  echo "codex worktree environment did not set up node_modules" >&2
  exit 1
fi
if [ ! -f "$worktree/graphify-out/graph.json" ]; then
  echo "codex worktree environment did not copy graphify-out snapshot" >&2
  exit 1
fi

echo "ok"
