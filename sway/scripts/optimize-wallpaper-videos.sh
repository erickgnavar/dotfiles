#!/usr/bin/env bash
set -uo pipefail

WALLPAPER_DIR="${1:-$HOME/Wallpapers}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
BACKUP_DIR="$STATE_DIR/original-videos/$(date +%Y%m%d-%H%M%S)-$$"
temporary=""

cleanup() {
  [[ -n "$temporary" ]] && rm -f -- "$temporary"
}
trap cleanup EXIT INT TERM

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Error: '$WALLPAPER_DIR' is not a directory" >&2
  exit 1
fi

videos=()
while IFS= read -r -d '' candidate; do
  [[ $(file --brief --mime-type -- "$candidate") == video/* ]] && videos+=("$candidate")
done < <(find "$WALLPAPER_DIR" -type f ! -name '.wallpaper-*.mp4' -print0)

if ((${#videos[@]} == 0)); then
  echo "No video wallpapers found in '$WALLPAPER_DIR'"
  exit 0
fi

converted=0
failed=0
for source in "${videos[@]}"; do
  relative=${source#"$WALLPAPER_DIR"/}
  output="$WALLPAPER_DIR/${relative%.*}.mp4"
  backup="$BACKUP_DIR/$relative"

  if [[ "$output" != "$source" && -e "$output" ]]; then
    echo "Skipping '$source': '$output' already exists" >&2
    ((failed++))
    continue
  fi

  mkdir -p "$(dirname "$output")" "$(dirname "$backup")"
  temporary=$(mktemp --tmpdir="$(dirname "$output")" ".wallpaper-XXXXXX.mp4")

  echo "Encoding '$relative' at 30 FPS..."
  if ffmpeg -y -nostdin -hide_banner -loglevel warning -stats \
    -i "$source" -map 0:v:0 -an -vf fps=30 \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p \
    -movflags +faststart "$temporary" &&
    ffprobe -v error -select_streams v:0 -show_entries stream=index \
      -of csv=p=0 "$temporary" | grep -q .; then
    mv -- "$source" "$backup"
    mv -- "$temporary" "$output"
    temporary=""
    ((converted++))
  else
    echo "Failed to encode '$source'" >&2
    rm -f -- "$temporary"
    temporary=""
    ((failed++))
  fi
done

echo "Converted: $converted; failed or skipped: $failed"
if ((converted > 0)); then
  echo "Original videos: $BACKUP_DIR"
fi
((failed == 0))
