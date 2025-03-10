#!/bin/env bash
mkdir -p ~/.config/zsh

function load_zsh_plugin() {
  url=$1
  loader=$2
  plugin_dir=$(echo "$url" | awk -F'[/.]' '{print $(NF-1)}')

  if [ ! -d "$HOME/.config/zsh/$plugin_dir" ]; then
    git clone --depth 1 "$url" "$HOME/.config/zsh/$plugin_dir"
  fi

  . "$HOME/.config/zsh/$plugin_dir/$loader"
}

load_zsh_plugin "https://github.com/ohmyzsh/ohmyzsh.git" "oh-my-zsh.sh"
load_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting.zsh"
load_zsh_plugin "https://github.com/mafredri/zsh-async.git" "async.zsh"
load_zsh_plugin "https://github.com/sindresorhus/pure.git" "pure.zsh"
load_zsh_plugin "https://github.com/agkozak/zsh-z.git" "zsh-z.plugin.zsh"

fpath+=("$HOME/.config/zsh/pure")
# setup pure-prompt
autoload -U promptinit
promptinit
prompt pure

# load custom stuff per OS
source ~/.config/zsh/main.sh

nerdfetch
