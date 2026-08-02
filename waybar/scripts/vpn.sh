#!/usr/bin/env bash
set -uo pipefail

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
  jq -cn --arg tooltip "$tooltip" \
    '{text: "", tooltip: ("VPN connected\n" + $tooltip), class: "connected"}'
else
  jq -cn '{text: "", tooltip: "VPN disconnected", class: "disconnected"}'
fi
