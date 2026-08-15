#!/usr/bin/env bash
set -euo pipefail

selection=$(
  printf '%s\n' \
    "󰸉  Change wallpaper" \
    "󰄀  Take screenshot" \
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
