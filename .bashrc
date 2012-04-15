# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# TODO: Clean up all this mess. Place into different sections, and merge in .bash_aliases

source /etc/profile

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Erase duplicates in history
export HISTCONTROL=erasedups
# Store lots of history entries
export HISTSIZE=20000
# Append to the history file when exiting instead of overwriting it
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

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

export CDPATH='$HOME/cdpath'
export PATH="$PATH:$HOME/bin:/usr/local/sbin:$HOME/.gem/ruby/1.8/bin:/usr/local/Cellar/ruby/1.9.2-p180/bin"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node"

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
    PROMPT_COMMAND='bpwd=$(basename `pwd`); hname=$(hostname | head -c 3); echo -ne "\033]0;\007\033k${bpwd}@${hname}\033\\"'
    # Set the hardstatus to the working directory, which will display on GNU
    # screen's caption as well as xterm's title bar. Now our prompt does not
    # need to show the full directory path.
    export PS1="\[\e]2;\w\a\e[36;40m\]\t \[\e[32;1m\][ \W ] \[\e[0;33m\](╯°□°)╯ ︵ ┻━┻ \[\e[0m\] "
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

# "Feature detection" of OS X homebrew
if command -v brew > /dev/null; then

    brew_prefix=`brew --prefix`

    # GNU Coreutils >= 7.5 has option sort -h: sort by human-readable size
    if [ -f "$brew_prefix"/bin/gsort ]; then
        alias sort=`brew --prefix`/bin/gsort
    fi

    if [ -f "$brew_prefix"/etc/bash_completion ]; then
      . "$brew_prefix"/etc/bash_completion
    fi

    if [ -f "$brew_prefix"/etc/bash_completion.d/hg-completion ]; then
      . "$brew_prefix"/etc/bash_completion.d/hg-completion
    fi

fi
