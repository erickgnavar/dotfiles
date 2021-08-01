if [ -z "$HOMEBREW_PREFIX" ]
then
    export HOMEBREW_PREFIX=$(brew --prefix)
fi

source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh"

# Load the oh-my-zsh's library.
antigen use oh-my-zsh
antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle mafredri/zsh-async

antigen apply

# load plugin from homwbrew installation
fpath+=("$HOMEBREW_PREFIX/opt/pure/share/zsh/site-functions")
# setup pure-prompt
autoload -U promptinit; promptinit
prompt pure
