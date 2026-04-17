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

# Structured Outcome slot format (Patch E) + findings accounting invariant
grep -q "^## Outcome Slot Format$" "$SKILL" || { echo "FAIL: Outcome Slot Format section"; exit 1; }
grep -q "findings=N critical=N auto_fixed=N deferred=N" "$SKILL" || { echo "FAIL: structured outcome format with deferred="; exit 1; }
grep -qi "admissible.findings = auto_fixed + deferred\|findings == auto_fixed + deferred\|findings = auto_fixed + deferred" "$SKILL" || { echo "FAIL: accounting invariant language"; exit 1; }

# Numbered findings + project-rule severity + deferred-for-all
grep -q "### Finding N\|### Finding 1" "$SKILL" || { echo "FAIL: numbered findings format"; exit 1; }
grep -qi "project.rule severity\|project rules override" "$SKILL" || { echo "FAIL: project-rule severity language"; exit 1; }
grep -qi "style.*ALWAYS deferred\|always deferred\|deferred-write.*ALL style\|MUST be written to.*deferred" "$SKILL" || { echo "FAIL: style-always-deferred rule"; exit 1; }

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
