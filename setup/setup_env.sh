#!/bin/sh

# TODO: Actually write this script
# TODO: script to rsync (in case machine doesn't have git): https://github.com/rtomayko/dotfiles/blob/rtomayko/bin/sync-home

# To install (absolute must):
# - run :BundleInstall in vim to install plugins
# - build native c object files for command-t (:h CommandT)
# - screen
# - ack-grep
# - autojump (write a script to install this)
# - google command line
# - htop
# - keyboard shortcut to launch terminal window, maximized. start with screen.
# - flux or Redshift for Linux: gtk-redshift -t 5700:3700
# - Google Chrome w/ extensions: facebook photo zoom, google quick scroll,
#     hover zoom (!!MUST), tweetdeck, pinned tabs (gmail, calendar, fb, reader,
#     twitter, github, phone to chrome), vimium. Use Chrome sync.
# - Ubuntu panels: cpu, memory, etc. and weather (set current location for time)
# - make terminal and gvim windows semi-transparent
# - copy ssh keys and run ssh-agent
# - LaTeX
# - office
# - source-highlight (for less syntax highlighting)
# - solarized colorscheme for terminals
# - vimpager

# Ubuntu specific
# - compiz with Grid (tiling by numpad)
#   - sudo apt-get install compiz-fusion-plugins-extra

# Mac OS X specific
# defaults -currentHost write -globalDomain AppleFontSmoothing -int 1
# KeyRemap4Macbook - capslock LED hack for no delay
# PCKeyboardHack - capslock --> ESC
# BetterTouchTool - gestures
# SizeUp - tiling (like Compiz's Grid)
# homebrew - package manager
# edit /etc/paths and /etc/manpaths to put /usr/local/ first, so brew-installed apps take precedence
# - iterm2
# increase key delay rate: http://hints.macworld.com/article.php?story=20090823193018149
# reduce text smoothing
# Animated Gif QuickLook plugin - http://www.quicklookplugins.com/
# brew install bash-completion
# osxfuse and Macfusion for ssh drive mounting


# Hardware setup
# - printer and scanner drivers

# ssh -f -L 3000:pandora.com:80 david-hu.com -N -l dhu # then browse to localhost:3000

# nginx: http://library.linode.com/web-servers/nginx/configuration/basic

# pandora outside of US: http://proxydns.co/
# Get font Bitstream Vera Sans Mono, then patch Powerline
