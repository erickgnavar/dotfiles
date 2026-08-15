#!/usr/bin/env bash
set -euo pipefail

is_running() {
  pgrep -f '(^|/)gammastep([[:space:]]|$)' >/dev/null
}

case "${1:-status}" in
status)
  if is_running; then
    printf '{"text":"","tooltip":"Night light enabled","class":"enabled"}\n'
  else
    printf '{"text":"","tooltip":"Night light disabled","class":"disabled"}\n'
  fi
  ;;
toggle)
  if is_running; then
    pkill -f '(^|/)gammastep([[:space:]]|$)'
  else
    swaymsg exec 'gammastep -m wayland -l geoclue2 -t 6500:4000' >/dev/null
  fi
  ;;
*)
  echo "Usage: $0 [status|toggle]" >&2
  exit 2
  ;;
esac
