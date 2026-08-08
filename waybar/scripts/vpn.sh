#!/usr/bin/env bash
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
STATE_FILE="$STATE_DIR/vpn-state"
connections=()

while IFS=: read -r type name; do
  case "$type" in
  vpn | wireguard)
    [[ -n "$name" ]] && connections+=("$name")
    ;;
  esac
done < <(nmcli -t --escape no -f TYPE,NAME connection show --active 2>/dev/null)

if command -v tailscale >/dev/null 2>&1; then
  tailscale_state=$(timeout 2s tailscale status --json 2>/dev/null | jq -r '.BackendState // "Stopped"' 2>/dev/null)
  if [[ "$tailscale_state" == "Running" ]]; then
    connections+=("Tailscale")
  fi
fi

if ((${#connections[@]})); then
  tooltip=$(printf '%s\n' "${connections[@]}")
  current_state="connected:$tooltip"
else
  tooltip=""
  current_state="disconnected"
fi

previous_state=""
[[ -r "$STATE_FILE" ]] && previous_state=$(<"$STATE_FILE")
if [[ -n "$previous_state" && "$previous_state" != "$current_state" ]]; then
  if ((${#connections[@]})); then
    notify-send -a "VPN" -i network-vpn -u normal -t 4000 \
      "VPN connected" "$tooltip"
  else
    notify-send -a "VPN" -i network-vpn-disconnected -u normal -t 4000 \
      "VPN disconnected" "No VPN connection is active."
  fi
fi
mkdir -p "$STATE_DIR"
printf '%s\n' "$current_state" >"$STATE_FILE"

if ((${#connections[@]})); then
  jq -cn --arg tooltip "$tooltip" \
    '{text: "", tooltip: ("VPN connected\n" + $tooltip), class: "connected"}'
else
  jq -cn '{text: "", tooltip: "VPN disconnected", class: "disconnected"}'
fi
