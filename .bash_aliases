# Override command aliases
alias less='less -I'
alias latex2html='latex2html -no_footnode -auto_prefix -split 0 -info 0 -no_navigation'


alias pdate='ssh pdate@184.106.221.127'
alias dserver='python manage.py runserver 9999'

alias lt='ls -trlh'
alias ll='ls -l'
alias vm='vim `ls --color=none -t | head -n 1`'
alias rs='resize -s 900 900'
alias cproj='cd ~/code/eatsleep/kwizr'
alias cindent='~/cindent.bash'
alias oldHome='cd /media/disk/Users/David/'
alias g='gvim'
alias wr='cd /home/david/Documents/work/work_reports/wt1/'
alias go='gnome-open'
alias agi='sudo apt-get install'
function mr() {
    echo "$1/$(ls --color=no -t $1 | head -n 1)";
}
function wiki() {
    dig +short txt "$*".wp.dg.cx
}

# ------------------------------------------------------------------------------
# directory navigation shortcuts
# ------------------------------------------------------------------------------
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

# from http://daniele.livejournal.com/76011.html
function up()
{
    dir=""
    if [ -z "$1" ]; then
        dir=..
    elif [[ $1 =~ ^[0-9]+$ ]]; then
        x=0
        while [ $x -lt ${1:-1} ]; do
            dir=${dir}../
            x=$(($x+1))
        done
    else
        dir=${PWD%/$1/*}/$1
    fi
    cd "$dir";
}

function upstr()
{
    echo "$(up "$1" && pwd)";
}

# http://mattie.posterous.com/some-handy-bash-commands
# down somesubdir
#
# Find a directory below this that matches the word provided
#   (locate-based)
function down() {
    dir=""
    if [ -z "$1" ]; then
        dir=.
    fi
    dir=$(locate -n 1 -r $PWD.*/$1$)
    cd "$dir";
}

# cdd someglobaldir
#
# quickly change to a directory anywhere that matches the word you typed.
# best if your locatedb is in good shape
function cdd() {
dir=""
if [ -z "$1" ]; then
dir=.
fi
dir=$(locate -n 1 -r $1$)
cd "$dir";
}

# make directory and cd to it
function md() {
    mkdir -p $1 && cd $1
}
