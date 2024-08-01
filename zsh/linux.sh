#!/bin/env bash

# Alias to use xclip like macOS
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  alias pbcopy="wl-copy"
  alias pbpaste="wl-paste"
else
  alias pbcopy="xclip -selection clipboard"
  alias pbpaste="xclip -selection clipboard -o"
fi
