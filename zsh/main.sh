ZSH_THEME=""

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
[[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"

# load poetry
[[ -f "$HOME/.poetry/env" ]] && source "$HOME/.poetry/env"

source "$(dirname $0)/prompt.sh"

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

function download_video_best_quality() {
    youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 $1
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

# Use ~/.ssh/config to prompt a list of host and ssh to the chosen one
function ssh_connect() {
    host=`cat ~/.ssh/config | grep "Host " | awk '{print $2} END {print ""}' | fzf | sed 's/ //g' | sed 's/\n//g'`
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
alias ls="exa"
alias ping="prettyping --nolegend"

# direnv conf
eval "$(direnv hook zsh)"

# Use binaries from ~/.local/bin
# haskell stack install some binaries here: hindent, hlint, etc
export PATH="$PATH:$HOME/.local/bin"

# variable used to avoid java as a requirement when installing a version of erlang with asdf
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"

# load cargo bin
if [ -d $HOME/.cargo/bin ]
then
    export PATH=$PATH:$HOME/.cargo/bin
fi

# opam configuration
test -r "$HOME/.opam/opam-init/init.zsh" && . "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null || true

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
    namespace=`kubectl get ns | sed 1d | awk '{print $1}' | fzf`
    pod=`kubectl get pods -n $namespace | sed 1d | awk '{print $1}' | fzf`
    echo "Connecting to $pod"

    if [ -z $1 ]
    then
	kubectl -n $namespace exec -ti $pod bash
    else
	kubectl -n $namespace exec -ti $pod $1
    fi
}

function pod_proxy {
    namespace=`kubectl get ns | sed 1d | awk '{print $1}' | fzf`
    pod=`kubectl get pods -n $namespace | sed 1d | awk '{print $1}' | fzf`
    echo "Enter port mapping using the form local_port:pod_port"
    read port_mapping
    echo "Setting up proxy to $pod on $port_mapping..."

    kubectl port-forward -n $namespace $pod $port_mapping
}
