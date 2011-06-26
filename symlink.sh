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
