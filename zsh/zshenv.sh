#! /bin/env sh
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
export EDITOR=vim

# Add homebrew binaries PATH
export PATH=$PATH:/usr/local/bin/

# Go binaries
export PATH=$PATH:$HOME/go/bin

# Use binaries from ~/.local/bin
# haskell stack install some binaries here: hindent, hlint, etc
export PATH="$PATH:$HOME/.local/bin"

# --without-javac will disable java requirement for erlang compilation
# --enable-m64-build will pass a flag to gcc about how to build 64 bits binaries, fixes an error with make while compiling erlang using asdf/kerl
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac --enable-m64-build"

# Tell kerl to build documentation when compiling erlang
export KERL_BUILD_DOCS="yes"

# Always save iex session history
export ERL_AFLAGS="-kernel shell_history enabled"

# enhance man pages using bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# load cargo bin
if [ -f "$HOME/.cargo/env" ]
then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.ghcup/" ]
then
    export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
fi

# opam configuration
# shellcheck source=/dev/null
test -r "$HOME/.opam/opam-init/init.zsh" && . "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null

# this will load credentials from a private file what won't be commited
# shellcheck source=/dev/null
test -r "$HOME/.zshenv.private" && . "$HOME/.zshenv.private"

# setup for intel macOS
if [ -d "/usr/local/opt/asdf/libexec" ]
then
    . /usr/local/opt/asdf/libexec/asdf.sh
fi

# setup for arm macOS
if [ -d "/opt/homebrew/opt/asdf/libexec" ]
then
    . /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

# Disable telemetry in homebrew
export HOMEBREW_NO_ANALYTICS=1
