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

alias ll='ls -l'
alias vm='vim `ls --color=none -t | head -n 1`'

alias m='mvim'
alias g='git'
alias gti='git'
alias h='hg'
alias pyserve='python -m SimpleHTTPServer'
alias pdfserve='latexmk -pdf -pvc'
alias myip="curl icanhazip.com"
alias ad="arc diff"
alias adv="arc diff --verbatim"
alias gac="git ack"
alias rni="react-native run-ios"

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

# Announces result of last run command.
# eg. `some_long_command; notify`
function notify {
  status=$?
  if [ $status -eq 0 ]; then
    echo -e "\033[1;32m[ DONE ]\033[0m"
    ( say -v Cellos `printf "%0.s done" {1..26}` & )
  elif [ $status -ne 130 ]; then  # Ignore exit with Ctrl-C
    echo -e "\033[1;31m[ ERROR $status ]\033[0m"
    ( say "Oh noes, exit code $status" & )
  fi

  return $status
}

# Stolen from http://cfenollosa.com/misc/tricks.txt
function psgrep() { ps aux | grep -v grep | grep "$@" -i --color=auto; }
function lt() { ls -ltrsa "$@" | tail; }
function fname() { find . -iname "*$@*"; }

function git-reference() {
    git branch --set-upstream-to="$1"
    git rebase -i "$1"
}

function git-reference-master() {
    git-reference "master"
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

# Schedule sleep in X minutes, use like: sleep-in 60
function sleep-in() {
  local minutes=$1
  local datetime=`date -v+${minutes}M +"%m/%d/%y %H:%M:%S"`
  sudo pmset schedule sleep "$datetime"
}
