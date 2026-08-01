#!/usr/bin/env bash
# Usage: gpu.sh

if [ -f /sys/class/drm/card1/device/gpu_busy_percent ]; then
  percent=$(cat /sys/class/drm/card1/device/gpu_busy_percent)
  vram_used=$(($(cat /sys/class/drm/card1/device/mem_info_vram_used 2>/dev/null || echo 0) / 1048576))
  vram_total=$(($(cat /sys/class/drm/card1/device/mem_info_vram_total 2>/dev/null || echo 0) / 1048576))
elif command -v nvidia-smi >/dev/null; then
  read -r percent vram_used vram_total <<<"$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | tr -d ',')"
else
  percent=0
  vram_used=0
  vram_total=0
fi

jq -n --arg percent "$percent" --arg vram_used "$vram_used" --arg vram_total "$vram_total" \
  '{percent: $percent, vram_used: $vram_used, vram_total: $vram_total}'
