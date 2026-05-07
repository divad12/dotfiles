#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/.agents/skills/new-session/setup.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

main="$tmpdir/repo with spaces"
worktree="$main/.claude/worktrees/graphify"

git init -q "$main"
git -C "$main" config user.email "test@example.com"
git -C "$main" config user.name "Test User"
mkdir -p "$main/graphify-out/wiki" "$main/node_modules"
printf '{}\n' >"$main/graphify-out/graph.json"
printf '# Wiki\n' >"$main/graphify-out/wiki/index.md"
printf '<html></html>\n' >"$main/graphify-out/graph.html"
printf 'hello\n' >"$main/README.md"
git -C "$main" add README.md
git -C "$main" commit -q -m init
git -C "$main" worktree add -q -b graphify "$worktree"

(cd "$worktree" && bash "$script" >/tmp/new-session-port.out)
first_port="$(cat /tmp/new-session-port.out)"

if [ ! -d "$worktree/graphify-out" ] || [ -L "$worktree/graphify-out" ]; then
  echo "new-session setup did not create a local graphify-out copy" >&2
  exit 1
fi
if [ ! -f "$worktree/graphify-out/graph.json" ]; then
  echo "graphify-out copy does not include graph.json" >&2
  exit 1
fi
if ! grep -q "# Wiki" "$worktree/graphify-out/wiki/index.md"; then
  echo "graphify-out copy does not include wiki output" >&2
  exit 1
fi
if [ -e "$worktree/graphify-out/graph.html" ]; then
  echo "new-session setup should not copy generated graph.html" >&2
  exit 1
fi
if [ ! -f "$worktree/.claude/launch.json" ]; then
  echo "new-session setup did not still write launch.json" >&2
  exit 1
fi

(cd "$worktree" && bash "$script" >/tmp/new-session-port-rerun.out)
second_port="$(cat /tmp/new-session-port-rerun.out)"
if [ "$first_port" != "$second_port" ]; then
  echo "new-session setup did not preserve launch port on rerun" >&2
  exit 1
fi
printf 'local session data\n' >"$worktree/graphify-out/local-only.txt"
printf 'main updated\n' >"$main/graphify-out/main-only.txt"
(cd "$worktree" && bash "$script" >/tmp/new-session-port-third.out)
if [ ! -f "$worktree/graphify-out/local-only.txt" ]; then
  echo "new-session setup overwrote worktree-local graphify output" >&2
  exit 1
fi
if [ -f "$worktree/graphify-out/main-only.txt" ]; then
  echo "new-session setup refreshed graphify-out after local copy existed" >&2
  exit 1
fi

echo "ok"
