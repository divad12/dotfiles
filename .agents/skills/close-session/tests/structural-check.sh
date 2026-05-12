#!/bin/bash
set -euo pipefail

SKILL="${SKILL:-.agents/skills/close-session/SKILL.md}"

test -f "$SKILL" || { echo "FAIL: close-session skill missing"; exit 1; }
grep -q "^name: close-session$" "$SKILL" || { echo "FAIL: frontmatter name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: user-invocable"; exit 1; }
grep -q "Do not write session files" "$SKILL" || { echo "FAIL: session-file opt-out"; exit 1; }
grep -q "Do not manage port files" "$SKILL" || { echo "FAIL: port-file opt-out"; exit 1; }
grep -q "Only remove the git worktree and branch" "$SKILL" || { echo "FAIL: narrow teardown scope"; exit 1; }
grep -q "git worktree remove" "$SKILL" || { echo "FAIL: worktree removal"; exit 1; }
grep -q "git branch -d" "$SKILL" || { echo "FAIL: safe branch deletion"; exit 1; }

! grep -q "Always write the session file" "$SKILL" || { echo "FAIL: session file still mandatory"; exit 1; }
! grep -q "\.claude/sessions" "$SKILL" || { echo "FAIL: session directory still referenced"; exit 1; }
! grep -q "port lock" "$SKILL" || { echo "FAIL: obsolete port-lock wording remains"; exit 1; }
! grep -q "\.claude/ports" "$SKILL" || { echo "FAIL: port directory still referenced"; exit 1; }
! grep -q "\.playwright-mcp" "$SKILL" || { echo "FAIL: runtime artifact cleanup still referenced"; exit 1; }
! grep -q "lsof -ti" "$SKILL" || { echo "FAIL: dev-server port kill still referenced"; exit 1; }
! grep -q "find .* -delete" "$SKILL" || { echo "FAIL: ad hoc file deletion still referenced"; exit 1; }

echo "ok"
