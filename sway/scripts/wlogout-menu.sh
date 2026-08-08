#!/usr/bin/env bash
set -euo pipefail

read -r width height monitor < <(
  swaymsg --type get_outputs --raw |
    jq --raw-output '
      to_entries as $outputs
      | ($outputs | map(select(.value.focused))[0] // $outputs[0])
      | "\(.value.rect.width) \(.value.rect.height) \(.key)"
    '
)

buttons=6
spacing=12
button_width=140
menu_height=160
menu_width=$((buttons * button_width + (buttons - 1) * spacing))
horizontal_margin=$(((width - menu_width) / 2))
vertical_margin=$(((height - menu_height) / 2))

((horizontal_margin < 16)) && horizontal_margin=16
((vertical_margin < 16)) && vertical_margin=16

exec wlogout \
  --protocol layer-shell \
  --buttons-per-row "$buttons" \
  --column-spacing "$spacing" \
  --margin-left "$horizontal_margin" \
  --margin-right "$horizontal_margin" \
  --margin-top "$vertical_margin" \
  --margin-bottom "$vertical_margin" \
  --primary-monitor "$monitor" \
  --no-span
