#!/usr/bin/env bash
set -euo pipefail

notify() {
  notify-send "Color picker" "$1" || true
}

# slurp -p returns 1 when the point selection is cancelled.
if point=$(slurp -p); then
  [[ -n "$point" ]] || exit 0
else
  status=$?
  [[ "$status" -eq 1 ]] && exit 0
  notify "Point selection failed."
  exit "$status"
fi

umask 077
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
trap 'exit 130' INT TERM HUP

if ! grim -g "$point" "$workdir/pixel.png"; then
  notify "Could not capture the selected pixel."
  exit 1
fi
if ! color=$(magick "$workdir/pixel.png" -format '%[hex:p{0,0}]' info:); then
  notify "Could not read the pixel color."
  exit 1
fi
[[ -n "$color" ]] || {
  notify "No color found. Clipboard unchanged."
  exit 0
}
hex=${color:0:6}

r=$((16#${hex:0:2}))
g=$((16#${hex:2:2}))
b=$((16#${hex:4:2}))

# Convert RGB to HSL with fixed-point math (micro-unit precision is plenty here).
scale=$((1000000))
r_scaled=$((r * scale / 255))
g_scaled=$((g * scale / 255))
b_scaled=$((b * scale / 255))
rg_max=$((r_scaled > g_scaled ? r_scaled : g_scaled))
gb_max=$((g_scaled > b_scaled ? g_scaled : b_scaled))
max=$((rg_max > gb_max ? rg_max : gb_max))
rg_min=$((r_scaled < g_scaled ? r_scaled : g_scaled))
gb_min=$((g_scaled < b_scaled ? g_scaled : b_scaled))
min=$((rg_min < gb_min ? rg_min : gb_min))
delta=$((max - min))
light_scaled=$(((max + min) / 2))
if ((delta == 0)); then
  hue=0
  sat_scaled=0
else
  if ((light_scaled * 2 <= scale)); then
    sat_scaled=$((delta * scale / (max + min)))
  else
    sat_scaled=$((delta * scale / (scale * 2 - max - min)))
  fi
  if ((max == r_scaled)); then
    hue=$((((g_scaled - b_scaled) * 60 * scale / delta) / scale))
  elif ((max == g_scaled)); then
    hue=$((((b_scaled - r_scaled) * 60 * scale / delta) / scale + 120))
  else
    hue=$((((r_scaled - g_scaled) * 60 * scale / delta) / scale + 240))
  fi
  ((hue < 0)) && hue=$((hue + 360))
fi
sat_pct=$(((sat_scaled * 100 + scale / 2) / scale))
light_pct=$(((light_scaled * 100 + scale / 2) / scale))

# Each entry is "Label<TAB>value"; the value after the tab is what gets copied.
menu=$(
  printf 'Hex\t#%s\n' "$hex"
  printf 'RGB\trgb(%d, %d, %d)\n' "$r" "$g" "$b"
  printf 'RGBA\trgba(%d, %d, %d, 1.0)\n' "$r" "$g" "$b"
  printf 'HSL\thsl(%d, %d%%, %d%%)\n' "$hue" "$sat_pct" "$light_pct"
)

# Rofi returns nonzero when the menu is dismissed.
if ! choice=$(printf '%s\n' "$menu" | rofi -dmenu -i -no-show-icons -p "Copy color as"); then
  exit 0
fi
value=${choice##*$'\t'}
if [[ -z "$value" ]]; then
  notify "Nothing selected. Clipboard unchanged."
  exit 0
fi
if ! printf '%s\n' "$value" | wl-copy --type text/plain; then
  notify "Could not copy the color."
  exit 1
fi
notify "Color copied: $value"
