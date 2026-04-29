#!/usr/bin/env bash
# Reviewer-dispatch contract resolver for /fly.
#
# Reads the checklist + extracts the EXACT reviewer model the task requires,
# the absolute review-file path, and the diff command for the review scope.
# Orchestrator MUST run this script before every reviewer Task dispatch and
# copy the emitted MODEL/PATH/DIFF values verbatim into the Task call. The
# orchestrator never types the model string itself - that's how reviewer-
# model drift sneaks in (e.g. silently downgrading sonnet to haiku to save
# cost). Combined with integrity-check.sh's post-hoc model verification,
# this gives belt-and-suspenders enforcement.
#
# Usage:
#   dispatch-reviewer.sh <checklist-path> <task-id> <review-type> <task-sha-or-range>
#
# Args:
#   checklist-path:   absolute or cwd-relative path to checklist.md
#   task-id:          e.g. "1", "5", "12.3", "final.deferred-resolution"
#                     For phase gates pass "phase-N"; for final gate "final".
#   review-type:      one of: spec | code | combined | batch | phase | final
#   task-sha-or-range: single sha for per-task; sha-range "<base>^..<head>"
#                     for batched / phase / final.
#
# Output (stdout, ENV-style key=value lines, easy to parse):
#   MODEL=<sonnet|haiku|opus>
#   REVIEW_PATH=<absolute path>
#   DIFF_CMD=<git command>
#   PROMPT_HEADER_NOTE=<one-line nag for the prompt asking the reviewer to
#                      include "reviewer-model: <model>" in the YAML header>
#
# Exit code:
#   0 on success - orchestrator parses stdout + uses values verbatim.
#   1 on missing model / parse failure - orchestrator HALTs and surfaces.

set -euo pipefail

CHECKLIST="${1:?checklist path required}"
TASK_ID="${2:?task-id required}"
REVIEW_TYPE="${3:?review-type required (spec|code|combined|batch|phase|final)}"
TASK_SHA_OR_RANGE="${4:?task-sha-or-range required}"

[ -f "$CHECKLIST" ] || { echo "ERROR: checklist not found: $CHECKLIST" >&2; exit 1; }

PLAN_DIR="$(cd "$(dirname "$CHECKLIST")" && pwd)"
REVIEWS_DIR="$PLAN_DIR/reviews"

# Map review-type to expected review file basename.
case "$REVIEW_TYPE" in
  spec)     REVIEW_FILE="task-$TASK_ID-spec.md" ;;
  code)     REVIEW_FILE="task-$TASK_ID-code.md" ;;
  combined) REVIEW_FILE="task-$TASK_ID-combined.md" ;;
  batch)    REVIEW_FILE="batch-$TASK_ID-combined.md" ;;
  phase)    REVIEW_FILE="phase-$TASK_ID-deep-review.md" ;;
  final)    REVIEW_FILE="final-deep-review.md" ;;
  *) echo "ERROR: invalid review-type: $REVIEW_TYPE" >&2; exit 1 ;;
esac

REVIEW_PATH="$REVIEWS_DIR/$REVIEW_FILE"

# ----------------------------------------------------------------------------
# Parse the reviewer model from the checklist.
#
# Sources, in priority order:
#   1. Per-review-gate annotation: `<Spec|Code|Combined> review (reviewer: <model>)`
#      within the matching `### Task <id>` block.
#   2. Phase / final gate header: `### Phase N Gate (reviewer: <model>)` or
#      `### Final Gate (reviewer: <model>)`.
#
# Source #1 is canonical for per-task reviews. The script prints exactly what
# the checklist says, with no fallback to the task's implementer model - if
# the reviewer model is missing we HALT, because that's a checklist defect
# preflight should have caught.
# ----------------------------------------------------------------------------

