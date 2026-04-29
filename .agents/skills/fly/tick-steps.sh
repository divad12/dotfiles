#!/usr/bin/env bash
# Bulk-tick plan-step checkboxes for a task in a /fly checklist.
#
# Replaces N per-step Edit-tool calls with one invocation.
#
# Usage:
#   tick-steps.sh <checklist-path> <task-id> <step-nums-csv>
#
# Example:
#   tick-steps.sh plan-checklist.md 3.2 1,2,3,4
#
# Output:
#   OK <N> checkboxes ticked for task <task-id>
#   ERROR <reason>
#
# Exit code: 0 on OK, 1 on ERROR.
#
# Agent-agnostic: uses only awk/sed. macOS + Linux sed -i compat.

set -euo pipefail

CHECKLIST="${1:?checklist-path required}"
TASK_ID="${2:?task-id required}"
STEPS_CSV="${3:?step-nums-csv required}"

if [ ! -f "$CHECKLIST" ]; then
  echo "ERROR checklist file not found: $CHECKLIST"
  exit 1
fi

# Locate the task block: [start_line, end_line) inclusive of start, exclusive of end.
# Start = line beginning "### Task <TASK_ID>" followed by space, colon, dash, or EOL.
# End = next "### " or "## " header after start, or EOF.
#
# Use literal-string match (substr/length), not regex, so consolidated IDs like
# "2.1+2.2+2.3" or paths with "." don't get interpreted as regex metacharacters.
BOUNDS=$(awk -v tid="$TASK_ID" '
  BEGIN { start=0; end=0; prefix = "### Task " tid; plen = length(prefix) }
  {
    if (start == 0) {
      if (substr($0, 1, plen) == prefix) {
        nc = substr($0, plen + 1, 1)
        if (nc == "" || nc == " " || nc == ":" || nc == "-") { start = NR; next }
      }
    } else if (end == 0) {
      if ($0 ~ /^### / || $0 ~ /^## /) { end = NR; exit }
    }
  }
  END {
    if (start == 0) { print "0 0"; exit }
    if (end == 0) { end = NR + 1 }
    print start " " end
  }
' "$CHECKLIST")

START_LINE=$(echo "$BOUNDS" | awk '{print $1}')
END_LINE=$(echo "$BOUNDS" | awk '{print $2}')

if [ "$START_LINE" = "0" ]; then
  echo "ERROR task-id '$TASK_ID' not found (expected header '### Task $TASK_ID ...')"
  exit 1
fi

# Parse CSV into space-separated list.
STEPS=$(echo "$STEPS_CSV" | tr ',' ' ')

# Find the absolute line numbers of each "- [ ]" line within the task block,
# in order of appearance. The Nth unticked (or originally-ticked) step box in
# the block corresponds to step number N.
#
# Requirement: "- [ ] Step <N>: ..." OR "- [ ] [INJECTED] ...", indexed by
# position in the overall step sequence of the task.

# Build an ordered list of line numbers for all step-box lines (both ticked and
# unticked) so that "step number" is a positional index.
# bash 3.2-compatible: no mapfile. Collect lines via while read.
STEP_LINES=()
while IFS= read -r ln; do
  [ -n "$ln" ] && STEP_LINES+=("$ln")
done < <(awk -v s="$START_LINE" -v e="$END_LINE" '
  NR >= s && NR < e {
    if ($0 ~ /^- \[[ x]\] Step [0-9]+:/ || $0 ~ /^- \[[ x]\] \[INJECTED\]/) {
      print NR
    }
  }
' "$CHECKLIST")

TOTAL_STEPS=${#STEP_LINES[@]}

if [ "$TOTAL_STEPS" -eq 0 ]; then
  echo "ERROR task $TASK_ID has no recognizable step lines ('- [ ] Step N:' or '- [ ] [INJECTED]')"
  exit 1
fi

# Select which line numbers to tick.
TO_TICK=()
for n in $STEPS; do
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "ERROR step number '$n' is not a positive integer"
    exit 1
  fi
  if [ "$n" -lt 1 ] || [ "$n" -gt "$TOTAL_STEPS" ]; then
    echo "ERROR step $n out of range for task $TASK_ID (task has $TOTAL_STEPS step(s))"
    exit 1
  fi
  idx=$((n - 1))
  TO_TICK+=("${STEP_LINES[$idx]}")
done

# Apply in-place edits. macOS sed needs `-i ''`; GNU sed uses `-i`.
# Detect once.
SED_INPLACE=(-i)
if sed --version >/dev/null 2>&1; then
  : # GNU sed, -i works
else
  SED_INPLACE=(-i '')
fi

TICKED=0
for ln in "${TO_TICK[@]}"; do
  # Read the current line.
  CURRENT=$(awk -v n="$ln" 'NR==n{print; exit}' "$CHECKLIST")
  if [[ "$CURRENT" == "- [x]"* ]]; then
    # Already ticked: skip silently, no error.
    continue
  fi
  if [[ "$CURRENT" != "- [ ]"* ]]; then
    echo "ERROR line $ln in task $TASK_ID is not a checkbox line: $CURRENT"
    exit 1
  fi
  # Replace just that line's "- [ ]" with "- [x]".
  sed "${SED_INPLACE[@]}" "${ln}s/^- \[ \]/- [x]/" "$CHECKLIST"
  TICKED=$((TICKED + 1))
done

echo "OK $TICKED checkboxes ticked for task $TASK_ID"
exit 0
