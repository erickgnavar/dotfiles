#!/usr/bin/env bash

player="spotify"

status=$(playerctl -p "$player" status 2>/dev/null)

if [[ -z "$status" ]]; then
  echo '{"text": "", "class": "stopped"}'
  exit 0
fi

artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
title=$(playerctl -p "$player" metadata title 2>/dev/null)

text="${artist} - ${title}"
text="${text//&/&amp;}"

if [[ "$status" == "Playing" ]]; then
  icon=""
  class="playing"
else
  icon=""
  class="paused"
fi

printf '{"text": "%s %s", "class": "%s", "alt": "%s"}\n' "$icon" "$text" "$class" "$status"
