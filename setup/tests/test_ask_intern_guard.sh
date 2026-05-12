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
small_page="$work/page.tsx"
medium_a="$work/medium-a.ts"
medium_b="$work/medium-b.ts"
medium_c="$work/medium-c.ts"
snippet_a="$work/snippet-a.ts"
snippet_b="$work/snippet-b.ts"
snippet_c="$work/snippet-c.ts"
edge_a="$work/edge-a.ts"
edge_b="$work/edge-b.ts"
large="$work/large.py"
marked_control="$work/arbitrary-queue.md"
docs_control="$work/docs/implementation-plan.txt"
manual_control="$work/manual-verbatim.md"
full="$work/full.txt"
codex_out="$work/codex-out.txt"
commit_msg="$work/cm2.txt"
image="$work/screenshot.png"
long_log="$work/long.log"
mkdir -p "$(dirname "$docs_control")"
printf 'print("a")\n' >"$small_a"
printf 'print("b")\n' >"$small_b"
printf 'print("c")\n' >"$small_c"
printf '' >"$small_page"
printf '' >"$medium_a"
printf '' >"$medium_b"
printf '' >"$medium_c"
printf '' >"$snippet_a"
printf '' >"$snippet_b"
printf '' >"$snippet_c"
printf '' >"$edge_a"
printf '' >"$edge_b"
printf '<!-- agent-control: direct-read -->\n' >"$marked_control"
printf 'Durable implementation plan\n\n- [ ] Read this verbatim\n' >"$docs_control"
printf '# Manual queue\n\n- [ ] Read this verbatim\n' >"$manual_control"
printf 'Test Files  1 passed\nTests  1 passed\n' >"$full"
printf 'codex review output\n' >"$codex_out"
printf '' >"$commit_msg"
printf '' >"$image"
printf '' >"$long_log"
i=0
while [ "$i" -lt 401 ]; do
  printf 'line %s\n' "$i" >>"$large"
  printf 'item %s\n' "$i" >>"$marked_control"
  printf 'manual item %s\n' "$i" >>"$manual_control"
  if [ "$i" -lt 300 ]; then
    printf 'medium a %s\n' "$i" >>"$medium_a"
    printf 'medium b %s\n' "$i" >>"$medium_b"
    printf 'medium c %s\n' "$i" >>"$medium_c"
  fi
  if [ "$i" -lt 170 ]; then
    printf 'snippet a %s\n' "$i" >>"$snippet_a"
    printf 'snippet b %s\n' "$i" >>"$snippet_b"
    printf 'snippet c %s\n' "$i" >>"$snippet_c"
  fi
  if [ "$i" -lt 400 ]; then
    printf 'edge a %s\n' "$i" >>"$edge_a"
    printf 'edge b %s\n' "$i" >>"$edge_b"
  fi
  printf 'pixel-ish line %s\n' "$i" >>"$image"
  printf 'log line %s\n' "$i" >>"$long_log"
  if [ "$i" -lt 88 ]; then
    printf 'page line %s\n' "$i" >>"$small_page"
  fi
  i=$((i + 1))
done
while [ "$i" -lt 1000 ]; do
  printf 'log line %s\n' "$i" >>"$long_log"
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
  session="${2:-s2}"
  limit="${3:-80}"
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s","offset":1,"limit":%s}}' "$session" "$work" "$file" "$limit"
}

bash_json() {
  command="$1"
  session="${2:-s1}"
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$session" "$work" "$command"
}

run_hook "$(read_json "$small_a")" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b")" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_c")" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$medium_a" s9)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$medium_b" s9)" >/tmp/guard.out 2>/tmp/guard.err
if run_hook "$(read_json "$medium_c" s9)" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "cumulative medium context reads were not blocked" >&2
  exit 1
fi
if ! grep -q "900 lines" /tmp/guard.err || ! grep -q "ask-intern" /tmp/guard.err; then
  echo "cumulative-read block did not explain the line budget and route Claude to ask-intern" >&2
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
if run_hook "$(partial_read_json "$large" s20 500)" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "large partial read was not blocked" >&2
  exit 1
fi
run_hook "$(read_json "$image" s21)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$medium_a" s10)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$medium_b" s10)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_page" s10)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$snippet_a" s14)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$snippet_b" s14)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$snippet_c" s14)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$edge_a" s13)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$edge_b" s13)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_page" s13)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$medium_a" s11)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$medium_b" s11)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "wc -l '$small_page'; head -5 '$small_page'; tail -5 '$small_page'" s11)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$medium_a" s22)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$medium_b" s22)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "cat '$long_log' | tail -5" s22)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "cat '$long_log' | wc -l && tail -80 '$long_log' | head -40" s22)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "cat '$large' | head -150 | tail -50" s23)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$marked_control" s6)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$small_a" s7)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s7)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$docs_control" s7)" >/tmp/guard.out 2>/tmp/guard.err

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

run_hook "$(bash_json "cat '$small_a' '$small_b' '$small_c'" s3)" >/tmp/guard.out 2>/tmp/guard.err

if run_hook "$(bash_json "cat '$medium_a' '$medium_b' '$medium_c'" s12)" >/tmp/guard.out 2>/tmp/guard.err; then
  echo "bash read of three medium files was not blocked" >&2
  exit 1
fi

run_hook "$(read_json "$small_a" s4)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s4)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "awk '/Test Files|Tests / {print}' '$full' | tail -3; echo --- codex stats ---; wc -l '$codex_out'" s4)" >/tmp/guard.out 2>/tmp/guard.err

run_hook "$(read_json "$small_a" s5)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(read_json "$small_b" s5)" >/tmp/guard.out 2>/tmp/guard.err
run_hook "$(bash_json "cat > '$commit_msg' << 'CMSGEOF'; commit body; CMSGEOF; git commit -F '$commit_msg' 2>&1 | tail -5" s5)" >/tmp/guard.out 2>/tmp/guard.err

claude_cwd="$work/.claude/worktrees/example"
mkdir -p "$claude_cwd"
run_hook "$(printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s"}}' "s15" "$claude_cwd" "$medium_a")" >/tmp/guard.out 2>/tmp/guard.err

events="$home/.config/ask-intern/read-guard/events.jsonl"
if ! grep -q '"tool_input": {"file_path":' "$events"; then
  echo "read guard events did not log original Read tool input" >&2
  exit 1
fi
if ! grep -q '"hook_event_name": "PreToolUse"' "$events"; then
  echo "read guard events did not log hook event name" >&2
  exit 1
fi
if ! grep -q '"limit": 500' "$events"; then
  echo "read guard events did not log partial Read limit" >&2
  exit 1
fi
if ! grep -q '"read_lines": 401' "$events"; then
  echo "read guard events did not log read-line estimate" >&2
  exit 1
fi
if ! grep -q '"total_lines": 900' "$events"; then
  echo "read guard events did not log cumulative line total" >&2
  exit 1
fi
if ! grep -q '"distinct_files": 3' "$events"; then
  echo "read guard events did not log cumulative file count" >&2
  exit 1
fi
if ! grep -q '"tool_input": {"command": "cat ' "$events"; then
  echo "read guard events did not log original Bash command in tool input" >&2
  exit 1
fi
if ! grep -q '"source": "claude"' "$events"; then
  echo "read guard events did not log inferred agent source" >&2
  exit 1
fi

echo "ok"
