#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`

for file in .*; do
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    rm -rf "$dest"
    ln -sfv "$source" "$dest"
done

ln -sfvn "$dir/home_bin" "$HOME/bin"
