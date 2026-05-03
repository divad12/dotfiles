#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home/.agents/observations" "$home/.codex" "$tmpdir/bin"
printf 'keep me\n' >"$home/.agents/observations/log.md"

cat >"$tmpdir/bin/launchctl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmpdir/bin/launchctl"

(
  cd "$repo_root"
  HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" ./symlink.sh >/tmp/symlink-test.out
)

if [ -L "$home/.agents" ]; then
  echo "~/.agents was replaced wholesale; runtime observations would be hidden" >&2
  exit 1
fi

if [ ! -f "$home/.agents/observations/log.md" ]; then
  echo "~/.agents runtime observations were not preserved" >&2
  exit 1
fi

if [ "$(readlink "$home/.agents/AGENTS.md")" != "$repo_root/.claude/AGENTS.md" ]; then
  echo "~/.agents/AGENTS.md does not point at the shared instructions" >&2
  exit 1
fi

if [ "$(readlink "$home/.agents/skills")" != "$repo_root/.agents/skills" ]; then
  echo "~/.agents/skills does not point at the shared skill directory" >&2
  exit 1
fi

if [ "$(readlink "$home/.codex/AGENTS.md")" != "$repo_root/.claude/AGENTS.md" ]; then
  echo "~/.codex/AGENTS.md does not point at the shared instructions" >&2
  exit 1
fi

echo "ok"
