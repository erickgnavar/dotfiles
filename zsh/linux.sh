#!/usr/bin/env bash

# Alias to use xclip like macOS
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  alias pbcopy="wl-copy"
  alias pbpaste="wl-paste"
else
  alias pbcopy="xclip -selection clipboard"
  alias pbpaste="xclip -selection clipboard -o"
fi

# Open files in the background without desktop warnings.
open() {
  (nohup xdg-open "$@" </dev/null >/dev/null 2>&1 &)
}

nixos_run_install() {
  cd ~/dotfiles/nixos/ || exit 1
  # we need to use --impure because we're referencing absolute path
  # for hardware-configuration.nix file
  sudo nixos-rebuild --impure switch --flake .
  cd - || exit 1
}
