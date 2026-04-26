#!/bin/bash
# Structural regression test for /deep-review skill
set -e
SKILL="${SKILL:-.claude/skills/deep-review/SKILL.md}"

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: deep-review$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Deep Review$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

grep -q "^### 2.5. Detect the invoking agent$" "$SKILL" || { echo "FAIL: invoking-agent detection section"; exit 1; }
grep -qi "current orchestrator.*Codex" "$SKILL" || { echo "FAIL: Codex orchestrator detection language"; exit 1; }
grep -qi "current orchestrator.*Claude Code" "$SKILL" || { echo "FAIL: Claude Code orchestrator detection language"; exit 1; }
grep -qi "Codex.*independent reviewer.*Claude Code" "$SKILL" || { echo "FAIL: Codex must dispatch Claude Code reviewer"; exit 1; }
grep -qi "Claude Code.*independent reviewer.*Codex" "$SKILL" || { echo "FAIL: Claude Code must dispatch Codex reviewer"; exit 1; }

grep -q "^#### When the independent reviewer is Codex$" "$SKILL" || { echo "FAIL: Codex reviewer command section"; exit 1; }
grep -q "codex review --uncommitted" "$SKILL" || { echo "FAIL: Codex uncommitted command"; exit 1; }
grep -q "codex review --base main" "$SKILL" || { echo "FAIL: Codex base command"; exit 1; }

grep -q "^#### When the independent reviewer is Claude Code$" "$SKILL" || { echo "FAIL: Claude Code reviewer command section"; exit 1; }
grep -q "claude -p" "$SKILL" || { echo "FAIL: Claude Code non-interactive command"; exit 1; }
grep -q "git diff --cached > /tmp/deep-review-staged.patch" "$SKILL" || { echo "FAIL: staged diff preservation"; exit 1; }

grep -qi "Reviewed by:.*independent reviewer" "$SKILL" || { echo "FAIL: summary uses dynamic independent reviewer"; exit 1; }
grep -qi "Re-run the same independent reviewer" "$SKILL" || { echo "FAIL: verification uses same reviewer selection"; exit 1; }

echo "OK: deep-review structural check passed"
