#!/usr/bin/env bash
# Usage: gpu.sh

percent=0
vram_used=0
vram_total=0

# Prefer NVIDIA's own tool when available; DRM card numbering is not stable.
if command -v nvidia-smi >/dev/null; then
  gpu_info=$(nvidia-smi \
    --query-gpu=utilization.gpu,memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d ',')
  if [ -n "$gpu_info" ]; then
    read -r percent vram_used vram_total <<<"$gpu_info"
  fi
fi

# Fall back to the first AMD GPU exposed through sysfs.
if [ "$percent" -eq 0 ] && [ "$vram_used" -eq 0 ] && [ "$vram_total" -eq 0 ]; then
  for busy_path in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do
    [ -r "$busy_path" ] || continue
    device_path=${busy_path%/gpu_busy_percent}
    percent=$(<"$busy_path")
    vram_used_bytes=$(cat "$device_path/mem_info_vram_used" 2>/dev/null || echo 0)
    vram_total_bytes=$(cat "$device_path/mem_info_vram_total" 2>/dev/null || echo 0)
    vram_used=$((vram_used_bytes / 1048576))
    vram_total=$((vram_total_bytes / 1048576))
    break
  done
fi

jq -n --argjson percent "$percent" --argjson vram_used "$vram_used" \
  --argjson vram_total "$vram_total" \
  '{percent: $percent, vram_used: $vram_used, vram_total: $vram_total}'
