This directory is the repo-local entrypoint for agent-agnostic assets.

Current setup:
- `.agents/skills` is the shared skill directory.
- `.claude/skills` symlinks to `.agents/skills`.
- `~/.agents/AGENTS.md` and `~/.codex/AGENTS.md` symlink to `.claude/AGENTS.md`.

Why this shape:
- `.claude/AGENTS.md` remains the source of truth for always-loaded global instructions.
- `.agents` holds cross-agent assets without mixing in Claude-specific config such as `commands`, `settings.json`, or `CLAUDE.md`.
- `~/.agents` and `~/.codex` remain real runtime directories; `symlink.sh` mirrors only shared config files into them.

Compatibility note:
- Some skills under `skills/` may still reference Claude-specific concepts or tools.
- Shared discovery works, but true portability may require adapting those skills over time.
