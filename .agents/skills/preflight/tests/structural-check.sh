#!/bin/bash
# Structural regression test for /preflight skill.
# Checks the SKILL.md body still has the load-bearing decision sections
# and that all bundled reference files exist.
set -e
SKILL_DIR=.agents/skills/preflight
SKILL=$SKILL_DIR/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }

# Frontmatter + heading
grep -q "^name: preflight$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Preflight$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

# Top-level sections that must stay in the body
grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Tunable Constants$" "$SKILL" || { echo "FAIL: Tunable Constants section"; exit 1; }
grep -q "^## Bundled References$" "$SKILL" || { echo "FAIL: Bundled References section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## Output$" "$SKILL" || { echo "FAIL: Output section"; exit 1; }
grep -q "^## Overwrite Behavior$" "$SKILL" || { echo "FAIL: Overwrite Behavior section"; exit 1; }
grep -q "^## Decisions Preflight Makes$" "$SKILL" || { echo "FAIL: Decisions section"; exit 1; }
grep -q "^## Steps$" "$SKILL" || { echo "FAIL: Steps section"; exit 1; }

# Decision logic sub-sections (these stay in body - they're judgment rules
# the model needs while computing decisions, not literal templates)
grep -q "Phase groupings" "$SKILL" || { echo "FAIL: Phase groupings subsection"; exit 1; }
grep -q "Task consolidation pass" "$SKILL" || { echo "FAIL: Task consolidation subsection"; exit 1; }
grep -q "LOC estimation + inline mode" "$SKILL" || { echo "FAIL: LOC estimation subsection"; exit 1; }
grep -q "Per-task model assignment" "$SKILL" || { echo "FAIL: Model assignment subsection"; exit 1; }
grep -q "Review policy per task" "$SKILL" || { echo "FAIL: Review policy subsection"; exit 1; }
grep -q "Phase normal review" "$SKILL" || { echo "FAIL: Phase normal review subsection"; exit 1; }
grep -q "Reviewer model per gate" "$SKILL" || { echo "FAIL: Reviewer model subsection"; exit 1; }
grep -q "Session deep-review gate" "$SKILL" || { echo "FAIL: Session deep-review gate subsection"; exit 1; }
grep -q "Deep-review coverage invariant" "$SKILL" || { echo "FAIL: Deep-review invariant"; exit 1; }
grep -q "TDD audit" "$SKILL" || { echo "FAIL: TDD audit subsection"; exit 1; }
grep -q "Manual-test convertibility analysis" "$SKILL" || { echo "FAIL: Convertibility analysis subsection"; exit 1; }

# Bundled reference files must exist on disk and be cited from SKILL.md
for ref in \
    references/checklist-format.md \
    references/per-session-plan-format.md \
    references/terminal-summary.md \
    references/session-breakdown-prompt.md \
    references/synthetic-tasks/integration-test.md \
    references/synthetic-tasks/codex-browser-verify.md \
    references/synthetic-tasks/deferred-resolution.md ; do
  test -f "$SKILL_DIR/$ref" || { echo "FAIL: missing reference file $ref"; exit 1; }
  grep -qF "$ref" "$SKILL" || { echo "FAIL: SKILL.md does not cite $ref"; exit 1; }
done

# Deferred-resolution must enforce mandatory user-facing impact framing
# for all surfaced items (including latent ones), per the global
# AGENTS.md / CLAUDE.md "Surfacing to the User" rule.
DEFERRED_REF="$SKILL_DIR/references/synthetic-tasks/deferred-resolution.md"
grep -qi "User-facing impact:" "$DEFERRED_REF" || { echo "FAIL: deferred-resolution missing User-facing impact line"; exit 1; }
grep -qi "mandatory for EVERY surfaced item\|exact format" "$DEFERRED_REF" || { echo "FAIL: deferred-resolution does not mark format as mandatory"; exit 1; }
grep -qi "no third bucket\|There is no third bucket" "$DEFERRED_REF" || { echo "FAIL: deferred-resolution missing latent-also-goes-to-bucket-B rule"; exit 1; }

echo "OK: preflight structural check passed"

# Integration test: run /preflight on sample-plan.md in a fresh Claude session
# and diff output against tests/expected/sample-plan-checklist.md.
# This test is MANUAL - cannot be automated without a live AI session.
