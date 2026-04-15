---
name: superpowers
description: Repo-local compatibility entrypoint for shared agent skills. Use when the user asks for "superpowers", wants to use one of the shared Claude/Codex skills in this repository, or wants agent capabilities exposed through `.agents/skills`.
---

# Superpowers

This skill is the compatibility entrypoint for repo-local shared skills.

## What it means

- The shared skill pool for this repository lives at `.agents/skills/`.
- In this repo, `.agents/skills` is a symlink to `.claude/skills`, so existing Claude-authored skills are visible through the agent-neutral path.
- When the user asks for "superpowers", interpret that as permission to inspect and use relevant skills from `.agents/skills/`.

## How to use it

1. List candidate skills under `.agents/skills/`.
2. Match the user request to the most relevant skill directory.
3. Open that skill's `SKILL.md` and follow it if the instructions are compatible with the current agent and toolset.
4. If a skill is Claude-specific, adapt the workflow rather than failing silently.

## Compatibility rules

- Prefer the `.agents/skills/...` path when referring to repo-local shared skills.
- Treat `.claude/skills/...` as the backing store for now, not the public interface.
- Claude-specific command names such as `/build` or `/save` are intent labels, not literal commands.
- Claude-only concepts such as `AskUserQuestion` should be mapped to the nearest equivalent behavior available in the current agent.
- If a skill depends on tools that do not exist in the current agent, state that briefly and continue with the closest supported workflow.

## Scope

This skill does not provide one workflow itself. It authorizes and explains access to the shared skill library in this repository.
