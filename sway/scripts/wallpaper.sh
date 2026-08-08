#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Wallpapers"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
LAST_WALLPAPER_FILE="$STATE_DIR/last-wallpaper"

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

last_wallpaper=""
[[ -r "$LAST_WALLPAPER_FILE" ]] && last_wallpaper=$(<"$LAST_WALLPAPER_FILE")

choices=("${media[@]}")
if ((${#media[@]} > 1)) && [[ -n "$last_wallpaper" ]]; then
  choices=()
  for candidate in "${media[@]}"; do
    [[ "$candidate" != "$last_wallpaper" ]] && choices+=("$candidate")
  done
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

selected=${choices[RANDOM % ${#choices[@]}]}
mkdir -p "$STATE_DIR"
printf '%s\n' "$selected" >"$LAST_WALLPAPER_FILE"
mime_type=$(file --brief --mime-type -- "$selected")

case "$mime_type" in
image/*)
  swaymsg output '*' bg "$selected" fill
  ;;
video/*)
  mpvpaper -o "hwdec=vaapi no-audio loop" '*' "$selected"
  ;;
esac
