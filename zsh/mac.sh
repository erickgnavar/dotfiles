#!/bin/env bash
# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# Avoid auto update homwbrew packages
export HOMEBREW_NO_AUTO_UPDATE=1

# Setup gettext binaries
export PATH="/usr/local/opt/gettext/bin:$PATH"

# autojump setup
# intel
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# arm
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

# fix emoji and symbol pallete when it doesn't show up
fix_emoji_palette() {
  preferences_path="$HOME/Library/Preferences/com.apple.HIToolbox.plist"

  if [ -e "$preferences_path" ]; then
    rm "$preferences_path"
  fi
}

function rae() {
  open "https://dle.rae.es/$1"
}

alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs -nw"

# use native macOS network check tool
alias speedtest=networkQuality

function reset_cache {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
}

function homebrew-dump {
  cd ~/dotfiles/ || exit
  brew bundle dump --force
  git diff Brewfile
  cd - || exit
}

function nixdarwnin_run_install {
  cd ~/dotfiles/nix-darwin/ || exit 1
  mkdir -p ~/.config/nix-darwin/
  cp *.nix ~/.config/nix-darwin/
  cp flake.lock ~/.config/nix-darwin/
  sudo darwin-rebuild switch --flake ~/.config/nix-darwin#simple
  # now we copy lock file back to dotfiles
  cp ~/.config/nix-darwin/flake.lock .
  cd - || exit 1
}
