#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Wallpapers"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Error: '$WALLPAPER_DIR' is not a directory" >&2
  exit 1
fi

media=()
while IFS= read -r -d '' candidate; do
  mime_type=$(file --brief --mime-type -- "$candidate")
  case "$mime_type" in
  image/* | video/*) media+=("$candidate") ;;
  esac
done < <(find "$WALLPAPER_DIR" -type f -print0)

if ((${#media[@]} == 0)); then
  echo "No image or video files found in '$WALLPAPER_DIR'" >&2
  exit 1
fi

mapfile -t mpvpaper_pids < <(pgrep -f '[m]pvpaper' || true)
if ((${#mpvpaper_pids[@]})); then
  kill "${mpvpaper_pids[@]}" 2>/dev/null || true
  for _ in {1..10}; do
    mpvpaper_running=false
    for pid in "${mpvpaper_pids[@]}"; do
      kill -0 "$pid" 2>/dev/null && mpvpaper_running=true
    done
    "$mpvpaper_running" || break
    sleep 0.05
  done
fi

selected=${media[RANDOM % ${#media[@]}]}
mime_type=$(file --brief --mime-type -- "$selected")

case "$mime_type" in
image/*)
  swaymsg output '*' bg "$selected" fill
  ;;
video/*)
  mpvpaper -o "hwdec=vaapi no-audio loop" '*' "$selected"
  ;;
esac
