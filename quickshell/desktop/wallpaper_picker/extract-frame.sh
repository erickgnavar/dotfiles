#!/usr/bin/env bash
set -euo pipefail

video=${1:?Usage: extract-frame.sh VIDEO}
[[ -f "$video" ]] || exit 1

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
FRAME_DIR="$STATE_DIR/video-frames"
mkdir -p "$FRAME_DIR"
key=$(printf '%s\0%s' "$video" "$(stat -c '%y:%s' -- "$video")" | sha256sum | cut -d' ' -f1)
frame="$FRAME_DIR/$key.png"
if [[ ! -f "$frame" ]]; then
  temporary=$(mktemp "$FRAME_DIR/.${key}.tmp.XXXXXX.png")
  trap 'rm -f -- "$temporary"' EXIT
  ffmpeg -y -hide_banner -loglevel error \
    -i "$video" -map 0:v:0 -frames:v 1 "$temporary"
  mv -- "$temporary" "$frame"
  trap - EXIT
fi

printf '%s\n' "$frame"
