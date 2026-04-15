#!/bin/sh

set -eu

HOOK_PATH="${1:-$HOME/.git-templates/hooks/post-commit}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/git" <<'EOF'
#!/bin/sh
case "$1" in
  rev-parse)
    echo "deadbeef"
    ;;
  config)
    echo "git@github.com:user/repo.git"
    ;;
  log)
    echo "Mon Apr 13 12:00:00 2026 -0300"
    ;;
  *)
    echo "unexpected git invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmpdir/bin/git"

if PATH="$tmpdir/bin:/usr/bin:/bin" "$HOOK_PATH" >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
  :
else
  echo "hook exited non-zero when git-stats was unavailable" >&2
  cat "$tmpdir/stderr" >&2
  exit 1
fi

if grep -Eq 'git-stats: (command )?not found' "$tmpdir/stderr"; then
  echo "hook leaked a missing git-stats error" >&2
  cat "$tmpdir/stderr" >&2
  exit 1
fi

cat >"$tmpdir/bin/git-stats" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TMP_GIT_STATS_ARGS"
EOF
chmod +x "$tmpdir/bin/git-stats"

TMP_GIT_STATS_ARGS="$tmpdir/git-stats-args" PATH="$tmpdir/bin:/usr/bin:/bin" "$HOOK_PATH"

if ! grep -q -- '--record' "$tmpdir/git-stats-args"; then
  echo "hook did not invoke git-stats with --record" >&2
  exit 1
fi

echo "ok"
