# Progress

## Last Updated
2026-05-02

## Current State
task-observer fully wired. Adaptive-docs pattern now applies at dotfiles scope: `~/dotfiles/docs/ai/` holds global topic guidance (writing-docs.md), routed from AGENTS.md. Cloud routine extended to PR against either `.agents/skills/<skill>/SKILL.md` OR `docs/ai/<doc>.md` based on observation scope (cross-cutting → docs, skill-specific → skills).

## In Progress
None.

## Up Next
- [ ] Resolve the existing `.claude/skills` to `.agents/skills` symlink migration.

## Recently Done
- [x] [worktree: master] Added `ask-intern-guard` as the active Claude Code PreToolUse routing hook; restored `~/.claude/settings.json` to the dotfiles symlink with unique drift backups.
- [x] [worktree: elated-buck-046da7] task-observer skips subagents — added SUBAGENT-STOP block + frontmatter exception + AGENTS.md note. Subagents previously burned ~50 tokens per invocation despite having no user-feedback signal to capture.
- [x] [worktree: elated-buck-046da7] Bootstrapped global `~/dotfiles/docs/ai/` with `writing-docs.md` (universal portion lifted from journology); added routing table to AGENTS.md; updated cloud routine prompt to support docs/ai/ as PR target.
- [x] [worktree: elated-buck-046da7] Hardened task-observer auto-invocation: MANDATORY language in AGENTS.md + SKILL.md description, SessionStart hook in settings.json injects mandatory pre-flight reminder.
- [x] [worktree: elated-buck-046da7] Version-controlled `.claude/settings.json` via dotfiles symlink; symlink.sh extended to handle per-file `.claude/*` mirroring on fresh install.
- [x] [worktree: master] Tightened global `.claude/AGENTS.md` wording and restored imperative shortcut/FIXME/TDD guardrails.
- [x] [worktree: elated-buck-046da7] Installed task-observer ("One Skill to Rule Them All") with centralized observations repo, launchd auto-push (plist version-controlled in dotfiles via `Library/LaunchAgents/`), and M/W/F cloud review routine.
- [x] [worktree: master] Made `/deep-review` Codex/Claude-Code aware for independent review dispatch.

## Blockers
None.
