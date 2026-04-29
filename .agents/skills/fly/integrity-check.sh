#!/usr/bin/env bash
# Per-task integrity check for /fly
#
# Verifies that reviewer subagents actually dispatched, did real work, and
# ran on the EXACT model the checklist requires for a given task. Uses
# Claude Code's subagent JSONL transcripts at:
#   ~/.claude/projects/<project-hash>/<session-id>/subagents/agent-*.jsonl
#
# Usage:
#   integrity-check.sh <task-id> <plan-dir> <task-sha>
#
# Output: single line to stdout:
#   PASS
#   HALT: <reason>
#
# Exit code: 0 on PASS, 1 on HALT. Anything else = infra failure.
#
# Checks performed:
#   1. Expected review files exist on disk.
#   2. Each file's mtime is after the task commit (no stale review).
#   3. Each file is non-trivially sized (>500 bytes).
#   4. A subagent transcript shows a Write to each review file path
#      (catches orchestrator-forged files).
#   5. The writing subagent made >=3 tool calls (real engagement).
#   6. The writing subagent's `message.model` matches the checklist's
#      reviewer-model annotation for that task + review type. This is
#      the post-hoc enforcement of the dispatch-reviewer.sh contract -
#      catches silent model downgrades (e.g. sonnet checklist annotation
#      but haiku-dispatched reviewer to save cost).
#
# Agent-agnostic caveat: this check relies on the CC subagent transcript
# layout. On non-CC agents (Codex, Cursor, etc.) this path will not exist;
# callers should skip the check in that case.

set -euo pipefail

TASK_ID="${1:?task-id required}"
PLAN_DIR="${2:?plan-dir required}"
TASK_SHA="${3:?task-sha required}"

REVIEWS_DIR="$PLAN_DIR/reviews"

# Locate current session's transcript + subagents dir.
#
# CC stores projects at ~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
# with subagent transcripts at ~/.claude/projects/<encoded-cwd>/<session-id>/subagents/agent-*.jsonl.
#
# We find the project dir whose encoded cwd matches our current working dir,
# then pick the newest <session-id>.jsonl inside it.

CWD="$(pwd)"
# CC encoding: every non-alphanumeric character becomes `-`. Examples:
#   /Users/david/Dropbox (Personal)/code/dotfiles
#     -> -Users-david-Dropbox--Personal--code-dotfiles
#   /path/to/project
#     -> -path-to-project
# No dash collapsing: consecutive non-alphanumerics produce consecutive dashes.
ENCODED_CWD="$(printf '%s' "$CWD" | sed 's|[^A-Za-z0-9]|-|g')"
PROJECT_DIR="$HOME/.claude/projects/$ENCODED_CWD"

if [ ! -d "$PROJECT_DIR" ]; then
  # Fall back: newest project dir that contains a .jsonl file modified in the
  # last hour. We detect "active" project dirs by looking at file mtime of
  # session files inside, not the dir mtime itself.
  PROJECT_DIR=$(find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' -mmin -60 2>/dev/null \
    | xargs -n1 dirname 2>/dev/null \
    | sort -u \
    | head -1 || true)
fi

if [ -z "${PROJECT_DIR:-}" ] || [ ! -d "$PROJECT_DIR" ]; then
  echo "HALT: cannot locate CC project dir for $CWD (expected $HOME/.claude/projects/$ENCODED_CWD)"
  exit 1
fi

SESSION_FILE=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1 || true)
[ -n "$SESSION_FILE" ] || { echo "HALT: no session .jsonl in $PROJECT_DIR"; exit 1; }

SESSION_ID=$(basename "$SESSION_FILE" .jsonl)
SUBAGENT_DIR="$PROJECT_DIR/$SESSION_ID/subagents"

[ -d "$SUBAGENT_DIR" ] || { echo "HALT: subagents dir not found at $SUBAGENT_DIR"; exit 1; }

# Task commit timestamp for mtime comparison
TASK_TIME=$(git log -1 --format=%ct "$TASK_SHA" 2>/dev/null) \
  || { echo "HALT: cannot resolve task sha $TASK_SHA in git log"; exit 1; }

# Determine which review files are expected for this task:
#   task-<id>-spec.md + task-<id>-code.md   (standard)
#   task-<id>-combined.md                    (combined-review shortcut when phase has /deep-review gate)
#   batch-*-spec.md / -code.md              (batched tasks; reviews live on the last task in the batch)
#
# We check by existence: whichever exists is what was expected.

EXPECTED_FILES=()
if [ -f "$REVIEWS_DIR/task-$TASK_ID-combined.md" ]; then
  EXPECTED_FILES=("$REVIEWS_DIR/task-$TASK_ID-combined.md")
elif [ -f "$REVIEWS_DIR/task-$TASK_ID-spec.md" ] && [ -f "$REVIEWS_DIR/task-$TASK_ID-code.md" ]; then
  EXPECTED_FILES=("$REVIEWS_DIR/task-$TASK_ID-spec.md" "$REVIEWS_DIR/task-$TASK_ID-code.md")
