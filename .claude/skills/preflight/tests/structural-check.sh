#!/bin/bash
# Structural regression test for /preflight skill
set -e
SKILL=.claude/skills/preflight/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: preflight$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Preflight$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

echo "OK: preflight structural check passed"
