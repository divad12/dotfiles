#!/usr/bin/env bash
# End-of-run verification sweep for a /fly checklist file.
#
# Consolidates the final-verification checks into one invocation so the
# orchestrator does not burn context on ~15 sequential greps / reads.
#
# Usage:
#   final-verify.sh <checklist-path>
#
# Output: diagnostic lines, then a final line:
#   PASS
#   HALT: <N> issues found:
#     - <check>: <count>
#     ...
#
# WARN and DEFERRED lines are informational and do NOT alter the exit code.
#
# Exit code: 0 on PASS, 1 on HALT. Anything else = infra failure.
#
# Agent-agnostic: relies only on standard Unix tools. No CC-specific paths.

set -euo pipefail

CHECKLIST="${1:?checklist-path required}"

if [ ! -f "$CHECKLIST" ]; then
  echo "HALT: checklist file not found: $CHECKLIST"
  exit 1
fi

PLAN_DIR=$(dirname "$CHECKLIST")
CHECKLIST_BASE=$(basename "$CHECKLIST" .md)
# Strip trailing "-checklist" or "-checklist-<N>" to get plan basename
PLAN_BASE=$(printf '%s' "$CHECKLIST_BASE" | sed -E 's/-checklist(-[0-9]+)?$//')

ISSUES=()
WARNINGS=()
DEFERRED_PATH=""

# --- Check 1: no unticked plan-step or [INJECTED] checkboxes remain ---
# Count unticked boxes up to (but not including) the "## Fly Verification" line.
if grep -qE '^## Fly Verification[[:space:]]*$' "$CHECKLIST"; then
  BEFORE_VERIFY=$(awk '/^## Fly Verification[[:space:]]*$/{exit} {print}' "$CHECKLIST")
else
  BEFORE_VERIFY=$(cat "$CHECKLIST")
fi
UNTICKED=$(printf '%s\n' "$BEFORE_VERIFY" | grep -cE '^- \[ \]' || true)
if [ "$UNTICKED" -gt 0 ]; then
  ISSUES+=("unticked checkboxes: $UNTICKED")
  printf '%s\n' "$BEFORE_VERIFY" | grep -nE '^- \[ \]' | head -5 | while IFS= read -r line; do
    echo "  unticked: $line"
  done
fi

# --- Check 2: no SHA slots contain <fill> ---
SHA_FILL=$(grep -cE 'SHA: `<fill>`' "$CHECKLIST" || true)
if [ "$SHA_FILL" -gt 0 ]; then
  ISSUES+=("unfilled SHA slots: $SHA_FILL")
fi

# --- Check 3: no Outcome slots contain <fill> ---
OUTCOME_FILL=$(grep -cE 'Outcome: `<fill>`' "$CHECKLIST" || true)
if [ "$OUTCOME_FILL" -gt 0 ]; then
  ISSUES+=("unfilled Outcome slots: $OUTCOME_FILL")
fi

# --- Check 4: Resolution Action slots must not be <fill>/ignored/skipped ---
ACTION_FILL=$(grep -cE 'Action: `<fill>`' "$CHECKLIST" || true)
ACTION_IGNORED=$(grep -cE 'Action: `ignored`' "$CHECKLIST" || true)
ACTION_SKIPPED=$(grep -cE 'Action: `skipped`' "$CHECKLIST" || true)
ACTION_BAD=$((ACTION_FILL + ACTION_IGNORED + ACTION_SKIPPED))
if [ "$ACTION_BAD" -gt 0 ]; then
  ISSUES+=("bad Resolution Action slots (<fill>/ignored/skipped): $ACTION_BAD")
fi

# --- Check 5: every Outcome line uses structured format (contains findings=) ---
# Per-task Outcomes must have findings=. Phase-gate Outcomes use tests_pass=
# instead and are checked separately in check 8.
OUTCOME_NO_FINDINGS=$(grep -E 'Outcome: `' "$CHECKLIST" \
  | grep -v 'Outcome: `<fill>`' \
  | grep -v 'findings=' \
  | grep -vc 'tests_pass=' || true)
if [ "$OUTCOME_NO_FINDINGS" -gt 0 ]; then
  ISSUES+=("Outcome lines missing findings= token: $OUTCOME_NO_FINDINGS")
fi

# --- Check 6: every findings= line also has review: token ---
FINDINGS_NO_REVIEW=$(grep -E 'findings=' "$CHECKLIST" \
  | grep -vc 'review:' || true)
if [ "$FINDINGS_NO_REVIEW" -gt 0 ]; then
  ISSUES+=("findings= lines missing review: token: $FINDINGS_NO_REVIEW")
fi

