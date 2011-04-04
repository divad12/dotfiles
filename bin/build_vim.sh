#!/bin/sh

# Building vim on Ubuntu

# From http://askubuntu.com/questions/7283/where-can-i-find-vim-7-3
# and http://vim.wikia.com/wiki/Building_Vim

sudo apt-get build-dep vim-gnome
sudo apt-get install libssl-dev
sudo apt-get install hg
sudo apt-get install libncurses5-dev libgnome2-dev libgnomeui-dev \
libgtk2.0-dev libatk1.0-dev libbonoboui2-dev \
libcairo2-dev libx11-dev libxpm-dev libxt-dev
mkdir -p ~/src
hg clone https://vim.googlecode.com/hg/ ~/src/vim
cd ~/src/vim
./configure --enable-multibyte --enable-pythoninterp --enable-rubyinterp --enable-cscope --enable-xim --with-features=huge --enable-gui=gnome2
sudo make # dunno why just "make" doesn't work
sudo make install
