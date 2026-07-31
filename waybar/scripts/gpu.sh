#!/usr/bin/env bash
if [ -f /sys/class/drm/card1/device/gpu_busy_percent ]; then
  u=$(cat /sys/class/drm/card1/device/gpu_busy_percent)
elif command -v nvidia-smi >/dev/null; then
  u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
else
  u=0
fi
echo "{\"text\": \"${u}%\", \"tooltip\": \"GPU: ${u}%\"}"
