export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="dracula"
# TODO: make dracula theme downloable if no exists

plugins=(git docker)

source $ZSH/oh-my-zsh.sh

# User configuration

export LANG="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_ALL=

# Prevent duplicates in bash history
setopt hist_ignore_all_dups

# Load the default .profile
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

# setup fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh ]

source $(dirname $0)/prompt.sh

# helper functions

function reload() {
    source ~/.zshrc
}

function run() {
    if [ -f ".run" ]; then
        bash .run $@
    fi
}

function t () {
    tree -I '.git|node_modules|bower_components|.DS_store' --dirsfirst -L ${1:-3} -aC $2
}

function elpy_install () {
    pip install elpy jedi flake8 yapf epc isort pdbpp importmagic
}

function docker_remove_containers() {
    docker rm $(docker ps -a -q)
}

function random_password() {
    openssl rand -base64 $1
}

# Estimate the compressed size of a file (GZIP)
function gzip_estimation() {
    gzip -9 -c $1 | wc -c | awk '{$1=$1/1024; print "Estimated size:", $1, "Kb";}'
}

function docker_remove_images() {
    docker rmi $(docker images -q)
}

function transfer() {
    curl --upload-file $1 https://transfer.sh/$2
}

function extract_youtube_audio() {
    youtube-dl $1 --audio-format=mp3 -x
}

function mkvenv() {
    local python_path="${HOME}/.pyenv/versions/$2/bin/python"

    if [ -f $python_path ]; then
        mkvirtualenv $1 --python=$python_path
    else
        echo "Python version doesn't exist"
        echo "Installing python $2"

        pyenv install $2

        if [ $? -eq 0 ]; then
            mkvirtualenv $1 --python=$python_path
        fi
    fi
}


function git_search() {
    git grep $1 $(git rev-list --all)
}

function kp() {
    local pid=$(ps -ef | sed 1d | eval "fzf ${FZF_DEFAULT_OPTS} -m --header='[kill:process]'" | awk '{print $2}')
    # https://github.com/SidOfc/dotfiles/blob/d07fa3862ed065c2a5a7f1160ae98416bfe2e1ee/zsh/kp

    if [ "x$pid" != "x" ]
    then
        echo $pid | xargs kill -${1:-9}
        kp
    fi
}

# custom alias
alias got="ps aux | grep"
alias grep="grep --color=auto"
alias json="python -m json.tool"
alias pipgrep="pip freeze | grep"
alias py3="python3"
alias py="python"
alias vi="vim"
alias weather="curl http://wttr.in/Lima"
alias wow="git status"
alias ipython='fades -d ipython -x ipython'
alias cat="bat"
alias ls="exa"
alias ping="prettyping --nolegend"

# direnv conf
eval "$(direnv hook zsh)"

# load cargo bin
if [ -d $HOME/.cargo/bin ]
then
    export PATH=$PATH:$HOME/.cargo/bin
fi

# Use ~/.ssh/config to prompt a list of host and ssh to the chosen one
function ssh_connect() {
    host=`cat ~/.ssh/config | grep "Host " | awk '{print $2} END {print ""}' | fzf | sed 's/ //g' | sed 's/\n//g'`
    echo "Connecting to $host..."
    ssh $host
}

# load custom OS code
if [ $(uname -s) = "Darwin" ]
then
    source $(dirname $0)/mac.sh
else
    source $(dirname $0)/linux.sh
fi
