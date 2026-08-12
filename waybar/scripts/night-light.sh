#!/usr/bin/env bash
set -euo pipefail

is_running() {
  pgrep -x wlsunset >/dev/null
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
    pkill -x wlsunset
  else
    swaymsg exec 'wlsunset -l 19.4326 -L -99.1332 -t 4000 -T 6500' >/dev/null
  fi
  ;;
*)
  echo "Usage: $0 [status|toggle]" >&2
  exit 2
  ;;
esac
