#!/usr/bin/env bash
set -euo pipefail

windows=$(swaymsg -t get_tree -r | jq '
  [.. | objects
   | select(.type? == "con" or .type? == "floating_con")
   | select(.app_id? != null or .window? != null)
   | {id, focused, label: (
       ((.app_id // .window_properties.class // "Application") + " — " + (.name // "Untitled"))
       | gsub("[\r\n\t]"; " ")
     )}]
  | sort_by(.focused)
')
[[ $(jq 'length' <<<"$windows") -gt 0 ]] || exit 0

selection=$(
  jq -r '.[].label' <<<"$windows" |
    rofi -dmenu -i -no-custom -format i -p "Open Windows"
) || exit 0
[[ "$selection" =~ ^[0-9]+$ ]] || exit 1

id=$(jq -r --argjson index "$selection" '.[$index].id // empty' <<<"$windows")
[[ -n "$id" ]] || exit 1
exec swaymsg "[con_id=$id] focus"
