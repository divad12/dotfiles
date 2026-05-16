#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home/.agents/observations" "$home/.codex" "$tmpdir/bin"
printf 'keep me\n' >"$home/.agents/observations/log.md"
mkdir -p "$home/.claude"
printf '{"local":"drift"}\n' >"$home/.claude/settings.json"
printf 'previous backup\n' >"$home/.claude/settings.json.orig"

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

if [ -L "$repo_root/.claude/CLAUDE.md" ]; then
  echo ".claude/CLAUDE.md must be a real Claude wrapper, not a symlink to AGENTS.md" >&2
  exit 1
fi

grep -q '@/Users/david/dotfiles/.claude/AGENTS.md' "$repo_root/.claude/CLAUDE.md" || {
  echo "Claude wrapper must include the shared global instructions" >&2
  exit 1
}

grep -q '^@RTK.md$' "$repo_root/.claude/CLAUDE.md" || {
  echo "Claude wrapper must include RTK using the relative reference expected by rtk init --show" >&2
  exit 1
}

if [ "$(readlink "$home/.codex/AGENTS.md")" != "$repo_root/.codex/AGENTS.md" ]; then
  echo "~/.codex/AGENTS.md does not point at the tracked Codex wrapper" >&2
  exit 1
fi

if [ "$(readlink "$home/.codex/config.toml")" != "$repo_root/.codex/config.toml" ]; then
  echo "~/.codex/config.toml does not point at the tracked Codex config" >&2
  exit 1
fi

if [ "$(readlink "$home/.codex/RTK.md")" != "$repo_root/.codex/RTK.md" ]; then
  echo "~/.codex/RTK.md does not point at the tracked RTK instructions" >&2
  exit 1
fi

grep -q '@/Users/david/dotfiles/.claude/AGENTS.md' "$repo_root/.codex/AGENTS.md" || {
  echo "tracked Codex wrapper must include the shared global instructions" >&2
  exit 1
}

grep -q '@/Users/david/.codex/RTK.md' "$repo_root/.codex/AGENTS.md" || {
  echo "tracked Codex wrapper must include Codex-specific RTK instructions" >&2
  exit 1
}

grep -q '^goals = true$' "$repo_root/.codex/config.toml" || {
  echo "tracked Codex config must enable the goals feature" >&2
  exit 1
}

grep -q 'env_http_headers = { "CONTEXT7_API_KEY" = "CONTEXT7_API_KEY" }' "$repo_root/.codex/config.toml" || {
  echo "tracked Codex config must read the Context7 key from the environment" >&2
  exit 1
}

if grep -q '^http_headers = { "CONTEXT7_API_KEY"' "$repo_root/.codex/config.toml"; then
  echo "tracked Codex config must not contain the literal Context7 key" >&2
  exit 1
fi

if [ "$(readlink "$home/.claude/settings.json")" != "$repo_root/.claude/settings.json" ]; then
  echo "~/.claude/settings.json drift was not restored to the dotfiles symlink" >&2
  exit 1
fi

if [ "$(cat "$home/.claude/settings.json.orig")" != "previous backup" ]; then
  echo "existing ~/.claude/settings.json.orig backup was overwritten" >&2
  exit 1
fi

if ! find "$home/.claude" -name 'settings.json.orig.*' -type f -exec grep -q '"local":"drift"' {} \; -print | grep -q .; then
  echo "drifted ~/.claude/settings.json was not preserved in a unique backup" >&2
  exit 1
fi

echo "ok"
