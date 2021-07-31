# setup antigen
MAC_INTEL_PATH="/usr/local/share/antigen/antigen.zsh"

if [ -f "$MAC_INTEL_PATH" ]
then
    source "$MAC_INTEL_PATH"
fi

MAC_ARM_PATH="/opt/homebrew/share/antigen/antigen.zsh"

if [ -f "$MAC_ARM_PATH" ]
then
    source "$MAC_ARM_PATH"
fi

# Load the oh-my-zsh's library.
antigen use oh-my-zsh
antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle mafredri/zsh-async
antigen bundle sindresorhus/pure

antigen apply

# setup pure-prompt
autoload -U promptinit; promptinit
prompt pure
