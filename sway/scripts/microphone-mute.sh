#!/usr/bin/env bash
set -euo pipefail

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
state=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

if [[ "$state" == *"[MUTED]"* ]]; then
  message="Microphone muted"
  icon="microphone-sensitivity-muted-symbolic"
else
  message="Microphone unmuted"
  icon="microphone-sensitivity-high-symbolic"
fi

swayosd-client --custom-message "$message" --custom-icon "$icon"
