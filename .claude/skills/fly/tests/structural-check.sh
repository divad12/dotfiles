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

grep -q "^## Rationalization Table$" "$SKILL" || { echo "FAIL: Rationalization Table section"; exit 1; }
grep -q "^## Red Flags - STOP$" "$SKILL" || { echo "FAIL: Red Flags section"; exit 1; }
grep -q "^## The Iron Rule$" "$SKILL" || { echo "FAIL: The Iron Rule section"; exit 1; }
grep -qi "checklist is the contract" "$SKILL" || { echo "FAIL: commitment contract language"; exit 1; }

# Reviewer Independence Override (Patch A) + finding tag taxonomy (Patch B)
grep -q "^## Reviewer Independence Override$" "$SKILL" || { echo "FAIL: Reviewer Independence Override section"; exit 1; }
grep -qi "implementer.s summary.*untrusted" "$SKILL" || { echo "FAIL: independence language"; exit 1; }
grep -q "Actual Diff" "$SKILL" || { echo "FAIL: Actual Diff heading in override"; exit 1; }
grep -q "\[critical\]" "$SKILL" || { echo "FAIL: critical finding tag"; exit 1; }
grep -q "\[correctness\]" "$SKILL" || { echo "FAIL: correctness finding tag"; exit 1; }
grep -q "\[cosmetic\]" "$SKILL" || { echo "FAIL: cosmetic finding tag"; exit 1; }
grep -qi "inadmissible" "$SKILL" || { echo "FAIL: inadmissibility rule"; exit 1; }

# Phase regression check (Patch D)
grep -q "^### Phase regression check" "$SKILL" || { echo "FAIL: Phase regression check subsection"; exit 1; }

# Structured Outcome slot format + findings accounting invariant
grep -q "^## Outcome Slot Format$" "$SKILL" || { echo "FAIL: Outcome Slot Format section"; exit 1; }
grep -q "findings=N fixed=N deferred=N" "$SKILL" || { echo "FAIL: structured outcome format (fixed/deferred tokens)"; exit 1; }
grep -qi "findings == fixed + deferred\|findings = fixed + deferred" "$SKILL" || { echo "FAIL: accounting invariant language"; exit 1; }

# Numbered findings + disposition model + project-rule severity
grep -q "### Finding N\|### Finding 1" "$SKILL" || { echo "FAIL: numbered findings format"; exit 1; }
grep -qi "disposition.*\[fix\]\|disposition.*fix.*defer\|\[fix\].*\[defer\]" "$SKILL" || { echo "FAIL: disposition field"; exit 1; }
grep -qi "default.*\[fix\]\|fix by default\|default disposition.*fix" "$SKILL" || { echo "FAIL: fix-by-default rule"; exit 1; }
grep -qi "project.rule\|project/user rules override\|abide by the rules" "$SKILL" || { echo "FAIL: project-rule language"; exit 1; }

# Review artifact files (write-witness for reviews)
grep -q "^## Review Artifact Files$" "$SKILL" || { echo "FAIL: Review Artifact Files section"; exit 1; }
grep -qi "write.*review.*to.*file\|Your final tool call MUST be a Write\|reviewer.*writes.*file" "$SKILL" || { echo "FAIL: reviewer-writes-file mandate"; exit 1; }
grep -q "review: <path>\|review: <path\|reviews/task-\|reviews/phase-" "$SKILL" || { echo "FAIL: review path convention"; exit 1; }

# Suspicious-pattern halt heuristics
grep -qi "3 consecutive\|three.*consecutive\|3 reviews in a row\|Suspicious-pattern" "$SKILL" || { echo "FAIL: halt heuristic for consecutive zero findings"; exit 1; }

# Combined review shortcut for deep-review-gated phases
grep -qi "Combined review shortcut\|combined spec+code reviewer\|combined review" "$SKILL" || { echo "FAIL: combined review shortcut"; exit 1; }

# Normalization pass for deep-reviews
grep -qi "normalization pass\|normalized.md\|normalize" "$SKILL" || { echo "FAIL: normalization pass language"; exit 1; }

# Enumerate every raw finding
grep -qi "EVERY raw finding\|every distinct observation\|do NOT output a .consolidated" "$SKILL" || { echo "FAIL: enumerate-every-finding language"; exit 1; }

# Deep-review subagent dispatch invoking Skill tool
grep -qi "invoke.*deep-review.*skill.*via.*Skill tool\|invoke the .deep-review. skill via" "$SKILL" || { echo "FAIL: deep-review Skill tool invocation"; exit 1; }

echo "OK: fly structural check passed"

# Integration test: dry-run /fly on sample checklist.
# MANUAL - requires live Claude Code session with plugin installed.
# Procedure:
#   1. Fresh Claude session: /fly .claude/skills/fly/tests/samples/sample-checklist.md
#   2. Interrupt after "Mode: fresh run" announcement; verify template resolution logs.
#   3. Edit sample-checklist.md to tick first step + fill Task 1 SHA.
#   4. Re-run /fly; verify "Mode: resuming from Task 1".
#   5. git checkout to restore fixture.
