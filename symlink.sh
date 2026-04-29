#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`


for file in .* bin; do
    # ~/.claude is a real dir managed by Claude Code (sessions, plugins,
    # projects). Wholesale-symlinking it to dotfiles would either nuke that
    # data or pollute the dotfiles repo with Claude's runtime state. So we
    # skip it here and handle individual files in the .claude/ section below.
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." || "$file" == ".claude" ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    if [ -e "$dest" ]; then
        mv "$dest" "$dest".orig
    fi
    ln -sfvn "$source" "$dest"
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
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mv "$dest" "$dest".orig
        fi
        ln -sfvn "$f" "$dest"
    done
fi

# macOS LaunchAgents - symlink each plist individually since ~/Library
# is a system dir we can't replace wholesale. After symlinking, (re)load
# each job so `./symlink.sh` is the single entry point for install AND
# activation. unload-then-load makes it idempotent across re-runs.
if [ -d "$dir/Library/LaunchAgents" ]; then
    mkdir -p "$HOME/Library/LaunchAgents"
    for plist in "$dir"/Library/LaunchAgents/*.plist; do
        [ -e "$plist" ] || continue
        dest="$HOME/Library/LaunchAgents/$(basename "$plist")"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mv "$dest" "$dest".orig
        fi
        ln -sfvn "$plist" "$dest"
        if command -v launchctl >/dev/null 2>&1; then
            launchctl unload "$dest" 2>/dev/null || true
            launchctl load "$dest"
        fi
    done
fi
