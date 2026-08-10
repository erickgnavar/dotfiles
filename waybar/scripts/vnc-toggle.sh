#!/usr/bin/env bash
set -euo pipefail

if wayvncctl --json version >/dev/null 2>&1; then
  if systemctl --user is-active --quiet wayvnc.service; then
    systemctl --user stop wayvnc.service
  else
    # Also stop WayVNC instances started manually before the service existed.
    wayvncctl wayvnc-exit >/dev/null
  fi
  notify-send -a "WayVNC" -i preferences-desktop-remote-desktop -u low -t 3000 \
    "WayVNC stopped" "Remote desktop access is disabled."
  exit 0
fi

if ! systemctl --user start wayvnc.service; then
  notify-send -a "WayVNC" -i dialog-error -u critical \
    "WayVNC could not start" "Check the WayVNC user service logs."
  exit 1
fi

notify-send -a "WayVNC" -i preferences-desktop-remote-desktop -u normal -t 4000 \
  "WayVNC started" "Listening on 0.0.0.0:5901 using wayland-1."
