#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/bin/graphify-guard"
stats="$repo_root/bin/graphify-stats"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if ! grep -q "graphify-guard" "$repo_root/.claude/settings.json"; then
  echo ".claude/settings.json does not install graphify-guard" >&2
  exit 1
fi

if grep -q "graphify-out/graph.json.*grep" "$repo_root/.claude/settings.json"; then
  echo ".claude/settings.json still contains Graphify's generated inline hook" >&2
  exit 1
fi

home="$tmpdir/home"
work="$tmpdir/work"
mkdir -p "$home" "$work/graphify-out"
printf '{}\n' >"$work/graphify-out/graph.json"
printf '# Graph Report\n' >"$work/graphify-out/GRAPH_REPORT.md"

run_hook() {
  HOME="$home" GRAPHIFY_USAGE_DIR="$tmpdir/graphify-usage" "$script" <<EOF
$1
EOF
}

bash_json() {
  command="$1"
  cwd="${2:-$work}"
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$cwd" "$command"
}

read_json() {
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"x.py"}}' "$work"
}

run_hook "$(bash_json "rg auth src")" >/tmp/graphify-guard.out
if ! grep -q "graphify-out/GRAPH_REPORT.md" /tmp/graphify-guard.out; then
  echo "graphify guard did not point search toward GRAPH_REPORT.md" >&2
  exit 1
fi
if ! grep -q "graphify query" /tmp/graphify-guard.out; then
  echo "graphify guard did not suggest graphify query" >&2
  exit 1
fi
if ! grep -q "graphify explain" /tmp/graphify-guard.out; then
  echo "graphify guard did not suggest graphify explain" >&2
  exit 1
fi

run_hook "$(bash_json "graphify query auth")" >/tmp/graphify-guard.out
if [ -s /tmp/graphify-guard.out ]; then
  echo "graphify guard should not nudge graphify commands" >&2
  exit 1
fi
if ! grep -q '"action": "command"' "$tmpdir/graphify-usage/events.jsonl"; then
  echo "graphify guard did not log graphify commands" >&2
  exit 1
fi
if ! grep -q '"action": "nudge"' "$tmpdir/graphify-usage/events.jsonl"; then
  echo "graphify guard did not log search nudges" >&2
  exit 1
fi

GRAPHIFY_USAGE_DIR="$tmpdir/graphify-usage" "$stats" >/tmp/graphify-stats.out
if ! grep -q "commands:   1" /tmp/graphify-stats.out; then
  echo "graphify-stats did not count commands" >&2
  exit 1
fi
if ! grep -q "nudges:     1" /tmp/graphify-stats.out; then
  echo "graphify-stats did not count nudges" >&2
  exit 1
fi

run_hook "$(read_json)" >/tmp/graphify-guard.out
if [ -s /tmp/graphify-guard.out ]; then
  echo "graphify guard should only handle Bash search commands" >&2
  exit 1
fi

mkdir -p "$tmpdir/no-graph"
run_hook "$(bash_json "rg auth src" "$tmpdir/no-graph")" >/tmp/graphify-guard.out
if [ -s /tmp/graphify-guard.out ]; then
  echo "graphify guard should stay quiet when no graph exists" >&2
  exit 1
fi

echo "ok"
