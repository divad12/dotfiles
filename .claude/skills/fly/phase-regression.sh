#!/usr/bin/env bash
# Phase-gate regression check for /fly.
#
# Runs the project's test suite at HEAD and at the phase base commit's parent,
# then reports new failing tests (regressions).
#
# Usage:
#   phase-regression.sh <phase-base-sha> <phase-head-sha>
#
# Output: a single line.
#   tests_pass=N tests_fail=N regressions=0
#   tests_pass=N tests_fail=N regressions=K | <test1> | <test2> | ...
#   tests_pass=0 tests_fail=0 regressions=0 (no tests)
#
# Exit code: 0 on no regressions, 1 on regressions OR infra failure.
#
# Agent-agnostic: no CC-specific paths. Uses git worktree to run tests at
# the base commit's parent without disturbing the working tree.

set -euo pipefail

PHASE_BASE="${1:?phase-base-sha required}"
PHASE_HEAD="${2:?phase-head-sha required}"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
  || { echo "HALT: not in a git repo"; exit 1; }

TEST_CMD_FILE="$REPO_ROOT/.fly-test-cmd"

# --- Detect test command (and cache) ---
# Exit status distinguishes three cases:
#   0, stdout non-empty  -> detected test command
#   0, stdout empty      -> user has explicitly declared "no tests" via empty cache file
#   1                    -> cannot detect
detect_cmd() {
  if [ -f "$TEST_CMD_FILE" ]; then
    # Empty file = explicit "no tests" declaration; print nothing, return 0.
    head -1 "$TEST_CMD_FILE"
    return 0
  fi
  if [ -f "$REPO_ROOT/package.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      local t
      t=$(jq -r '.scripts.test // empty' "$REPO_ROOT/package.json" 2>/dev/null || true)
      if [ -n "$t" ]; then
        echo "npm test"
        return 0
      fi
    else
      if grep -qE '"test"[[:space:]]*:' "$REPO_ROOT/package.json"; then
        echo "npm test"
        return 0
      fi
    fi
  fi
  if [ -f "$REPO_ROOT/pyproject.toml" ] || [ -f "$REPO_ROOT/pytest.ini" ]; then
    echo "pytest"
    return 0
  fi
  if [ -f "$REPO_ROOT/Cargo.toml" ]; then
    echo "cargo test"
    return 0
  fi
  if [ -f "$REPO_ROOT/go.mod" ]; then
    echo "go test ./..."
    return 0
  fi
  return 1
}

# If cache file exists, trust it (even if empty -> "no tests").
# Otherwise auto-detect.
if [ -f "$TEST_CMD_FILE" ]; then
  TEST_CMD=$(head -1 "$TEST_CMD_FILE" 2>/dev/null || true)
else
  TEST_CMD=$(detect_cmd 2>/dev/null || true)
  if [ -z "${TEST_CMD:-}" ]; then
    echo "HALT: cannot detect test command. Create $TEST_CMD_FILE with the test command on the first line (or write an empty file to declare 'no tests')."
    exit 1
  fi
  # Cache detection for future runs.
  printf '%s\n' "$TEST_CMD" > "$TEST_CMD_FILE"
fi

# Empty (explicit "no tests" declaration via empty cache file).
if [ -z "${TEST_CMD:-}" ]; then
  echo "tests_pass=0 tests_fail=0 regressions=0 (no tests)"
  exit 0
fi

# Resolve base's parent SHA (phase base SHA^).
BASE_PARENT=$(git rev-parse "${PHASE_BASE}^" 2>/dev/null) \
  || { echo "HALT: cannot resolve ${PHASE_BASE}^ in git (bad SHA?)"; exit 1; }
HEAD_OK=$(git rev-parse "$PHASE_HEAD" 2>/dev/null) \
  || { echo "HALT: cannot resolve $PHASE_HEAD in git"; exit 1; }

# --- Helper: run tests, write pass/fail counts + failing-test list ---
# $1 = working dir in which to run test cmd
# stdout of this function, one per line:
#   PASS_COUNT=<n>
#   FAIL_COUNT=<n>
#   FAIL:<identifier>     (0 or more)
run_tests() {
  local dir="$1"
  local out
  out=$(cd "$dir" && eval "$TEST_CMD" 2>&1) || true

  # Heuristic extraction of failing test identifiers.
  # Match lines that start with or contain FAIL/FAILED/✗/failed.
  local fails
  fails=$(printf '%s\n' "$out" \
    | grep -E '(^|[[:space:]])(FAIL|FAILED|✗)([[:space:]]|:)' \
    | sed -E 's/^[[:space:]]*//' \
    | awk '{
        # Pick the first token that looks like a test identifier.
        for (i=1; i<=NF; i++) {
          if ($i ~ /(test|spec|::|\.)/) { print $i; next }
        }
        print $0
      }' \
    | sort -u || true)

  local fail_count=0
  if [ -n "$fails" ]; then
    fail_count=$(printf '%s\n' "$fails" | grep -c . || true)
  fi

  # Pass count: best-effort parse common formatters
  # - pytest: "N passed"
  # - jest:   "Tests: ... N passed"
  # - cargo:  "test result: ok. N passed"
  # - go:     "PASS" lines
  local pass_count
  pass_count=$(printf '%s\n' "$out" | grep -oE '[0-9]+ passed' | head -1 | awk '{print $1}')
  if [ -z "${pass_count:-}" ]; then
    pass_count=$(printf '%s\n' "$out" | grep -cE '^(ok|PASS)([[:space:]]|$)' || true)
  fi
  [ -z "${pass_count:-}" ] && pass_count=0

  echo "PASS_COUNT=$pass_count"
  echo "FAIL_COUNT=$fail_count"
  if [ -n "$fails" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && echo "FAIL:$f"
    done <<< "$fails"
  fi
}

# --- Run at HEAD (working dir) ---
HEAD_OUT=$(run_tests "$REPO_ROOT")
HEAD_PASS=$(printf '%s\n' "$HEAD_OUT" | grep '^PASS_COUNT=' | head -1 | cut -d= -f2)
HEAD_FAIL=$(printf '%s\n' "$HEAD_OUT" | grep '^FAIL_COUNT=' | head -1 | cut -d= -f2)
HEAD_FAILS=$(printf '%s\n' "$HEAD_OUT" | sed -n 's/^FAIL://p' | sort -u)

# --- Run at BASE_PARENT via worktree ---
TMPDIR_WT=$(mktemp -d -t fly-phase-regression.XXXXXX)
trap 'git worktree remove --force "$TMPDIR_WT" >/dev/null 2>&1 || true; rm -rf "$TMPDIR_WT" 2>/dev/null || true' EXIT

if ! git worktree add --detach "$TMPDIR_WT" "$BASE_PARENT" >/dev/null 2>&1; then
  echo "HALT: git worktree add failed for $BASE_PARENT"
  exit 1
fi

BASE_OUT=$(run_tests "$TMPDIR_WT")
BASE_FAILS=$(printf '%s\n' "$BASE_OUT" | sed -n 's/^FAIL://p' | sort -u)

# --- Compute regressions: failing at HEAD but not at base ---
REGRESSIONS=""
if [ -n "$HEAD_FAILS" ]; then
  if [ -n "$BASE_FAILS" ]; then
    REGRESSIONS=$(comm -23 <(printf '%s\n' "$HEAD_FAILS") <(printf '%s\n' "$BASE_FAILS"))
  else
    REGRESSIONS="$HEAD_FAILS"
  fi
fi

REG_COUNT=0
if [ -n "$REGRESSIONS" ]; then
  REG_COUNT=$(printf '%s\n' "$REGRESSIONS" | grep -c . || true)
fi

if [ "$REG_COUNT" -eq 0 ]; then
  echo "tests_pass=${HEAD_PASS} tests_fail=${HEAD_FAIL} regressions=0"
  exit 0
fi

LINE="tests_pass=${HEAD_PASS} tests_fail=${HEAD_FAIL} regressions=${REG_COUNT}"
while IFS= read -r r; do
  [ -n "$r" ] && LINE="$LINE | $r"
done <<< "$REGRESSIONS"
echo "$LINE"
exit 1
