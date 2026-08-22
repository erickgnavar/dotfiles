#!/usr/bin/env bash
set -euo pipefail

selection=$(
  printf '%s\n' \
    "󰸉  Change wallpaper" \
    "󰄀  Take screenshot" \
    "󰖩  Share Wi-Fi" \
    "󰍹  Scale display" \
    "󰑐  Refresh rate" \
    "  Clipboard history" \
    "  Toggle night light" \
    "󰢹  Toggle remote desktop" \
    "󰆴  Kill process" \
    "󰌾  Lock screen" \
    "󰐥  Power menu" |
    rofi -dmenu -i -p "Quick Actions"
) || exit 0

case "$selection" in
"󰸉  Change wallpaper")
  systemctl --user start wallpaper-rotate.service
  ;;
"󰄀  Take screenshot")
  exec "$HOME/.config/sway/scripts/screenshot.sh"
  ;;
"󰖩  Share Wi-Fi")
  exec "$HOME/.config/sway/scripts/wifi-qr.sh"
  ;;
"󰍹  Scale display")
  outputs=$(swaymsg --type get_outputs --raw)
  output=$(jq -r \
    'map(select(.focused))[0].name // map(select(.active))[0].name // empty' \
    <<<"$outputs")
  [[ -n "$output" ]] || exit 1

  current_scale=$(jq -r --arg output "$output" \
    '.[] | select(.name == $output) | .scale' <<<"$outputs")
  scale_selection=$(
    printf '%s\n' \
      "75%   (0.75×)" \
      "80%   (0.80×)" \
      "90%   (0.90×)" \
      "100%  (1.00×)" \
      "125%  (1.25×)" \
      "150%  (1.50×)" \
      "175%  (1.75×)" \
      "200%  (2.00×)" |
      rofi -dmenu -p "$output · Current ${current_scale}×"
  ) || exit 0

  case "$scale_selection" in
  "75%   (0.75×)") scale=0.75 ;;
  "80%   (0.80×)") scale=0.8 ;;
  "90%   (0.90×)") scale=0.9 ;;
  "100%  (1.00×)") scale=1.0 ;;
  "125%  (1.25×)") scale=1.25 ;;
  "150%  (1.50×)") scale=1.5 ;;
  "175%  (1.75×)") scale=1.75 ;;
  "200%  (2.00×)") scale=2.0 ;;
  *) exit 0 ;;
  esac

  swaymsg output "$output" scale "$scale" >/dev/null
  ;;
"󰑐  Refresh rate")
  compact_mode_filter='
    def compact_mode:
      if (.current_mode | type) == "object" then
        "\(.current_mode.width)x\(.current_mode.height)@\(.current_mode.refresh / 1000)hz"
      else
        ((try (
          (.current_mode // "")
          | capture("(?<width>[0-9]+)x(?<height>[0-9]+).*@ ?(?<rate>[0-9.]+).*Hz")
          | "\(.width)x\(.height)@\(.rate)hz"
        ) catch null) // "unknown")
      end;
  '
  outputs=$(swaymsg --type get_outputs --raw)
  output=$(
    jq -r 'map(select(.focused))[0].name // map(select(.active))[0].name // empty' \
      <<<"$outputs"
  )
  [[ -n "$output" ]] || exit 1

  output_selection=$(
    jq -r "$compact_mode_filter .[] | \"\(.name)\\t\(compact_mode)\"" <<<"$outputs" |
      rofi -dmenu -p "Select display"
  ) || exit 0
  [[ -n "$output_selection" ]] || exit 0
  output=${output_selection%%$'\t'*}

  current_status=$(jq -r --arg output "$output" \
    "$compact_mode_filter .[] | select(.name == \$output) | compact_mode" \
    <<<"$outputs")
  mode_selection=$(
    jq -r --arg output "$output" \
      '.[] | select(.name == $output) | .modes
      | sort_by([.width, .height, .refresh])
      | group_by([.width, .height, .refresh]) | map(.[0])
      | map("\(.width)x\(.height)@\(.refresh / 1000)hz")[]' \
      <<<"$outputs" |
      rofi -dmenu -p "$output · Current: $current_status"
  ) || exit 0
  [[ -n "$mode_selection" ]] || exit 0

  if [[ "$mode_selection" =~ ^([0-9]+)x([0-9]+)@([0-9.]+)hz$ ]]; then
    width=${BASH_REMATCH[1]}
    height=${BASH_REMATCH[2]}
    refresh=${BASH_REMATCH[3]}
  else
    exit 1
  fi

  swaymsg output "$output" mode "${width}x${height}@${refresh}Hz" >/dev/null
  ;;
"  Clipboard history")
  exec "$HOME/.config/sway/scripts/clipboard-menu.sh"
  ;;
"  Toggle night light")
  exec "$HOME/.config/waybar/scripts/night-light.sh" toggle
  ;;
"󰢹  Toggle remote desktop")
  exec "$HOME/.config/waybar/scripts/vnc-toggle.sh"
  ;;
"󰆴  Kill process")
  process_selection=$(
    ps -eo pid=,user=,%cpu=,%mem=,args= --sort=-%cpu |
      awk '{command = $5; sub(".*/", "", command); $5 = command; print}' |
      rofi -dmenu -i -p "Kill Process"
  ) || exit 0
  [[ -n "$process_selection" ]] || exit 0

  pid=$(awk '{print $1}' <<<"$process_selection")
  [[ "$pid" =~ ^[0-9]+$ ]] || exit 1
  kill -TERM -- "$pid"
  ;;
"󰌾  Lock screen")
  exec "$HOME/.config/sway/scripts/lockscreen.sh"
  ;;
"󰐥  Power menu")
  exec "$HOME/.config/sway/scripts/wlogout-menu.sh"
  ;;
esac
