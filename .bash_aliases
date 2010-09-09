# Temporary
alias bot='cd /home/david/code/galcon/latest'

# Override command aliases
alias less='less -I'

# alias for listing more recent files first
alias lt='ls -trlh'
alias ll='ls -l'
alias vm='vim `ls --color=none -t | head -n 1`'
alias rs='resize -s 900 900'
alias cs='cd ~/Documents/school/cs138'
alias cproj='cd ~/code/eatsleep/kwizr'
alias cindent='~/cindent.bash'
alias oldHome='cd /media/disk/Users/David/'
alias g='gvim'
alias dl='cd ~/Downloads'
alias wr='cd /home/david/Documents/work/work_reports/wt1/'
alias go='gnome-open'

# directory navigation shortcuts
pushd()
{
    builtin pushd "$@" > /dev/null
}
alias cd='pushd '
alias pu='pushd'
alias po='popd'
alias cd-='popd'
alias cd--='popd -2'
alias cd---='popd -3'
alias d='dirs -v'
alias b='pushd +1'
