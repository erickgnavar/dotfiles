#!/usr/bin/env bash
set -euo pipefail

mode=${1:-}
if [[ -z "$mode" ]]; then
  selection=$(printf '%s\n' "Full screen" "Select region" "Focused window" |
    rofi -dmenu -i -p "Screenshot") || exit 0
  case "$selection" in
  "Full screen") mode="full" ;;
  "Select region") mode="region" ;;
  "Focused window") mode="window" ;;
  *) exit 0 ;;
  esac
fi

screenshot_dir="$HOME/Pictures/Screenshots"
capture=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/screenshot.XXXXXX.png")
trap 'rm -f "$capture"' EXIT
mkdir -p "$screenshot_dir"

case "$mode" in
full)
  grim "$capture"
  ;;
region)
  geometry=$(slurp) || exit 0
  [[ -n "$geometry" ]] || exit 0
  grim -g "$geometry" "$capture"
  ;;
window)
  geometry=$(swaymsg -t get_tree | jq -r \
    'first(.. | objects | select(.focused? == true) | .rect | "\(.x),\(.y) \(.width)x\(.height)") // empty')
  [[ -n "$geometry" ]] || exit 1
  grim -g "$geometry" "$capture"
  ;;
*)
  printf 'Usage: %s {full|region|window}\n' "${0##*/}" >&2
  exit 2
  ;;
esac

satty --filename "$capture" \
  --app-id org.satty.satty \
  --copy-command wl-copy \
  --output-filename "$screenshot_dir/screenshot-%Y-%m-%d_%H-%M-%S.png"
