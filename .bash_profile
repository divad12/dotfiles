if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).

# This is here instead of in .bashrc because it takes a few seconds to source
# all the completion scripts
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

if [ -f `brew --prefix`/etc/bash_completion ]; then
  . `brew --prefix`/etc/bash_completion
fi
