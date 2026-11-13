#!/usr/bin/env bash
set -euo pipefail

# --systemd updates both D-Bus activation and the systemd user manager.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY SWAYSOCK XDG_SESSION_TYPE

# Sway's socket identifies this session; reloads must only refresh the environment.
startup_dir="${XDG_RUNTIME_DIR:?}/sway-startup-${SWAYSOCK##*/}"
[[ -d "$startup_dir" ]] && exit 0
if ! mkdir -m 700 -- "$startup_dir"; then
  [[ -d "$startup_dir" ]] && exit 0
  exit 1
fi

systemctl --user restart clipboard-picker.service ||
  printf '%s\n' 'Failed to restart clipboard-picker.service' >&2

# A failed clipboard restart must not prevent wallpaper restoration.
bash "$HOME/.config/sway/scripts/wallpaper.sh" --restore
