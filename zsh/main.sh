#!/bin/env bash
# disable oh my zsh theme so pure prompt can work properly
export ZSH_THEME=""

# ZSH history file config
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000
export SAVEHIST=1000000
# Prevent duplicates in bash history
setopt hist_ignore_all_dups

# Load the default .profile
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

# setup fzf
[[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"

# load poetry
[[ -f "$HOME/.poetry/env" ]] && source "$HOME/.poetry/env"

# helper functions

function reload {
    source "$HOME/.zshrc"
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
    pip install elpy jedi flake8 epc isort pdbpp
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

function download_video_best_quality() {
    youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 $1
}

function mkvenv() {
    local python_path="${HOME}/.pyenv/versions/$1/bin/python"

    if [ -f $python_path ]; then
        poetry env use $python_path
    else
        echo "Python version doesn't exist"
        echo "Installing python $1"

        pyenv install $1

        if [ $? -eq 0 ]; then
            poetry env use $python_path
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

# Use ~/.ssh/config to prompt a list of host and ssh to the chosen one
function ssh_connect() {
    local host=`cat ~/.ssh/config | grep "Host " | awk '{print $2} END {print ""}' | fzf | sed 's/ //g' | sed 's/\n//g'`
    echo "Connecting to $host..."
    ssh $host
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
alias ls="eza --icons"
alias k="kubectl"

# direnv conf, load configuration only if the binary is already
# installed, silence stdout and stderr
which direnv 1>/dev/null 2>&1 && eval "$(direnv hook zsh)"

# load custom OS code
if [ $(uname -s) = "Darwin" ]
then
    source $(dirname $0)/mac.sh
else
    source $(dirname $0)/linux.sh
fi

function gitpr {
    git fetch upstream refs/pull/$1/head:PR$1
    git checkout PR$1
}

function video_to_gif {
    ffmpeg -i $1 $2 -hide_banner
}

# k8s helpers

function pod_shell {
    local namespace=`kubectl get ns | sed 1d | awk '{print $1}' | fzf --header="Select namespace"`
    local pod=`kubectl get pods -n $namespace | sed 1d | awk '/Running/ {print $1}' | fzf --header="Select pod"`
    echo "Connecting to $pod"

    if [ -z $1 ]
    then
        kubectl -n $namespace exec -ti $pod -- bash
    else
        kubectl -n $namespace exec -ti $pod -- $1
    fi
}

function pod_proxy {
    local namespace=`kubectl get ns | sed 1d | awk '{print $1}' | fzf --header="Select namespace"`
    local pod=`kubectl get pods -n $namespace | sed 1d | awk '{print $1}' | fzf --header="Select pod"`
    local port_mapping
    echo "Enter port mapping using the form local_port:pod_port"
    read port_mapping
    echo "Setting up proxy to $pod on $port_mapping..."

    kubectl port-forward -n $namespace $pod $port_mapping
}

function pod_logs {
    local namespace=`kubectl get ns | sed 1d | awk '{print $1}' | fzf --header="Select namespace"`
    local pod=`kubectl get pods -n $namespace | sed 1d | awk '/Running/ {print $1}' | fzf --header="Select pod"`
    echo "Showing logs for $pod"

    kubectl -n $namespace logs -f $pod
}

function k8s_change_context {
    local context=`kubectl config get-contexts --output='name' | fzf --header="Select context"`
    echo "Changing to $context"
    kubectl config use-context $context
}

alias tn="tmuxifier new-session"

function tl {
    local selection=$(ls ~/.tmuxifier/layouts | fzf --header="Select session")
    if [[ $selection != "" ]]
    then
    local session_name=$(echo "$selection" | awk '{split($0, a, "."); print a[1]}')

    tmuxifier load-session "$session_name"
    fi
}

# my jump, it's a similar concept of jump command but search into ~/Code folder
# and create a new tmux session with the selected project folder
function mj {
    local project_path=`tree ~/Code -L 2 --noreport -d -f -i | fzf`
    local org=`echo $project_path | awk '{split($0, a, "/"); print a[5]}'`
    local project=`echo $project_path | awk '{split($0, a, "/"); print a[6]}'`
    local session_name="$org/$project"

    # prevent tmux complain about being already inside a tmux session
    TMUX=

    if [ "$session_name" = "" ]
    then
         exit 1
    fi

    tmux has-session -t $session_name

    if [ $? != 0 ]
    then
        tmux new-session -s "$session_name" -d
    fi

    # switch to session
    tmux switch-client -t $session_name

    window=${session_name}:0
    tmux send-keys -t "$window" "cd $project_path" Enter
}

function setup_rust_analyzer {
    local toolchain=$(echo "stable\nnightly" | fzf)

    echo "Creating symlink rust-analyzer for $toolchain toolchain"

    ln -sf "$(rustup which --toolchain $toolchain rust-analyzer)" "$HOME/.cargo/bin/rust-analyzer"
}
