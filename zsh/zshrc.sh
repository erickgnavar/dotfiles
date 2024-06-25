if [ -z "$HOMEBREW_PREFIX" ]
then
    export HOMEBREW_PREFIX=$(brew --prefix)
fi

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

# load plugin from homwbrew installation
fpath+=("$HOMEBREW_PREFIX/opt/pure/share/zsh/site-functions")
# setup pure-prompt
autoload -U promptinit; promptinit
prompt pure
