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
text="${text//</\&lt;}"
text="${text//>/\&gt;}"

if [[ "$status" == "Playing" ]]; then
  icon=""
  class="playing"
else
  icon=""
  class="paused"
fi

jq -cn \
  --arg text "$text" \
  --arg icon "$icon" \
  --arg class "$class" \
  --arg alt "$status" \
  '{text: ($icon + " " + $text), class: $class, alt: $alt}'
