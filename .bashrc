# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# TODO: Clean up all this mess. Place into different sections, and merge in .bash_aliases

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# don't overwrite GNU Midnight Commander's setting of `ignorespace'.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
# ... or force ignoredups and ignorespace
export HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend


# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
# Erase duplicates in history
export HISTCONTROL=erasedups
# Store 10k history entries
export HISTSIZE=10000
# Append to the history file when exiting instead of overwriting it
shopt -s histappend



# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    eval "`dircolors -b`"
    alias ls='ls --color -F'

    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
else
    alias ls='ls -F'
fi

#export GREP_COLOR='1;32'
alias grep='grep --color=always -n' # Alias instead of env var so as not to break scripts that may use grep

# Less syntax higlighting - from http://linux-tips.org/article/78/syntax-highlighting-in-less
export LESSOPEN="| /usr/local/bin/src-hilite-lesspipe.sh %s"
export LESS=' -RF'

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
#alias l='ls -CF'
export LS_COLORS='ow=34'

# For Mac (BSD ls)
export CLICOLOR=1
#export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx  # Cyan instead of blue for ls

export EDITOR=vim

# Use vi modal editing for readline
# see http://www.catonmat.net/blog/bash-vi-editing-mode-cheat-sheet/
set -o vi

# export WORKON_HOME=/home/david/.virtualenvs
# source /usr/local/bin/virtualenvwrapper_bashrc

source /etc/profile

export CDPATH='$HOME/cdpath'

#export PATH="$PATH:/usr/share/pk2:/home/david/.virtualenvs/pinax-env/lib/python2.6/site-packages/django/bin/:$HOME/bin:/home/david/qtsdk-2010.05/qt/bin:/home/david/.cabal/bin"
export PATH="$PATH:$HOME/bin:/usr/local/sbin:$HOME/.gem/ruby/1.8/bin:/usr/local/Cellar/ruby/1.9.2-p180/bin"

shopt -s histappend


# Prompt colouring
#export PS1="${debian_chroot:+($debian_chroot)}\u@\h:\w\$ "
#export PS1="$\w\$ "
#export PS1="\[\e[1;31m[\w \@]\$ \e[m\]"
#export PS1="[\[\e[0;34m\]\t \[\e[31;1m\]\w]\$ \[\e[0m\]"
#export PS1="\[\e[33;1m\] [ \w ]\$ \[\e[0m\]"

# from http://www.ibm.com/developerworks/linux/library/l-tip-prompt/
#export PS1="\[\e]2;\u@\H \w\a\e[32;1m\]>\[\e[0m\] "

case $TERM in
xterm*)
    # Set the prompt to a basic coloured current working directory
    export PS1="\[\e[33;1m\] [ \w ]\$ \[\e[0m\]"
    PROMPT_COMMAND=''
    ;;
screen*)
    # Set the screen window name to the basename of the working directory
    PROMPT_COMMAND='bpwd=$(basename `pwd`); echo -ne "\033]0;\007\033k$bpwd\033\\"'
    # Set the hardstatus to the working directory, which will display on GNU
    # screen's caption as well as xterm's title bar. Now our prompt can be a short
    # and sweet $.
    export PS1="\[\e]2;\w\a\e[32;40m\]\t \[\e[32;1m\][ \W ]\[\e[0m\] "
    ;;
*)
    ;;
esac

export PAGER=less

# Less pager colouring (useful for man)
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;37m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


# autojump: https://github.com/joelthelion/autojump/wiki/
_autojump()
{
        local cur
        cur=${COMP_WORDS[*]:1}
        while read i
        do
            COMPREPLY=("${COMPREPLY[@]}" "${i}")
        done  < <(autojump --bash --completion $cur)
}
complete -F _autojump j
data_dir=$([ -e ~/.local/share ] && echo ~/.local/share || echo ~)
export AUTOJUMP_HOME=${HOME}
if [[ "$data_dir" = "${HOME}" ]]
then
    export AUTOJUMP_DATA_DIR=${data_dir}
else
    export AUTOJUMP_DATA_DIR=${data_dir}/autojump
fi
if [ ! -e "${AUTOJUMP_DATA_DIR}" ]
then
    mkdir "${AUTOJUMP_DATA_DIR}"
    mv ~/.autojump_py "${AUTOJUMP_DATA_DIR}/autojump_py" 2>>/dev/null #migration
    mv ~/.autojump_py.bak "${AUTOJUMP_DATA_DIR}/autojump_py.bak" 2>>/dev/null
    mv ~/.autojump_errors "${AUTOJUMP_DATA_DIR}/autojump_errors" 2>>/dev/null
fi

AUTOJUMP='{ [[ "$AUTOJUMP_HOME" == "$HOME" ]] && (autojump -a "$(pwd -P)"&)>/dev/null 2>>${AUTOJUMP_DATA_DIR}/autojump_errors;} 2>/dev/null'
if [[ ! $PROMPT_COMMAND =~ autojump ]]; then
  export PROMPT_COMMAND="${PROMPT_COMMAND:-:} ; $AUTOJUMP"
fi
alias jumpstat="autojump --stat"
function j { new_path="$(autojump $@)";if [ -n "$new_path" ]; then echo -e "\\033[31m${new_path}\\033[0m"; cd "$new_path";else false; fi }


# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

if [ -f `brew --prefix`/etc/bash_completion ]; then
  . `brew --prefix`/etc/bash_completion
fi

if [ -f `brew --prefix`/etc/bash_completion.d/hg-completion ]; then
  . `brew --prefix`/etc/bash_completion.d/hg-completion
fi
