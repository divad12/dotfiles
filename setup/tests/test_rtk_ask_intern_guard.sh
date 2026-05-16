#!/bin/sh

set -eu

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
wrapper="$repo_root/bin/rtk"
guard="$repo_root/bin/ask-intern-guard"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
work="$tmpdir/work"
fake="$tmpdir/real-rtk"
calls="$tmpdir/calls.log"
mkdir -p "$home" "$work"

cat >"$fake" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$RTK_FAKE_CALLS"
EOF
chmod +x "$fake"

large="$work/large.ts"
medium_a="$work/medium-a.ts"
medium_b="$work/medium-b.ts"
medium_c="$work/medium-c.ts"
small="$work/small.ts"

i=0
while [ "$i" -lt 450 ]; do
  printf 'large %s\n' "$i" >>"$large"
  if [ "$i" -lt 300 ]; then
    printf 'a %s\n' "$i" >>"$medium_a"
    printf 'b %s\n' "$i" >>"$medium_b"
    printf 'c %s\n' "$i" >>"$medium_c"
  fi
  if [ "$i" -lt 80 ]; then
    printf 'small %s\n' "$i" >>"$small"
  fi
  i=$((i + 1))
done

run_wrapper() {
  HOME="$home" \
    RTK_REAL="$fake" \
    RTK_FAKE_CALLS="$calls" \
    ASK_INTERN_GUARD="$guard" \
    RTK_GUARD_SESSION_ID="$1" \
    "$wrapper" "${@:2}"
}

if run_wrapper large-read read "$large" >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err; then
  echo "rtk read of a large file was not blocked" >&2
  exit 1
fi
if ! grep -q "ask-intern guard" /tmp/rtk-guard.err || ! grep -q "ask-intern -f" /tmp/rtk-guard.err; then
  echo "large rtk read block did not route to ask-intern" >&2
  exit 1
fi
if [ -s "$calls" ]; then
  echo "blocked command still reached the real rtk binary" >&2
  exit 1
fi

run_wrapper bounded-read read --max-lines 80 "$large" >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err
if ! grep -q "read --max-lines 80 $large" "$calls"; then
  echo "bounded rtk read did not reach the real rtk binary" >&2
  exit 1
fi

if run_wrapper broad-sed sed -n '1,500p' "$large" >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err; then
  echo "broad rtk sed read was not blocked" >&2
  exit 1
fi

if run_wrapper proxy-cat proxy cat "$large" >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err; then
  echo "raw rtk proxy cat of a large file was not blocked" >&2
  exit 1
fi

if run_wrapper multi-read read "$medium_a" "$medium_b" "$medium_c" >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err; then
  echo "rtk read of three medium files was not blocked" >&2
  exit 1
fi
if ! grep -q "broadly read about 900 lines" /tmp/rtk-guard.err; then
  echo "multi-file rtk read did not explain the cumulative budget" >&2
  exit 1
fi

: >"$calls"
if run_wrapper raw-diff proxy git diff -- src/foo.ts >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err; then
  echo "raw rtk proxy git diff was not blocked" >&2
  exit 1
fi
if ! grep -q "raw git diff" /tmp/rtk-guard.err || ! grep -q "ask-intern" /tmp/rtk-guard.err; then
  echo "raw diff block did not route to ask-intern" >&2
  exit 1
fi
if [ -s "$calls" ]; then
  echo "blocked raw diff still reached the real rtk binary" >&2
  exit 1
fi

run_wrapper normal git status --short >/tmp/rtk-guard.out 2>/tmp/rtk-guard.err
if ! grep -q "git status --short" "$calls"; then
  echo "normal rtk command did not pass through" >&2
  exit 1
fi

echo "ok"
