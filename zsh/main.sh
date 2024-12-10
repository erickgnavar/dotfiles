#!/bin/env bash
# disable oh my zsh theme so pure prompt can work properly
export ZSH_THEME=""

# ZSH history file config
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000
export SAVEHIST=1000000

# Ignore duplicates
setopt HIST_IGNORE_ALL_DUPS
# Ignore when prefixed with space
setopt HIST_IGNORE_SPACE
# Share history between sessions
setopt SHARE_HISTORY

# Load the default .profile
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"

# setup fzf
source <(fzf --zsh)
# Disable C-t which search into all files for the current folder to
# avoid press it by mistake
bindkey -r "^T"

# helper functions

function reload {
  source "$HOME/.zshrc"
}

function t() {
  tree -I '.git|node_modules|bower_components|.DS_store' --dirsfirst -L "${1:-3}" -aC "$2"
}

function docker_remove_containers() {
  docker rm "$(docker ps -a -q)"
}

function random_password() {
  openssl rand -base64 "$1"
}

# Estimate the compressed size of a file (GZIP)
function gzip_estimation() {
  gzip -9 -c "$1" | wc -c | awk '{$1=$1/1024; print "Estimated size:", $1, "Kb";}'
}

function docker_remove_images() {
  docker rmi "$(docker images -q)"
}

function transfer() {
  curl --upload-file "$1" "https://transfer.sh/$2"
}

function extract_youtube_audio() {
  youtube-dl "$1" --audio-format=mp3 -x
}

function download_video_best_quality() {
  youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 "$1"
}

function git_search() {
  git grep "$1" "$(git rev-list --all)"
}

# Use ~/.ssh/config to prompt a list of host and ssh to the chosen one
function ssh_connect() {
  local host
  host=$(grep "Host " ~/.ssh/config | awk '{print $2} END {print ""}' | fzf | sed 's/ //g' | sed 's/\n//g')
  echo "Connecting to $host..."
  ssh "$host"
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
alias g="git"
alias wow="git status"
alias cat="bat"
alias ls="eza --icons"
alias k="kubectl"

# direnv conf, load configuration only if the binary is already
# installed, silence stdout and stderr
which direnv 1>/dev/null 2>&1 && eval "$(direnv hook zsh)"

# load custom OS code
if [ "$(uname -s)" = "Darwin" ]; then
  source "$(dirname "$0")/mac.sh"
else
  source "$(dirname "$0")/linux.sh"
fi

function gitpr {
  git fetch upstream "refs/pull/$1/head:PR$1"
  git checkout "PR$1"
}

function video_to_gif {
  ffmpeg -i "$1" "$2" -hide_banner
}

# k8s helpers

function pick_namespace() {
  kubectl get ns | sed 1d | awk '{print $1}' | fzf --header="Select namespace"
}

function pick_pod() {
  kubectl get pods -n "$1" | sed 1d | awk '/Running/ {print $1}' | fzf --header="Select pod"
}

function pod_shell {
  local namespace
  namespace=$(pick_namespace)
  local pod
  pod=$(pick_pod "$namespace")
  echo "Connecting to $pod"

  if [ -z "$1" ]; then
    kubectl -n "$namespace" exec -ti "$pod" -- bash
  else
    kubectl -n "$namespace" exec -ti "$pod" -- "$1"
  fi
}

function pod_proxy {
  local namespace
  namespace=$(pick_namespace)
  local pod
  pod=$(pick_pod "$namespace")
  local port_mapping
  echo "Enter port mapping using the form local_port:pod_port"
  read -r port_mapping
  echo "Setting up proxy to $pod on $port_mapping..."

  kubectl port-forward -n "$namespace" "$pod" "$port_mapping"
}

function pod_logs {
  local namespace
  namespace=$(pick_namespace)
  local pod
  pod=$(pick_pod "$namespace")
  echo "Showing logs for $pod"

  kubectl -n "$namespace" logs -f "$pod"
}

function k8s_change_context {
  local context
  context=$(kubectl config get-contexts --output='name' | fzf --header="Select context")
  echo "Changing to $context"
  kubectl config use-context "$context"
}

alias tn="tmuxifier new-session"

function tl {
  local selection
  selection=$(ls ~/.tmuxifier/layouts | fzf --header="Select session")
  if [[ $selection != "" ]]; then
    local session_name
    session_name=$(echo "$selection" | awk '{split($0, a, "."); print a[1]}')

    tmuxifier load-session "$session_name"
  fi
}

# my jump, it's a similar concept of jump command but search into ~/Code folder
# and create a new tmux session with the selected project folder
function mj {
  local project_path
  project_path=$(tree ~/Code -L 2 --noreport -d -f -i | fzf)
  local org
  org=$(echo "$project_path" | awk '{split($0, a, "/"); print a[5]}')
  local project
  project=$(echo "$project_path" | awk '{split($0, a, "/"); print a[6]}')
  local session_name="$org/$project"

  # prevent tmux complain about being already inside a tmux session
  export TMUX=

  if [ "$session_name" = "" ]; then
    exit 1
  fi

  if ! tmux has-session -t "$session_name"; then
    tmux new-session -s "$session_name" -d
  fi

  # switch to session
  tmux switch-client -t "$session_name"

  window=${session_name}:0
  tmux send-keys -t "$window" "cd $project_path" Enter
}

function setup_rust_analyzer {
  local toolchain
  toolchain=$(printf "stable\nnightly" | fzf)

  echo "Creating symlink rust-analyzer for $toolchain toolchain"

  ln -sf "$(rustup which --toolchain "$toolchain" rust-analyzer)" "$HOME/.cargo/bin/rust-analyzer"
}
