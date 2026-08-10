#!/usr/bin/env bash
set -euo pipefail

if wayvncctl --json version >/dev/null 2>&1; then
  wayvncctl wayvnc-exit >/dev/null
  notify-send -a "WayVNC" -i preferences-desktop-remote-desktop -u low -t 3000 \
    "WayVNC stopped" "Remote desktop access is disabled."
  exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/wayvnc"
mkdir -p "$state_dir"
# Port 5900 is reserved by libvirt/QEMU's local VNC display.
nohup env WAYLAND_DISPLAY=wayland-1 \
  wayvnc -Ldebug 0.0.0.0 5901 >"$state_dir/wayvnc.log" 2>&1 &

notify-send -a "WayVNC" -i preferences-desktop-remote-desktop -u normal -t 4000 \
  "WayVNC started" "Listening on 0.0.0.0:5901 using wayland-1."
