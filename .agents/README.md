This directory is the repo-local entrypoint for agent-agnostic assets.

Current setup:
- `skills` is a symlink to `../.claude/skills`

Why this shape:
- `.claude` remains the source of truth for existing skills.
- `.agents` stays available for cross-agent files that should not be mixed with Claude-specific config such as `commands`, `settings.json`, or `CLAUDE.md`.

Compatibility note:
- Some skills under `skills/` may still reference Claude-specific concepts or tools.
- Shared discovery works, but true portability may require adapting those skills over time.
