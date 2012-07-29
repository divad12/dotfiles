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
alias pyserve='python -m SimpleHTTPServer'
alias pdfserve='latexmk -pdf -pvc'
alias myip="curl icanhazip.com"

function mr() {
    echo "$1/$('ls' -t $1 | head -n 1)";
}
function wiki() {
    dig +short txt "$*".wp.dg.cx
}
function mans() {
  man $1 | less -p "^ +$2";
}

# Copy absolute filenames to a temporary file
# Modified from http://www.khattam.info/howto-command-line-copypaste-filesdirectories-in-linux-2010-10-27.html
function fcopy () {
  rm -f /tmp/fclipboard;
  dirlist=("$@")
  for file in "${dirlist[@]}"; do
    abspath "$file" >> /tmp/fclipboard;
  done;
}

# Paste filenames from temporary file to current directory
function fpaste() {
  while read line
    do cp -R "$line" ./ && echo "Pasted ${line}"
  done < /tmp/fclipboard
}

# ------------------------------------------------------------------------------
# directory navigation shortcuts
# ------------------------------------------------------------------------------

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

# make directory and cd to it
function md() {
    mkdir -p $1 && cd $1
}
