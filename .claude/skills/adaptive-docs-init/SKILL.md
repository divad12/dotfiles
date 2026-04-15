---
name: adaptive-docs-init
description: "Bootstrap the adaptive documentation system in a project: create docs/ai/, .agents/skills/, the .claude/skills symlink, root AGENTS.md, writing-docs.md, and a slim CLAUDE.md template. Use when the user says 'set up adaptive docs', 'set up the doc system', 'init docs', 'add agent docs to this project', or wants to apply the three-layer docs architecture to a new project."
user-invocable: true
---

# Adaptive Docs - Init

Set up the adaptive documentation system in a project. This is the **mechanical bootstrap** - it creates the structure but doesn't try to refactor existing CLAUDE.md sprawl. Use `/adaptive-docs-extract` for that after.

The architecture being installed:

```
<project>/
├── CLAUDE.md                 # always loaded by Claude Code (slim, intent-based table)
├── AGENTS.md                 # always loaded by Codex; Claude Code fallback
├── docs/ai/                  # on-demand reference docs (the source of truth)
│   ├── README.md
│   └── writing-docs.md       # meta-rules for editing these
├── .agents/skills/           # auto-activated skills (shared between agents)
└── .claude/skills            # symlink → ../.agents/skills
```

See `~/.claude/templates/adaptive-docs/` for the templates this skill uses.

## Steps

### 1. Verify environment

Confirm we're in a git repository and at the project root:

```bash
git rev-parse --show-toplevel
```

If not in a git repo, ask the user whether to proceed anyway or `git init` first.

Detect project name from `package.json`, `pyproject.toml`, `Cargo.toml`, or the directory name as fallback.

### 2. Detect what already exists

Check for each piece of the system:

```bash
test -f CLAUDE.md            && echo "HAS_CLAUDE_MD"
test -f AGENTS.md            && echo "HAS_AGENTS_MD"
test -d docs/ai              && echo "HAS_DOCS_AI"
test -d .agents/skills       && echo "HAS_AGENTS_SKILLS"
test -L .claude/skills       && echo "HAS_SKILLS_SYMLINK"
test -f docs/ai/writing-docs.md && echo "HAS_WRITING_DOCS"
```

For each missing piece, plan to create it. For each existing piece, **do not overwrite** - instead report and skip. The user can run `/adaptive-docs-extract` to refactor existing files.

### 3. Create directory structure

```bash
mkdir -p docs/ai
mkdir -p .agents/skills
mkdir -p .claude
```

### 4. Create the symlink

`.claude/skills` is a relative symlink to `../.agents/skills` so both paths resolve to the same directory:

```bash
[ -L .claude/skills ] || ln -s ../.agents/skills .claude/skills
```

If `.claude/skills` exists as a real directory (not a symlink), stop and ask the user how to proceed - they may have skills they don't want to lose.

### 5. Update .gitignore

The `.claude/` directory is often gitignored (it has worktrees, ports, settings). But `.claude/skills` (the symlink) and `.claude/settings.json` should usually be tracked.

Read `.gitignore`. If it has a bare `.claude/` or `.claude` rule, replace with:

```
.claude/*
!.claude/skills
!.claude/settings.json
```

If `.gitignore` doesn't mention `.claude/` at all, add the same block. If it already has the exception form, leave it alone.

### 6. Create docs/ai/writing-docs.md

Copy `~/.claude/templates/adaptive-docs/writing-docs.md.template` to `docs/ai/writing-docs.md`. Replace template placeholders with empty strings (the file inventory will be filled in as docs are added):

- `{{FILE_TABLE_ROWS}}` → empty (just the header row remains)
- `{{SKILL_TABLE_ROWS}}` → empty
- `{{NESTED_AGENTS_ROWS}}` → empty

### 7. Create docs/ai/README.md

Copy `~/.claude/templates/adaptive-docs/README.md.template` to `docs/ai/README.md`. Replace `{{FILE_TABLE_ROWS}}` with empty (the table will list new docs as they're added).

### 8. Create root AGENTS.md (if missing)

Copy `~/.claude/templates/adaptive-docs/AGENTS.md.template` to `AGENTS.md` at the project root.

Replace placeholders:
- `{{PROJECT_NAME}}` → detected project name
- `{{TECH_STACK_DESCRIPTION}}` → empty (or one line if obvious from package.json)
- `{{REFERENCE_TABLE_ROWS}}` → empty (to be filled in as docs are added)

If `AGENTS.md` already exists, **do not overwrite**. Report it and tell the user that `/adaptive-docs-extract` can help align it with the structure.

### 9. Create root CLAUDE.md (only if missing)

If `CLAUDE.md` does not exist, copy `~/.claude/templates/adaptive-docs/CLAUDE.md.template` to `CLAUDE.md`. Replace placeholders the same way as AGENTS.md.

If `CLAUDE.md` already exists, **do not overwrite**. Report that the next step is to run `/adaptive-docs-extract` to refactor it into the three-layer system.

### 10. Report what was done

Print a summary like:

```
Adaptive docs initialized.

Created:
  ✓ docs/ai/README.md
  ✓ docs/ai/writing-docs.md
  ✓ AGENTS.md
  ✓ .agents/skills/ (empty)
  ✓ .claude/skills → ../.agents/skills (symlink)
  ✓ .gitignore updated to track .claude/skills

Skipped (already existed):
  - CLAUDE.md  (run /adaptive-docs-extract to refactor it)

Next steps:
  - If your existing CLAUDE.md is more than ~100 lines, run /adaptive-docs-extract
    to split it into docs/ai/ files with skill triggers.
  - Otherwise, start adding topic docs as you encounter them. The /capture-learning
    skill knows how to route new principles into the right docs/ai/ file.
  - Read docs/ai/writing-docs.md to understand the maintenance rules.
```

## Notes

- **This skill is idempotent.** Running it twice should not break anything - it skips files that already exist.
- **Templates are at `~/.claude/templates/adaptive-docs/`.** If the templates are missing (e.g. user doesn't have these dotfiles), bail with a clear message instead of inventing content.
- **Do not invent content for placeholders.** If you don't have a real value (e.g. tech stack), leave a clear comment like `<!-- TODO: fill in tech stack -->` so the user knows to come back.
- **Don't run /adaptive-docs-extract automatically.** It's interactive and the user may want to do it later.
