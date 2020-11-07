# This file is always executed, even for non interactive shells so it should only contains environment variables
# Setup lang
export LANG="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_ALL=

# Add homebrew binaries PATH
export PATH=$PATH:/usr/local/bin/

# Go binaries
export PATH=$PATH:$HOME/go/bin

# Use binaries from ~/.local/bin
# haskell stack install some binaries here: hindent, hlint, etc
export PATH="$PATH:$HOME/.local/bin"

# variable used to avoid java as a requirement when installing a version of erlang with asdf
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"

# Always save iex session history
export ERL_AFLAGS="-kernel shell_history enabled"

# load cargo bin
if [ -d $HOME/.cargo/bin ]
then
    export PATH=$PATH:$HOME/.cargo/bin
fi

if [ -d $HOME/.ghcup/ ]
then
    export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
fi

# opam configuration
test -r "$HOME/.opam/opam-init/init.zsh" && . "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null || true

# this will load credentials from a private file what won't be commited
test -r "$HOME/.zshenv.private" && . "$HOME/.zshenv.private"

# Setup asdf
export ASDF_DIR="/usr/local/opt/asdf"
# shellcheck source=/dev/null
[ -f "$ASDF_DIR/asdf.sh" ] && source "$ASDF_DIR/asdf.sh"
