#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/bin/ask-intern-guard"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if ! grep -q "ask-intern-guard" "$repo_root/.claude/settings.json"; then
  echo ".claude/settings.json does not install ask-intern-guard" >&2
  exit 1
fi

home="$tmpdir/home"
work="$tmpdir/work"
mkdir -p "$home" "$work"

small_a="$work/a.py"
small_b="$work/b.py"
small_c="$work/c.py"
large="$work/large.py"
marked_control="$work/arbitrary-queue.md"
spec_control="$work/docs/specs/m3/shakedown/anything-at-all.md"
manual_control="$work/manual-verbatim.md"
full="$work/full.txt"
codex_out="$work/codex-out.txt"
commit_msg="$work/cm2.txt"
mkdir -p "$(dirname "$spec_control")"
printf 'print("a")\n' >"$small_a"
printf 'print("b")\n' >"$small_b"
printf 'print("c")\n' >"$small_c"
printf '<!-- agent-control: direct-read -->\n' >"$marked_control"
printf '# Durable queue\n\n- [ ] Read this verbatim\n' >"$spec_control"
printf '# Manual queue\n\n- [ ] Read this verbatim\n' >"$manual_control"
printf 'Test Files  1 passed\nTests  1 passed\n' >"$full"
printf 'codex review output\n' >"$codex_out"
printf '' >"$commit_msg"
i=0
while [ "$i" -lt 401 ]; do
  printf 'line %s\n' "$i" >>"$large"
  printf 'item %s\n' "$i" >>"$marked_control"
  i=$((i + 1))
done

run_hook() {
  HOME="$home" "$script" <<EOF
$1
EOF
}

read_json() {
  file="$1"
  session="${2:-s1}"
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$session" "$work" "$file"
}

partial_read_json() {
  file="$1"
  printf '{"session_id":"s2","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s","offset":1,"limit":80}}' "$work" "$file"
}

bash_json() {
  command="$1"
  session="${2:-s1}"
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$session" "$work" "$command"
}

run_hook "$(read_json "$small_a")" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b")" >/tmp/guard.out 2>/tmp/guard.err

if run_hook "$(read_json "$small_c")" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "third distinct context read was not blocked" >&2
  exit 1
fi
if ! grep -q "ask-intern" /tmp/guard.err; then
  echo "third-read block did not route Claude to ask-intern" >&2
  exit 1
fi

if run_hook "$(read_json "$large")" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "large whole-file read was not blocked" >&2
  exit 1
fi
if ! grep -q "401 lines" /tmp/guard.err; then
  echo "large-file block did not explain the line-count trigger" >&2
  exit 1
fi

run_hook "$(partial_read_json "$large")" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$marked_control" s6)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$small_a" s7)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s7)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$spec_control" s7)" >/tmp/guard.out 2>/tmp/guard.err

HOME="$home" "$script" --allow-next "$manual_control" "verbatim user request" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_a" s8)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s8)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$manual_control" s8)" >/tmp/guard.out 2>/tmp/guard.err
if run_hook "$(read_json "$manual_control" s8)" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "manual one-shot direct-read allowance was not consumed" >&2
  exit 1
fi

run_hook "$(bash_json "ask-intern -f '$small_a' -f '$small_b' summarize")" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_c")" >/tmp/guard.out 2>/tmp/guard.err

if run_hook "$(bash_json "cat '$small_a' '$small_b' '$small_c'" s3)" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "bash read of three distinct files was not blocked" >&2
  exit 1
fi

run_hook "$(read_json "$small_a" s4)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s4)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "awk '/Test Files|Tests / {print}' '$full' | tail -3; echo --- codex stats ---; wc -l '$codex_out'" s4)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$small_a" s5)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s5)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "cat > '$commit_msg' << 'CMSGEOF'; commit body; CMSGEOF; git commit -F '$commit_msg' 2>&1 | tail -5" s5)" >/tmp/guard.out 2>/tmp/guard.err

echo "ok"
