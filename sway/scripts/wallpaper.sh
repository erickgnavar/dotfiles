#!/usr/bin/env bash
set -euo pipefail

pkill -9 -f "bin/mpvpaper" || true

sleep 0.5

VIDEO_DIR="$HOME/Videos/wallpapers/"

if [[ ! -d "$VIDEO_DIR" ]]; then
  echo "Error: '$VIDEO_DIR' is not a directory" >&2
  exit 1
fi

mapfile -d '' -t videos < <(find "$VIDEO_DIR" -type f -iname '*.mp4' -print0)

if [[ ${#videos[@]} -eq 0 ]]; then
  echo "No .mp4 files found in '$VIDEO_DIR'" >&2
  exit 1
fi

random_index=$((RANDOM % ${#videos[@]}))
selected="${videos[$random_index]}"

mpvpaper -o "hwdec=vaapi no-audio loop" '*' "$selected"
