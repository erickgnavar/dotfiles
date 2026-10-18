#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell-recording.pid"
if [[ -r "$state_file" ]]; then
  pid=$(<"$state_file")
  if [[ "$pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' '{"text":"● REC","tooltip":"Recording · Click to stop (Mod+Ctrl+S)","class":"recording"}'
    exit 0
  fi
fi
printf '%s\n' '{"text":"","tooltip":"","class":"idle"}'
