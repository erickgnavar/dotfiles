#!/usr/bin/env bash
# Usage: net.sh speed | net.sh usage

mode="$1"

# Detect first active (UP, non-loopback) interface
iface=$(ip -brief link | grep "  UP " | awk '{print $1}' | xargs | awk '$1 != "lo" {print $1; exit}')

if [ -z "$iface" ]; then
  if [ "$mode" = "speed" ]; then
    echo '{"down": "--", "up": "--"}'
  else
    echo '{"down_total": "--", "up_total": "--"}'
  fi
  exit 0
fi

rx_path="/sys/class/net/$iface/statistics/rx_bytes"
tx_path="/sys/class/net/$iface/statistics/tx_bytes"

if [ ! -f "$rx_path" ]; then
  if [ "$mode" = "speed" ]; then
    echo '{"down": "--", "up": "--"}'
  else
    echo '{"down_total": "--", "up_total": "--"}'
  fi
  exit 0
fi

human_rate() {
  local kb=$1
  if [ "$kb" -gt 1000 ]; then
    echo "$(echo "scale=1; $kb/1024" | bc) MB/s"
  else
    echo "${kb} KB/s"
  fi
}

human_total() {
  local bytes=$1
  if [ "$bytes" -gt 1073741824 ]; then
    echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
  else
    echo "$((bytes / 1048576)) MB"
  fi
}

case "$mode" in
speed)
  rx1=$(cat "$rx_path")
  tx1=$(cat "$tx_path")
  sleep 1
  rx2=$(cat "$rx_path")
  tx2=$(cat "$tx_path")

  down_kb=$(((rx2 - rx1) / 1024))
  up_kb=$(((tx2 - tx1) / 1024))

  down=$(human_rate "$down_kb")
  up=$(human_rate "$up_kb")

  jq -n --arg down "$down" --arg up "$up" '{down: $down, up: $up}'
  ;;

usage)
  rx=$(cat "$rx_path")
  tx=$(cat "$tx_path")

  down_total=$(human_total "$rx")
  up_total=$(human_total "$tx")

  jq -n --arg down "$down_total" --arg up "$up_total" '{down_total: $down, up_total: $up}'
  ;;

*)
  echo '{"error": "usage: net.sh speed|usage"}'
  exit 1
  ;;
esac
