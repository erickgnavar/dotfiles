#!/usr/bin/env bash
set -euo pipefail

PICKER="$HOME/dotfiles/wallpaper-picker/result/bin/wallpaper-picker"
WALLPAPER_DIR="$HOME/Wallpapers"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
VIDEO_WALLPAPER_LINK="$STATE_DIR/current-video"

selected=$("$PICKER" "$WALLPAPER_DIR") || exit 0
[[ -n "$selected" && -f "$selected" ]] || exit 0

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
