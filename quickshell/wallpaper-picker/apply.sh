#!/usr/bin/env bash
set -euo pipefail

frame0=false
if [[ ${1:-} == --frame0 ]]; then
  frame0=true
  shift
fi
selected=${1:?Usage: apply.sh [--frame0] WALLPAPER}
[[ -f "$selected" ]] || exit 1

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
VIDEO_WALLPAPER_LINK="$STATE_DIR/current-video"
if "$frame0"; then
  script_dir=$(
    CDPATH=
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
  )
  selected=$(bash "$script_dir/extract-frame.sh" "$selected")
fi
mkdir -p "$STATE_DIR"
printf '%s\n' "$selected" >"$STATE_DIR/last-wallpaper"
mime_type=$(file --brief --mime-type -- "$selected")

case "$mime_type" in
image/*)
  systemctl --user stop wallpaper-video.service
  swaymsg output '*' bg "$selected" fill
  ;;
video/*)
  mapfile -t swaybg_pids < <(pgrep -f '[s]waybg' || true)
  if ((${#swaybg_pids[@]})); then
    kill "${swaybg_pids[@]}" 2>/dev/null || true
    for _ in {1..10}; do
      swaybg_running=false
      for pid in "${swaybg_pids[@]}"; do
        kill -0 "$pid" 2>/dev/null && swaybg_running=true
      done
      "$swaybg_running" || break
      sleep 0.05
    done
  fi
  ln -sfn -- "$selected" "$VIDEO_WALLPAPER_LINK"
  systemctl --user restart wallpaper-video.service
  ;;
esac
