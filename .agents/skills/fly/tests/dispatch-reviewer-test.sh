#!/usr/bin/env bash
# Behavioral tests for dispatch-reviewer.sh.
#
# Covers:
#   - normal task IDs with combined / spec / code review types
#   - consolidated task IDs with `+` ("2.1+2.2+2.3") - regex-meta in awk pattern
#   - dotted task IDs ("final.deferred-resolution") - `.` is regex any-char
#
# Run: bash .agents/skills/fly/tests/dispatch-reviewer-test.sh
# Exits 0 on all-pass, 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DR="$SCRIPT_DIR/dispatch-reviewer.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS+1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL+1))
    echo "  FAIL: $name"
    echo "    expected to contain: $needle"
    echo "    got:"
    printf '%s\n' "$haystack" | sed 's/^/      /'
  fi
}

make_checklist() {
  local task_id="$1" reviewer_model="$2" path="$3"
  cat > "$path" <<EOF
# Test Checklist

## Phase 1

### Task $task_id | Model: sonnet | Mode: subagent | Review: combined

Plan steps:
- [ ] Step 1: do thing
- [ ] Step 2: Commit - SHA: \`<fill>\`

Review gates:
- [ ] Combined review (reviewer: $reviewer_model) - Outcome: \`<fill>\`
- [ ] Combined review resolution - Action: \`<fill>\`

### Task next-task | Model: haiku
Plan steps:
- [ ] Step 1: other
EOF
}

# --- Test 1: normal task id ---
echo "Test 1: normal task id (3.2)"
F1="$TMP/normal.md"
make_checklist "3.2" "sonnet" "$F1"
OUT1=$(bash "$DR" "$F1" "3.2" "combined" "abc123" 2>&1)
assert_contains "MODEL emitted" "MODEL=sonnet" "$OUT1"
assert_contains "REVIEW_PATH emitted" "task-3.2-combined.md" "$OUT1"
assert_contains "DIFF_CMD emitted" "git show abc123" "$OUT1"

# --- Test 2: consolidated task id with `+` (THE BUG) ---
echo "Test 2: consolidated task id (2.1+2.2+2.3)"
F2="$TMP/consolidated.md"
make_checklist "2.1+2.2+2.3" "haiku" "$F2"
OUT2=$(bash "$DR" "$F2" "2.1+2.2+2.3" "combined" "def456" 2>&1)
assert_contains "MODEL emitted for consolidated id" "MODEL=haiku" "$OUT2"
assert_contains "REVIEW_PATH for consolidated id" "task-2.1+2.2+2.3-combined.md" "$OUT2"

# --- Test 3: dotted task id ---
echo "Test 3: dotted task id (final.deferred-resolution)"
F3="$TMP/dotted.md"
make_checklist "final.deferred-resolution" "sonnet" "$F3"
OUT3=$(bash "$DR" "$F3" "final.deferred-resolution" "combined" "ghi789" 2>&1)
assert_contains "MODEL emitted for dotted id" "MODEL=sonnet" "$OUT3"
assert_contains "REVIEW_PATH for dotted id" "task-final.deferred-resolution-combined.md" "$OUT3"

# --- Test 4: missing reviewer annotation halts ---
echo "Test 4: missing reviewer annotation"
F4="$TMP/missing.md"
cat > "$F4" <<EOF
### Task 1 | Model: sonnet
Review gates:
- [ ] Combined review - Outcome: \`<fill>\`
EOF
if bash "$DR" "$F4" "1" "combined" "xyz" >/dev/null 2>&1; then
  FAIL=$((FAIL+1))
  echo "  FAIL: should exit nonzero on missing reviewer annotation"
else
  PASS=$((PASS+1))
  echo "  PASS: exits nonzero on missing reviewer annotation"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
