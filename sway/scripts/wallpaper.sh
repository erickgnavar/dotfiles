#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Wallpapers"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
LAST_WALLPAPER_FILE="$STATE_DIR/last-wallpaper"
VIDEO_WALLPAPER_LINK="$STATE_DIR/current-video"

last_wallpaper=""
[[ -r "$LAST_WALLPAPER_FILE" ]] && last_wallpaper=$(<"$LAST_WALLPAPER_FILE")
if [[ "${1:-}" == "--restore" && ! -f "$last_wallpaper" ]]; then
  exit 0
fi

if [[ "${1:-}" != "--restore" && ! -d "$WALLPAPER_DIR" ]]; then
  echo "Error: '$WALLPAPER_DIR' is not a directory" >&2
  exit 1
fi

media=()
while IFS= read -r -d '' candidate; do
  mime_type=$(file --brief --mime-type -- "$candidate")
  case "$mime_type" in
  image/* | video/*) media+=("$candidate") ;;
  esac
done < <(
  if [[ "${1:-}" == "--restore" ]]; then
    # Consider only the saved path instead of scanning the collection.
    printf '%s\0' "$last_wallpaper"
  else
    find "$WALLPAPER_DIR" -type f -print0
  fi
)

if ((${#media[@]} == 0)); then
  echo "No image or video files found in '$WALLPAPER_DIR'" >&2
  exit 1
fi

choices=("${media[@]}")
if ((${#media[@]} > 1)) && [[ -n "$last_wallpaper" ]]; then
  choices=()
  for candidate in "${media[@]}"; do
    [[ "$candidate" != "$last_wallpaper" ]] && choices+=("$candidate")
  done
fi

selected=${choices[0]}
if ((${#choices[@]} > 1)); then
  selected=${choices[RANDOM % ${#choices[@]}]}
fi
if [[ "${1:-}" != "--restore" ]]; then
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$selected" >"$LAST_WALLPAPER_FILE"
fi
mime_type=$(file --brief --mime-type -- "$selected")

case "$mime_type" in
image/*)
  systemctl --user stop wallpaper-video.service
  swaymsg output '*' bg "$selected" fill
  ;;
video/*)
  # Sway starts swaybg for static images; stop it before using mpvpaper.
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
