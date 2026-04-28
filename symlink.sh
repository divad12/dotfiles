#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`


for file in .* bin; do
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    if [ -e "$dest" ]; then
        mv "$dest" "$dest".orig
    fi
    ln -sfvn "$source" "$dest"
done

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
