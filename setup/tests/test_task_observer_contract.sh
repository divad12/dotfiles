#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS="$ROOT/.claude/AGENTS.md"
SKILL="$ROOT/.agents/skills/task-observer/SKILL.md"
CLI="$ROOT/bin/task-observer"

grep -q 'Do not run `task-observer` as a shell command' "$AGENTS" || {
  echo "AGENTS must tell agents not to invoke task-observer through Bash" >&2
  exit 1
}
grep -q '.agents/skills/task-observer/SKILL.md' "$AGENTS" || {
  echo "AGENTS must name the direct skill fallback path" >&2
  exit 1
}
grep -q 'Do not run a shell command named `task-observer`' "$SKILL" || {
  echo "task-observer skill must document the non-shell invocation contract" >&2
  exit 1
}
test -x "$CLI" || {
  echo "task-observer CLI fallback must be executable" >&2
  exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home"
repo="$tmpdir/sample-repo"
mkdir -p "$home" "$repo"

(
  cd "$repo"
  git init -q
  HOME="$home" "$CLI" "agent feedback: keep implementation notes private" >"$tmpdir/out.txt"
)

log="$home/.agents/observations/sample-repo/log.md"
test -f "$log" || {
  echo "task-observer CLI fallback did not create the central observation log" >&2
  exit 1
}
grep -q 'task-observer CLI fallback' "$log" || {
  echo "task-observer CLI fallback log entry missing title" >&2
  exit 1
}
grep -q 'keep implementation notes private' "$log" || {
  echo "task-observer CLI fallback did not record the prompt" >&2
  exit 1
}
grep -q 'fallback observation captured' "$tmpdir/out.txt" || {
  echo "task-observer CLI fallback should report the captured log path" >&2
  exit 1
}

echo "ok"
