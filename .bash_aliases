# TODO: clean up this mess; organize into sections

uname=$(uname)

# Override command aliases
alias less='less -I'
alias latex2html='latex2html -no_footnode -auto_prefix -split 0 -info 0 -no_navigation'

if [[ "$uname" == 'Linux' ]]; then
    alias ack='ack-grep'
    alias vt='gvim --remote-tab'
    alias agi='sudo apt-get install'
    alias go='gnome-open'
elif [[ "$uname" == "Darwin" ]]; then
    alias vt='mvim --remote-tab'
    alias go='open'
fi


alias dserver='python manage.py runserver 9999'

#alias s3cmd='s3cmd -c /home/david/code/ura-2011-spring/websearch-experiment/dedup/third_party/s3cmd/.s3cfg'
#alias s3cmd='$HOME/code/ura2b/smucker_websearch/dedup/third_party/s3cmd/s3cmd -c $HOME/code/ura2b/smucker_websearch/dedup/third_party/s3cmd/.s3cfg'
#alias elastic-mapreduce='$HOME/bin/elastic-mapreduce-ruby/elastic-mapreduce'
alias elastic-mapreduce='$HOME/code/ura2b/smucker_websearch/dedup/third_party/elastic-mapreduce-ruby/elastic-mapreduce'

function jsdoc() {
    JSDOCDIR=$HOME/bin/jsdoc-toolkit
    java -Djsdoc.dir=$JSDOCDIR -jar "$JSDOCDIR"/jsrun.jar "$JSDOCDIR"/app/run.js -t="$JSDOCDIR"/templates/jsdoc -d=doc/ $@
}

alias lt='ls -trlhu'
alias ll='ls -l'
alias vm='vim `ls --color=none -t | head -n 1`'

alias m='mvim'
alias g='git'
alias h='hg'

function mr() {
    echo "$1/$('ls' -t $1 | head -n 1)";
}
function wiki() {
    dig +short txt "$*".wp.dg.cx
}
function mans() {
  man $1 | less -p "^ +$2";
}

# ------------------------------------------------------------------------------
# directory navigation shortcuts
# ------------------------------------------------------------------------------
pushd()
{
    builtin pushd "$@" > /dev/null
}
#alias cd='pushd '
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
