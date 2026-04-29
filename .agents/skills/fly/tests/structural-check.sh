#!/bin/bash
# Structural regression test for /fly skill.
# Checks the SKILL.md body still has the load-bearing execution sections
# and that all bundled reference files exist.
set -e
SKILL_DIR=.agents/skills/fly
SKILL=$SKILL_DIR/SKILL.md

test -f "$SKILL" || { echo "FAIL: $SKILL missing"; exit 1; }

# Frontmatter + heading
grep -q "^name: fly$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "^# Fly$" "$SKILL" || { echo "FAIL: H1 heading"; exit 1; }

# Top-level sections that must stay in the body
grep -q "^## Purpose$" "$SKILL" || { echo "FAIL: Purpose section"; exit 1; }
grep -q "^## Helper Scripts$" "$SKILL" || { echo "FAIL: Helper Scripts section"; exit 1; }
grep -q "^## Bundled References$" "$SKILL" || { echo "FAIL: Bundled References section"; exit 1; }
grep -q "^## Triggers$" "$SKILL" || { echo "FAIL: Triggers section"; exit 1; }
grep -q "^## Input$" "$SKILL" || { echo "FAIL: Input section"; exit 1; }
grep -q "^## State Detection$" "$SKILL" || { echo "FAIL: State Detection section"; exit 1; }
grep -q "^## Template Resolution$" "$SKILL" || { echo "FAIL: Template Resolution section"; exit 1; }
grep -q "^## Per-Task Loop$" "$SKILL" || { echo "FAIL: Per-Task Loop section"; exit 1; }
grep -q "^## Reviewer Independence Override$" "$SKILL" || { echo "FAIL: Reviewer Independence Override section"; exit 1; }
grep -q "^## Per-Task Integrity Gate$" "$SKILL" || { echo "FAIL: Per-Task Integrity Gate section"; exit 1; }
grep -q "^## Phase Regression Check$" "$SKILL" || { echo "FAIL: Phase Regression Check section"; exit 1; }
grep -q "^## Session Gate" "$SKILL" || { echo "FAIL: Session Gate section"; exit 1; }
grep -q "^## Deferred File Handling$" "$SKILL" || { echo "FAIL: Deferred File Handling section"; exit 1; }
grep -q "^## Final Verification$" "$SKILL" || { echo "FAIL: Final Verification section"; exit 1; }
grep -q "^## Completion$" "$SKILL" || { echo "FAIL: Completion section"; exit 1; }
grep -q "^## Discipline: shortcuts to NEVER take$" "$SKILL" || { echo "FAIL: Discipline section"; exit 1; }

# Load-bearing technical assertions (the contract language)
grep -q "claude-plugins-official/superpowers/\*/skills/subagent-driven-development" "$SKILL" || { echo "FAIL: Glob pattern missing"; exit 1; }
grep -qi "checklist is the contract\|checklist IS the contract" "$SKILL" || { echo "FAIL: commitment contract language"; exit 1; }
grep -qi "implementer.s summary.*untrusted\|Implementer-Reported Summary.*untrusted" "$SKILL" || { echo "FAIL: independence language"; exit 1; }
grep -q "Actual Diff" "$SKILL" || { echo "FAIL: Actual Diff heading in override"; exit 1; }
grep -qi "inadmissible" "$SKILL" || { echo "FAIL: inadmissibility rule"; exit 1; }
grep -qi "findings == fixed + deferred\|findings = fixed + deferred" "$SKILL" || { echo "FAIL: accounting invariant language"; exit 1; }
grep -qi "disposition\|\[fix\].*\[defer\]" "$SKILL" || { echo "FAIL: disposition field"; exit 1; }
grep -qi "default disposition is .\[fix\]\|default = .\[fix\]\|Default disposition" "$SKILL" || { echo "FAIL: fix-by-default rule"; exit 1; }
grep -q "review: <path>\|reviews/task-\|reviews/phase-" "$SKILL" || { echo "FAIL: review path convention"; exit 1; }

# fly Completion must NOT independently re-list deferred §N items - the
# synthetic deferred-resolution task is the canonical user-facing surface.
grep -qi "do NOT independently list deferred items\|single canonical surface" "$SKILL" || { echo "FAIL: Completion section must forbid raw deferred listing"; exit 1; }

# Bundled reference files must exist on disk and be cited from SKILL.md
for ref in \
    references/review-artifacts.md \
    references/outcome-format.md \
    references/integrity-gate.md \
    references/final-verify-output.md ; do
  test -f "$SKILL_DIR/$ref" || { echo "FAIL: missing reference file $ref"; exit 1; }
  grep -qF "$ref" "$SKILL" || { echo "FAIL: SKILL.md does not cite $ref"; exit 1; }
done

# Helper scripts present
for script in dispatch-reviewer.sh integrity-check.sh final-verify.sh phase-regression.sh tick-steps.sh ; do
  test -f "$SKILL_DIR/$script" || { echo "FAIL: missing helper script $script"; exit 1; }
done
test -f "$SKILL_DIR/reviewer-override.md" || { echo "FAIL: missing reviewer-override.md"; exit 1; }

# Outcome format reference must spell out the structured token shape
OUTCOME_REF="$SKILL_DIR/references/outcome-format.md"
grep -q "findings=N fixed=N deferred=N" "$OUTCOME_REF" || { echo "FAIL: outcome-format.md missing structured token shape"; exit 1; }

# Review artifacts reference must spell out the normalization pass
REVIEW_REF="$SKILL_DIR/references/review-artifacts.md"
grep -qi "normalization pass\|normalized.md" "$REVIEW_REF" || { echo "FAIL: review-artifacts.md missing normalization pass"; exit 1; }

echo "OK: fly structural check passed"

# Integration test: dry-run /fly on sample checklist. MANUAL - requires
# live Claude Code session with plugin installed.
