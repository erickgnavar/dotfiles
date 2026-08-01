#!/usr/bin/env bash
# Usage: cpu.sh

read -r _ user nice system idle iowait irq softirq steal _ _ </proc/stat
prev_idle=$((idle + iowait))
prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

sleep 0.5

read -r _ user nice system idle iowait irq softirq steal _ _ </proc/stat
idle_now=$((idle + iowait))
total_now=$((user + nice + system + idle + iowait + irq + softirq + steal))

diff_idle=$((idle_now - prev_idle))
diff_total=$((total_now - prev_total))
percent=$(((1000 * (diff_total - diff_idle) / diff_total + 5) / 10))

load=$(awk '{print $1}' /proc/loadavg)
cores=$(nproc)

jq -n --arg percent "$percent" --arg load "$load" --arg cores "$cores" \
  '{percent: $percent, load: $load, cores: $cores}'