# --- Check 7: for every review: <path>, verify the artifact file ---
# Extract paths following "review: " up to next whitespace, backtick, comma, paren, or semicolon.
# Require .md or .txt suffix so stray "review: 0" tokens (e.g. from a malformed
# Outcome line near "regressions=0") don't get mistaken for paths.
REVIEW_PATHS=$(grep -oE 'review: [^ `),;]+\.(md|txt)' "$CHECKLIST" | awk '{print $2}' | sed 's/[,);]*$//' | sort -u)
REVIEW_BAD=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  case "$rel" in
    /*) abs="$rel" ;;
    *)  abs="$PLAN_DIR/$rel" ;;
  esac
  if [ ! -f "$abs" ]; then
    REVIEW_BAD=$((REVIEW_BAD + 1))
    echo "  missing review artifact: $abs"
    continue
  fi
  SIZE=$(wc -c < "$abs" | tr -d ' ')
  NO_ISSUES=0
  if grep -qE '^No issues\.$' "$abs"; then
    NO_ISSUES=1
  fi
  if [ "$SIZE" -le 500 ] && [ "$NO_ISSUES" -ne 1 ]; then
    REVIEW_BAD=$((REVIEW_BAD + 1))
    echo "  review artifact too small (<=500 bytes, no 'No issues.'): $abs"
    continue
  fi
  if ! grep -qE '^findings-count:' "$abs"; then
    REVIEW_BAD=$((REVIEW_BAD + 1))
    echo "  review artifact missing YAML front-matter findings-count: $abs"
    continue
  fi
  # Match this review path to its Outcome line to find the advertised findings=N.
  # Escape ERE metacharacters so paths like task-32+33-combined.md don't
  # turn `+` into a one-or-more quantifier.
  esc_rel=$(printf '%s' "$rel" | sed 's/[][\\.$*/^+?(){}|]/\\&/g')
  OUTCOME_LINE=$(grep -E "review: ${esc_rel}(\$|[^A-Za-z0-9_./-])" "$CHECKLIST" | head -1 || true)
  ADV_COUNT=$(printf '%s' "$OUTCOME_LINE" | grep -oE 'findings=[0-9]+' | head -1 | sed 's/findings=//')
  if [ -z "${ADV_COUNT:-}" ]; then
    REVIEW_BAD=$((REVIEW_BAD + 1))
    echo "  could not extract findings=N for review: $abs"
    continue
  fi
  # Reviewer-override spec is `### Finding` (3 hash), but deep-review sub-reviewers
  # sometimes emit `#### Finding` (4 hash). Accept either to avoid false HALTs.
  ACTUAL_COUNT=$(grep -cE '^#{3,4} Finding ' "$abs" || true)
  if [ "$ADV_COUNT" = "0" ]; then
    # Acceptable: zero findings WITH "No issues." literal, OR actual zero ### Finding headers.
    if [ "$NO_ISSUES" -ne 1 ] && [ "$ACTUAL_COUNT" -ne 0 ]; then
      REVIEW_BAD=$((REVIEW_BAD + 1))
      echo "  findings=0 but artifact has $ACTUAL_COUNT Finding headers and no 'No issues.' line: $abs"
      continue
    fi
  else
    if [ "$ACTUAL_COUNT" != "$ADV_COUNT" ]; then
      REVIEW_BAD=$((REVIEW_BAD + 1))
      echo "  findings count mismatch: advertised=$ADV_COUNT actual=$ACTUAL_COUNT in $abs"
      continue
    fi
  fi
done <<< "$REVIEW_PATHS"

if [ "$REVIEW_BAD" -gt 0 ]; then
  ISSUES+=("review artifact problems: $REVIEW_BAD")
fi

# --- Check 8: Phase Gate Outcome lines must begin with tests_pass=N tests_fail=N regressions=0; ---
# Phase gate lines live after "## Phase Gate" headers; we detect them by being
# Outcome lines that contain regressions= token (phase gate contract).
# All filled Outcome lines that have "tests_pass=" are phase-gate Outcomes.
PHASE_GATE_BAD=0
while IFS= read -r line; do
  # Strip leading "... Outcome: `" prefix, keep just the content between backticks.
  content=$(printf '%s' "$line" | sed -E 's/^.*Outcome: `([^`]*)`.*$/\1/')
  if ! printf '%s' "$content" | grep -qE '^tests_pass=[0-9]+ tests_fail=[0-9]+ regressions=0;'; then
    PHASE_GATE_BAD=$((PHASE_GATE_BAD + 1))
    echo "  phase-gate Outcome malformed: $line"
  fi
done < <(grep -E 'Outcome: `[^`]*tests_pass=' "$CHECKLIST" || true)

if [ "$PHASE_GATE_BAD" -gt 0 ]; then
  ISSUES+=("phase-gate Outcome lines malformed: $PHASE_GATE_BAD")
fi

# --- Check 9: fabrication-pattern warning (soft) ---
# If > 50% of filled Outcome lines have findings=0, warn.
TOTAL_OUTCOMES=$(grep -cE 'findings=[0-9]+' "$CHECKLIST" || true)
ZERO_OUTCOMES=$(grep -cE 'findings=0( |$|;)' "$CHECKLIST" || true)
if [ "$TOTAL_OUTCOMES" -gt 0 ]; then
  # Integer compare: zero*2 > total  <=>  zero/total > 0.5
  if [ $((ZERO_OUTCOMES * 2)) -gt "$TOTAL_OUTCOMES" ]; then
    WARNINGS+=("WARN: $ZERO_OUTCOMES of $TOTAL_OUTCOMES Outcome lines report findings=0 (>50%). Possible fabrication pattern; spot-check a few review artifacts.")
  fi
fi

# --- Check 10: deferred file ---
DEF_FILE="$PLAN_DIR/${PLAN_BASE}-deferred.md"
if [ -f "$DEF_FILE" ]; then
  DEFERRED_PATH="$DEF_FILE"
fi

# --- Emit output ---
for w in "${WARNINGS[@]:-}"; do
  [ -n "$w" ] && echo "$w"
done

if [ -n "$DEFERRED_PATH" ]; then
  echo "DEFERRED: items exist in $DEFERRED_PATH - user must be informed:"
  echo "----- BEGIN DEFERRED -----"
  cat "$DEFERRED_PATH"
  echo "----- END DEFERRED -----"
fi

if [ "${#ISSUES[@]}" -eq 0 ]; then
  echo "PASS"
  exit 0
fi

echo "HALT: ${#ISSUES[@]} issues found:"
for i in "${ISSUES[@]}"; do
  echo "  - $i"
done
exit 1
