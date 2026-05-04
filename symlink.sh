#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`


link_path() {
    source="$1"
    dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        backup="$dest.orig"
        if [ -e "$backup" ]; then
            i=1
            while [ -e "$backup.$i" ]; do
                i=$((i + 1))
            done
            backup="$backup.$i"
        fi
        echo "Backing up real $dest to $backup before restoring dotfiles symlink" >&2
        mv "$dest" "$backup"
    fi
    ln -sfvn "$source" "$dest"
}

for file in .* bin; do
    # Agent state dirs are owned by their apps (sessions, plugins, projects,
    # observations). Keep them real and mirror only shared config below.
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." || "$file" == ".claude" || "$file" == ".agents" || "$file" == ".codex" ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    link_path "$source" "$dest"
done

# .claude/ - per-file symlinks into ~/.claude/. Claude Code owns ~/.claude
# (sessions, plugins, projects) so we only mirror specific config files.
# AGENTS.md, CLAUDE.md, settings.json all live in dotfiles; everything else
# is runtime state that stays local.
if [ -d "$dir/.claude" ]; then
    mkdir -p "$HOME/.claude"
    for f in "$dir"/.claude/*; do
        [ -e "$f" ] || continue
        # Skip directories - we only want top-level config files here.
        [ -f "$f" ] || continue
        dest="$HOME/.claude/$(basename "$f")"
        link_path "$f" "$dest"
    done
fi

# .agents/ - shared agent assets plus local runtime state. Observations and
# backups stay in ~/.agents; only global instructions and skills are mirrored.
if [ -d "$dir/.agents" ]; then
    mkdir -p "$HOME/.agents"
    link_path "$dir/.claude/AGENTS.md" "$HOME/.agents/AGENTS.md"
    link_path "$dir/.agents/skills" "$HOME/.agents/skills"
fi

# .codex/ - Codex owns this directory. Mirror the shared global instructions
# so Codex loads the same token-delegation and adaptive-docs contracts.
mkdir -p "$HOME/.codex"
link_path "$dir/.claude/AGENTS.md" "$HOME/.codex/AGENTS.md"

# macOS LaunchAgents - symlink each plist individually since ~/Library
# is a system dir we can't replace wholesale. After symlinking, (re)load
# each job so `./symlink.sh` is the single entry point for install AND
# activation. unload-then-load makes it idempotent across re-runs.
if [ -d "$dir/Library/LaunchAgents" ]; then
    mkdir -p "$HOME/Library/LaunchAgents"
    for plist in "$dir"/Library/LaunchAgents/*.plist; do
        [ -e "$plist" ] || continue
        dest="$HOME/Library/LaunchAgents/$(basename "$plist")"
        link_path "$plist" "$dest"
        if command -v launchctl >/dev/null 2>&1; then
            launchctl unload "$dest" 2>/dev/null || true
            launchctl load "$dest"
        fi
    done
fi
