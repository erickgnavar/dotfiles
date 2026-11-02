#!/usr/bin/env bash
mkdir -p ~/.config/zsh

load_zsh_plugin() {
  url=$1
  loader=$2
  plugin_dir=$(echo "$url" | awk -F'[/.]' '{print $(NF-1)}')

  if [ ! -d "$HOME/.config/zsh/$plugin_dir" ]; then
    git clone --depth 1 "$url" "$HOME/.config/zsh/$plugin_dir" || return
  fi

  . "$HOME/.config/zsh/$plugin_dir/$loader"
}

load_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting.zsh"
load_zsh_plugin "https://github.com/agkozak/zsh-z.git" "zsh-z.plugin.zsh"
load_zsh_plugin "https://github.com/Aloxaf/fzf-tab.git" "fzf-tab.plugin.zsh"

# Original Pure setup (kept as a reference).
# load_zsh_plugin "https://github.com/mafredri/zsh-async.git" "async.zsh"
# load_zsh_plugin "https://github.com/sindresorhus/pure.git" "pure.zsh"
# fpath+=("$HOME/.config/zsh/pure")
# autoload -U promptinit
# promptinit
# prompt pure

# Load the standalone Pure-style prompt.
source ~/.config/zsh/prompt.zsh

# load custom stuff per OS
source ~/.config/zsh/main.sh

nerdfetch
