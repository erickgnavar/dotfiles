#!/usr/bin/env bash
# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# Avoid auto update homwbrew packages
export HOMEBREW_NO_AUTO_UPDATE=1

# Setup gettext binaries
export PATH="/usr/local/opt/gettext/bin:$PATH"

# fix emoji and symbol pallete when it doesn't show up
fix_emoji_palette() {
  preferences_path="$HOME/Library/Preferences/com.apple.HIToolbox.plist"

  if [ -e "$preferences_path" ]; then
    rm "$preferences_path"
  fi
}

rae() {
  open "https://dle.rae.es/$1"
}

# use native macOS network check tool
alias speedtest=networkQuality

reset_cache() {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
}

homebrew-dump() {
  cd ~/dotfiles/ || exit
  brew bundle dump --force
  git diff Brewfile
  cd - || exit
}

nixdarwin_run_install() {
  cd ~/dotfiles/nix-darwin/ || exit 1
  mkdir -p ~/.config/nix-darwin/
  cp *.nix ~/.config/nix-darwin/
  cp flake.lock ~/.config/nix-darwin/
  sudo darwin-rebuild switch --flake ~/.config/nix-darwin#simple
  # now we copy lock file back to dotfiles
  cp ~/.config/nix-darwin/flake.lock .
  cd - || exit 1
}

nixdarwin_free_space() {
  echo "collecting garbage..."
  nix-collect-garbage -d
  sudo nix-collect-garbage -d
  echo "optimizing storage, it might take a while..."
  nix-store --optimise
}
