#!/bin/bash
# Structural regression test for /fly skill
set -e
SKILL=.claude/skills/fly/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: fly$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Fly$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## State Detection$" "$SKILL" || { echo "FAIL: State Detection section"; exit 1; }

grep -q "^## Template Resolution$" "$SKILL" || { echo "FAIL: Template Resolution section"; exit 1; }
grep -q "^## Per-Task Loop$" "$SKILL" || { echo "FAIL: Per-Task Loop section"; exit 1; }
grep -q "claude-plugins-official/superpowers/\*/skills/subagent-driven-development" "$SKILL" || { echo "FAIL: Glob pattern missing"; exit 1; }

grep -q "^## Phase Gates$" "$SKILL" || { echo "FAIL: Phase Gates section"; exit 1; }
grep -q "^## Final Gate$" "$SKILL" || { echo "FAIL: Final Gate section"; exit 1; }
grep -q "^## Deferred File Handling$" "$SKILL" || { echo "FAIL: Deferred File Handling section"; exit 1; }
grep -q "^## Final Verification$" "$SKILL" || { echo "FAIL: Final Verification section"; exit 1; }

echo "OK: fly structural check passed"
