#!/usr/bin/env bash
set -euo pipefail

emit_status() {
  local clients count tooltip

  if ! clients=$(wayvncctl --json client-list 2>/dev/null); then
    jq -cn '{text: "󰢹", tooltip: "WayVNC stopped — click to start", class: "stopped"}'
    return
  fi
  if ! count=$(jq -r 'if type == "array" then length else 0 end' <<<"$clients" 2>/dev/null); then
    count=0
  fi

  if ((count > 0)); then
    tooltip=$(jq -r '
      .[]
      | if .username then
          "\(.address // "Unknown address") (\(.username))"
        else
          (.address // "Unknown client")
        end
    ' <<<"$clients")
    jq -cn --arg count "$count" --arg tooltip "$tooltip" \
      '{text: ("󰢹 " + $count), tooltip: ("Active VNC sessions\n" + $tooltip + "\nClick to stop"), class: "active"}'
  else
    jq -cn '{text: "󰢹", tooltip: "WayVNC running — no active sessions\nClick to stop", class: "running"}'
  fi
}

emit_status
while IFS= read -r event; do
  case $(jq -r '.method // empty' <<<"$event" 2>/dev/null) in
  client-connected | client-disconnected | wayvnc-startup | wayvnc-shutdown)
    emit_status
    ;;
  esac
done < <(wayvncctl --wait --reconnect --json event-receive 2>/dev/null)
