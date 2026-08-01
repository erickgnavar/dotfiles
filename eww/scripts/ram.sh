#!/usr/bin/env bash
# Usage: ram.sh

mem=$(free -m | awk '/Mem:/ {printf "%d %d %d", $3, $2, ($3/$2)*100}')
used=$(echo "$mem" | awk '{print $1}')
total=$(echo "$mem" | awk '{print $2}')
percent=$(echo "$mem" | awk '{print $3}')

human() {
  local mb=$1
  if [ "$mb" -gt 1024 ]; then
    echo "$(echo "scale=1; $mb/1024" | bc)G"
  else
    echo "${mb}M"
  fi
}

used_h=$(human "$used")
total_h=$(human "$total")

jq -n --arg used "$used_h" --arg total "$total_h" --arg percent "$percent" \
  '{used: $used, total: $total, percent: $percent}'
