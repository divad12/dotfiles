#!/usr/bin/env bash
# Behavioral tests for tick-steps.sh.
#
# Covers:
#   - normal task IDs ("3.2")
#   - consolidated task IDs with `+` ("2.1+2.2+2.3") - regex-meta in awk pattern
#   - already-ticked steps (idempotent skip)
#
# Run: bash .agents/skills/fly/tests/tick-steps-test.sh
# Exits 0 on all-pass, 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TICK="$SCRIPT_DIR/tick-steps.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS+1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL+1))
    echo "  FAIL: $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

make_checklist() {
  local task_id="$1" path="$2"
  cat > "$path" <<EOF
# Test Checklist

## Phase 1

### Task $task_id | Model: sonnet | Mode: subagent

Plan steps:
- [ ] Step 1: write test
- [ ] Step 2: implement
- [ ] Step 3: verify

Review gates:
- [ ] Combined review - Outcome: \`<fill>\`
EOF
}

# --- Test 1: normal task id ---
echo "Test 1: normal task id (3.2)"
F1="$TMP/checklist-normal.md"
make_checklist "3.2" "$F1"
bash "$TICK" "$F1" "3.2" "1" >/dev/null
assert_eq "step 1 ticked" "- [x] Step 1: write test" "$(grep '^- \[.\] Step 1:' "$F1")"
assert_eq "step 2 not ticked" "- [ ] Step 2: implement" "$(grep '^- \[.\] Step 2:' "$F1")"

# --- Test 2: consolidated task id with `+` (THE BUG) ---
echo "Test 2: consolidated task id (2.1+2.2+2.3)"
F2="$TMP/checklist-consolidated.md"
make_checklist "2.1+2.2+2.3" "$F2"
bash "$TICK" "$F2" "2.1+2.2+2.3" "1,2" >/dev/null
assert_eq "step 1 ticked" "- [x] Step 1: write test" "$(grep '^- \[.\] Step 1:' "$F2")"
assert_eq "step 2 ticked" "- [x] Step 2: implement" "$(grep '^- \[.\] Step 2:' "$F2")"
assert_eq "step 3 not ticked" "- [ ] Step 3: verify" "$(grep '^- \[.\] Step 3:' "$F2")"

# --- Test 3: dotted task id with no consolidation - still must work ---
echo "Test 3: dotted task id (final.deferred-resolution)"
F3="$TMP/checklist-dotted.md"
make_checklist "final.deferred-resolution" "$F3"
bash "$TICK" "$F3" "final.deferred-resolution" "3" >/dev/null
assert_eq "step 3 ticked" "- [x] Step 3: verify" "$(grep '^- \[.\] Step 3:' "$F3")"

# --- Test 4: idempotent re-tick (already ticked = no error) ---
echo "Test 4: idempotent re-tick"
F4="$TMP/checklist-retick.md"
make_checklist "1.1" "$F4"
bash "$TICK" "$F4" "1.1" "1" >/dev/null
OUT=$(bash "$TICK" "$F4" "1.1" "1" 2>&1)
assert_eq "re-tick exits OK" "OK 0 checkboxes ticked for task 1.1" "$OUT"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
