#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`

for file in .*; do
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest"
    fi
    ln -sfv "$source" "$dest"
done

ln -sfv "$dir/home_bin" $HOME/bin
