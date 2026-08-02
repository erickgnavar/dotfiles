#!/usr/bin/env bash
# Usage: disk.sh

read -r percent used total <<<"$(df -h / | awk 'NR==2 {gsub("%","",$5); print $5, $3, $2}')"

jq -n --arg percent "$percent" --arg used "$used" --arg total "$total" \
  '{percent: $percent, used: $used, total: $total}'
