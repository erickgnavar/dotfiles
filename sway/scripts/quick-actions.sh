#!/usr/bin/env bash
set -euo pipefail

selection=$(
  printf '%s\n' \
    "󰸉  Change wallpaper" \
    "󰄀  Take screenshot" \
    "󰖩  Share Wi-Fi" \
    "󰍹  Scale display" \
    "  Clipboard history" \
    "  Toggle night light" \
    "󰢹  Toggle remote desktop" \
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
"  Clipboard history")
  exec "$HOME/.config/sway/scripts/clipboard-menu.sh"
  ;;
"  Toggle night light")
  exec "$HOME/.config/waybar/scripts/night-light.sh" toggle
  ;;
"󰢹  Toggle remote desktop")
  exec "$HOME/.config/waybar/scripts/vnc-toggle.sh"
  ;;
"󰌾  Lock screen")
  exec "$HOME/.config/sway/scripts/lockscreen.sh"
  ;;
"󰐥  Power menu")
  exec "$HOME/.config/sway/scripts/wlogout-menu.sh"
  ;;
esac
