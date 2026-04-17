#!/bin/bash
# Structural regression test for /preflight skill
set -e
SKILL=.claude/skills/preflight/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q "^name: preflight$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Preflight$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## Output$" "$SKILL" || { echo "FAIL: Output section"; exit 1; }
grep -q "^## Overwrite Behavior$" "$SKILL" || { echo "FAIL: Overwrite Behavior section"; exit 1; }

grep -q "^## Decisions Preflight Makes$" "$SKILL" || { echo "FAIL: Decisions section"; exit 1; }
grep -q "Phase groupings" "$SKILL" || { echo "FAIL: Phase groupings subsection"; exit 1; }
grep -q "Per-task model assignment" "$SKILL" || { echo "FAIL: Model assignment subsection"; exit 1; }
grep -q "Review policy per task" "$SKILL" || { echo "FAIL: Review policy subsection"; exit 1; }
grep -q "Reviewer model per gate" "$SKILL" || { echo "FAIL: Reviewer model subsection"; exit 1; }
grep -q "Deep-review coverage invariant" "$SKILL" || { echo "FAIL: Deep-review invariant"; exit 1; }
grep -q "TDD audit" "$SKILL" || { echo "FAIL: TDD audit subsection"; exit 1; }

grep -q "^## Steps$" "$SKILL" || { echo "FAIL: Steps section"; exit 1; }
grep -q "^## Terminal Summary$" "$SKILL" || { echo "FAIL: Terminal Summary section"; exit 1; }
grep -q "^## Checklist Format$" "$SKILL" || { echo "FAIL: Checklist Format section"; exit 1; }

echo "OK: preflight structural check passed"