else
  # No expected review files on disk. This is drift unless the caller is
  # invoking integrity-check on a batched task's non-last position (which
  # fly should NOT do - fly's per-task loop is responsible for skipping
  # the integrity check on batched non-last tasks).
  echo "HALT: expected review files not found for task $TASK_ID (checked: task-$TASK_ID-combined.md, task-$TASK_ID-spec.md + task-$TASK_ID-code.md). If this is a batched non-last task, fly should skip integrity-check for it; if not, reviewer dispatches were skipped."
  exit 1
fi

# Check each review file: mtime after commit, non-trivial size.
for F in "${EXPECTED_FILES[@]}"; do
  MTIME=$(stat -f %m "$F" 2>/dev/null || stat -c %Y "$F" 2>/dev/null) \
    || { echo "HALT: stat failed on $F"; exit 1; }
  [ "$MTIME" -gt "$TASK_TIME" ] \
    || { echo "HALT: review file mtime <= task commit time: $F"; exit 1; }
  SIZE=$(wc -c < "$F")
  [ "$SIZE" -gt 500 ] \
    || { echo "HALT: review file suspiciously small ($SIZE bytes, expected >500): $F"; exit 1; }
done

# For each expected review file, verify a subagent transcript shows a real
# dispatch that wrote to that path with non-trivial tool-use activity.
for F in "${EXPECTED_FILES[@]}"; do
  # Find subagent jsonl whose transcript contains a Write to this path.
  #
  # Two correctness requirements:
  # 1. `|| true` on each pipeline: under set -e + pipefail, a no-match grep
  #    returns 1, pipefail propagates, command substitution trips set -e and
  #    aborts the script BEFORE reaching the basename fallback. Suppress to
  #    allow graceful empty-string fallthrough.
  # 2. Order agents NEWEST-FIRST before grep so head -1 picks the most recent
  #    writer, not the lex-first one. Re-reviews after fix-loops write the
  #    SAME review file again - if we matched the original (low-tool-use)
  #    reviewer, we'd HALT spuriously even though the latest re-reviewer was
  #    fine. `ls -t` sorts by mtime newest-first; xargs preserves order;
  #    grep -l outputs in command-line order; head -1 = latest writer.
  AGENT_FILES=$(ls -t "$SUBAGENT_DIR"/agent-*.jsonl 2>/dev/null || true)
  WRITING_AGENT=""
  BASENAME=$(basename "$F")
  if [ -n "$AGENT_FILES" ]; then
    # Reviewer subagents are dispatched with a user-message prompt that names
    # the target review file path. Match the agent by prompt-content (the
    # FIRST jsonl entry whose `"role":"user"` message text mentions the
    # review path or basename). This is more robust than detecting the write
    # tool_use directly: reviewers may use Write, Edit, mcp__Desktop_Commander
    # __write_file, or even a Bash heredoc (`cat > file.md << EOF`) - all
    # produce a valid review file but only some carry `"file_path":"<F>"` in
    # the JSONL. Prompt-text matches catch all of them.
    for AGENT_FILE in $AGENT_FILES; do
      # First user message in the JSONL - has `"type":"user"` near the top.
      # Match either the full path or just the basename in the message body.
      if head -1 "$AGENT_FILE" 2>/dev/null | grep -qE "$F|$BASENAME"; then
        WRITING_AGENT="$AGENT_FILE"
        break
      fi
    done
  fi
  if [ -z "$WRITING_AGENT" ]; then
    echo "HALT: no subagent transcript found that wrote to $F. Reviewer was likely NOT dispatched; review file may have been forged by the orchestrator."
    exit 1
  fi

  # Subagent must have done real work: expect >= 3 tool_use entries
  # (at minimum: Read diff/context, Read review target, Write final review).
  TOOL_USES=$(grep -c '"type":"tool_use"' "$WRITING_AGENT" || true)
  if [ "$TOOL_USES" -lt 3 ]; then
    echo "HALT: reviewer $WRITING_AGENT made only $TOOL_USES tool calls (expected >=3 for real engagement with diff); possibly trivial or fabricated review."
    exit 1
  fi

  # ----- Reviewer-model verification ----------------------------------------
  #
  # Pull the reviewer's actual model from the JSONL `message.model` field on
  # the first assistant entry, normalize it to a family (haiku|sonnet|opus),
  # and compare against the model the checklist annotated. Catches silent
  # downgrades (e.g. sonnet → haiku to save cost) that the dispatch-reviewer
  # contract is meant to prevent.
  #
  # Determine review type from the file basename so we can ask the checklist
  # for the right reviewer line.
  BASENAME=$(basename "$F")
  case "$BASENAME" in
    task-*-spec.md)     REVIEW_TYPE="spec"     ;;
    task-*-code.md)     REVIEW_TYPE="code"     ;;
    task-*-combined.md) REVIEW_TYPE="combined" ;;
    batch-*-combined.md) REVIEW_TYPE="batch"   ;;
    phase-*-deep-review.md) REVIEW_TYPE="phase" ;;
    final-deep-review.md) REVIEW_TYPE="final"  ;;
    *)
      # Unknown filename pattern - skip model check, but log a warning so
      # the user can extend this script if a new review type was added.
      echo "PASS (warn: unknown review filename '$BASENAME', skipping model check)"
      continue
      ;;
  esac

  # Find the checklist file. Convention: lives at $PLAN_DIR/checklist.md or
  # similarly-named sibling. Walk up from $PLAN_DIR.
  CHECKLIST=""
  for candidate in "$PLAN_DIR/checklist.md" "$PLAN_DIR/../checklist.md"; do
    [ -f "$candidate" ] && { CHECKLIST="$candidate"; break; }
  done
  if [ -z "$CHECKLIST" ]; then
    # Try preflight's split-checklist naming.
    CHECKLIST=$(ls "$PLAN_DIR"/*-checklist*.md 2>/dev/null | head -1 || true)
  fi

  if [ -n "$CHECKLIST" ]; then
    # Extract the expected reviewer model for this task + review type.
    # Reuses the same parsing logic as dispatch-reviewer.sh; kept here as
    # an awk pipeline so integrity-check stays self-contained.
    EXPECTED_MODEL=""
    case "$REVIEW_TYPE" in
      spec|code|combined)
        TASK_BLOCK=$(awk -v id="$TASK_ID" '
          /^### Task / { in_block = ($0 ~ "^### Task " id "([^0-9]|$)") }
          /^### (Phase|Final|Task) / && !match($0, "^### Task " id "([^0-9]|$)") && in_block { in_block = 0 }
          in_block { print }
        ' "$CHECKLIST" 2>/dev/null || true)
        case "$REVIEW_TYPE" in
          spec)     LABEL="Spec review" ;;
          code)     LABEL="Code review" ;;
          combined) LABEL="Combined review" ;;
        esac
        LINE=$(printf '%s\n' "$TASK_BLOCK" | grep -E "^- \[[ x]\] $LABEL \(reviewer: [a-zA-Z0-9_-]+\)" | head -1 || true)
        EXPECTED_MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
        ;;
      batch)
        TASK_BLOCK=$(awk -v id="$TASK_ID" '
          /^### Task / { in_block = ($0 ~ "^### Task " id "([^0-9]|$)") }
          /^### (Phase|Final|Task) / && !match($0, "^### Task " id "([^0-9]|$)") && in_block { in_block = 0 }
          in_block { print }
        ' "$CHECKLIST" 2>/dev/null || true)
        LINE=$(printf '%s\n' "$TASK_BLOCK" | grep -E "^- \[[ x]\] Batch review \(reviewer: [a-zA-Z0-9_-]+\)" | head -1 || true)
        EXPECTED_MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
        ;;
      phase)
        # task-id is the phase number for phase reviews.
        LINE=$(grep -E "^### Phase $TASK_ID Gate \(reviewer: [a-zA-Z0-9_-]+\)" "$CHECKLIST" | head -1 || true)
        EXPECTED_MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
        ;;
      final)
        LINE=$(grep -E "Final Gate.*\(reviewer: [a-zA-Z0-9_-]+\)" "$CHECKLIST" | head -1 || true)
        EXPECTED_MODEL=$(printf '%s' "$LINE" | sed -n 's/.*(reviewer: \([a-zA-Z0-9_-]*\)).*/\1/p')
        ;;
    esac

    # Pull actual model from the subagent's first assistant entry.
    # Format: ..."model":"claude-haiku-4-5-20251001",..."type":"message"...
    ACTUAL_MODEL_RAW=$(grep -m1 '"type":"assistant"' "$WRITING_AGENT" 2>/dev/null \
      | sed -n 's/.*"model":"\([^"]*\)".*/\1/p' \
      | head -1 || true)

    # Normalize claude-<family>-... to <family>.
    case "$ACTUAL_MODEL_RAW" in
      claude-haiku-*)   ACTUAL_FAMILY="haiku" ;;
      claude-sonnet-*)  ACTUAL_FAMILY="sonnet" ;;
      claude-opus-*)    ACTUAL_FAMILY="opus" ;;
      "") ACTUAL_FAMILY="" ;;
      *) ACTUAL_FAMILY="$ACTUAL_MODEL_RAW" ;;
    esac

    if [ -n "$EXPECTED_MODEL" ] && [ -n "$ACTUAL_FAMILY" ]; then
      if [ "$EXPECTED_MODEL" != "$ACTUAL_FAMILY" ]; then
        echo "HALT: reviewer model drift on $F. Checklist annotation says reviewer-model=$EXPECTED_MODEL but the dispatched subagent ran on $ACTUAL_FAMILY (raw: $ACTUAL_MODEL_RAW). The checklist is the contract; if the model is wrong, halt and edit the checklist - do not silently dispatch a different model."
        exit 1
      fi
    fi
    # If either side is empty, fall through (e.g. checklist lacks the
    # annotation, or transcript format changed). Don't HALT on missing
    # data - the existing file/mtime/dispatch checks already gate fakery,
    # and a missing annotation is a checklist defect for /preflight to fix.
  fi
done

echo "PASS"
exit 0