case "$REVIEW_TYPE" in
  spec|code|combined|batch)
    # Find the task's section, then grep for the matching reviewer line.
    # Use literal-string match (substr/length), not regex - so consolidated IDs
    # like "2.1+2.2+2.3" or dotted IDs like "final.deferred-resolution" don't
    # get interpreted as regex metacharacters.
    TASK_BLOCK=$(awk -v id="$TASK_ID" '
      function is_task_header(line, want,    prefix, plen, nc) {
        prefix = "### Task " want
        plen = length(prefix)
        if (substr(line, 1, plen) != prefix) return 0
        nc = substr(line, plen + 1, 1)
        return (nc == "" || nc == " " || nc == ":" || nc == "-")
      }
      /^### Task / { in_block = is_task_header($0, id) }
      /^### (Phase|Final|Task) / && !is_task_header($0, id) && in_block { in_block = 0 }
      in_block { print }
    ' "$CHECKLIST")
    [ -n "$TASK_BLOCK" ] || { echo "ERROR: no task block found for id=$TASK_ID in $CHECKLIST" >&2; exit 1; }

    case "$REVIEW_TYPE" in
      spec)     LABEL="Spec review" ;;
      code)     LABEL="Code review" ;;
      combined) LABEL="Combined review" ;;
      batch)    LABEL="Batch review" ;;
    esac

    # Match e.g. `- [ ] Spec review (reviewer: haiku) - Outcome: ...`
    # Tolerate `- [x]` already ticked.
    LINE=$(printf '%s\n' "$TASK_BLOCK" | grep -E "^- \[[ x]\] $LABEL \(reviewer: [a-zA-Z0-9_-]+\)" | head -1 || true)
    [ -n "$LINE" ] || { echo "ERROR: reviewer line '$LABEL (reviewer: ...)' not found in task $TASK_ID block" >&2; exit 1; }

    MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
    ;;
  phase)
    # `### Phase N Gate (reviewer: <model>)`
    LINE=$(grep -E "^### Phase $TASK_ID Gate \(reviewer: [a-zA-Z0-9_-]+\)" "$CHECKLIST" | head -1 || true)
    [ -n "$LINE" ] || { echo "ERROR: '### Phase $TASK_ID Gate (reviewer: ...)' header not found in $CHECKLIST" >&2; exit 1; }
    MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
    ;;
  final)
    # `## Final Gate: /deep-review over <scope>` followed somewhere by the
    # Outcome line; or a `(reviewer: <model>)` annotation in the same section.
    # Try a few patterns.
    LINE=$(grep -E "Final Gate.*\(reviewer: [a-zA-Z0-9_-]+\)" "$CHECKLIST" | head -1 || true)
    if [ -z "$LINE" ]; then
      LINE=$(grep -E "## Final Gate" "$CHECKLIST" | head -1 || true)
    fi
    [ -n "$LINE" ] || { echo "ERROR: Final Gate section not found in $CHECKLIST" >&2; exit 1; }
    MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
    [ -n "$MODEL" ] || { echo "ERROR: Final Gate found but no '(reviewer: <model>)' annotation; edit checklist." >&2; exit 1; }
    ;;
esac

[ -n "$MODEL" ] || { echo "ERROR: failed to parse reviewer model from $CHECKLIST for task=$TASK_ID type=$REVIEW_TYPE" >&2; exit 1; }

# ----------------------------------------------------------------------------
# Build the diff command for the review scope.
# ----------------------------------------------------------------------------
case "$TASK_SHA_OR_RANGE" in
  *..*)  DIFF_CMD="git diff $TASK_SHA_OR_RANGE" ;;
  *)     DIFF_CMD="git show $TASK_SHA_OR_RANGE" ;;
esac

# ----------------------------------------------------------------------------
# Emit the contract.
# ----------------------------------------------------------------------------
cat <<EOF
MODEL=$MODEL
REVIEW_PATH=$REVIEW_PATH
DIFF_CMD=$DIFF_CMD
PROMPT_HEADER_NOTE=Include "reviewer-model: $MODEL" in the review file's YAML header (verbatim - integrity-check verifies this matches the dispatched model).
EOF

exit 0
