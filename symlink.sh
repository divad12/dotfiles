#!/bin/bash

# Symlinks dotfiles into home directory

dir=`pwd`


for file in .*; do
    # XXX Use list of stuff to not include. Also README.
    if [[ "$file" == ".git" || "$file" == "." || "$file" == ".." ]]; then
        continue
    fi
    source="$dir/$file"
    dest="$HOME/$file"
    mv "$dest" "$dest".orig
    ln -sfv "$source" "$dest"
done

ln -sfvn "$dir/home_bin" "$HOME/bin"
