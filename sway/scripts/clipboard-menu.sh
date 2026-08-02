#!/usr/bin/env bash
set -euo pipefail

preview_dir=$(mktemp -d)
menu_file="$preview_dir/menu"
: >"$menu_file"
trap 'rm -rf "$preview_dir"' EXIT

while IFS= read -r entry; do
  display=${entry#*$'\t'}
  if [[ "$display" == "[[ binary data"* ]]; then
    id=${entry%%$'\t'*}
    preview="$preview_dir/$id"
    if printf '%s' "$entry" | cliphist decode >"$preview"; then
      details=${display#"[[ binary data "}
      details=${details%"]]"}
      printf '%s\0icon\x1f%s\x1fdisplay\x1fImage · %s\n' "$entry" "$preview" "$details" >>"$menu_file"
      continue
    fi
  fi
  printf '%s\0display\x1f%s\n' "$entry" "$display" >>"$menu_file"
done < <(cliphist list)

selection=$(rofi -dmenu -i -show-icons -p "Clipboard" \
  -theme-str 'element-icon { size: 80px; }' <"$menu_file") || exit 0
[[ -n "$selection" ]] || exit 0

printf '%s' "$selection" | cliphist decode | wl-copy
sleep 0.05

app_id=$(swaymsg -t get_tree | jq -r \
  'first(.. | objects | select(.focused? == true) | (.app_id // .window_properties.class // empty)) // empty')

case "${app_id,,}" in
*alacritty* | foot | footclient | *kitty* | *wezterm* | *ghostty* | *terminal* | konsole | xterm | urxvt)
  wtype -M ctrl -M shift v -m shift -m ctrl
  ;;
*)
  wtype -M ctrl v -m ctrl
  ;;
esac
