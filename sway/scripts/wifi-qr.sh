#!/usr/bin/env bash
set -euo pipefail

umask 077
ulimit -c 0

show_error() {
  rofi -e "$1"
  exit 1
}

escape_wifi_field() {
  printf '%s' "$1" | sed 's/[\\;,:]/\\&/g'
}

[[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" && -w "$XDG_RUNTIME_DIR" ]] ||
  show_error "A private runtime directory is not available"

device=$(nmcli -t --escape no -f DEVICE,TYPE,STATE device status |
  awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
[[ -n "$device" ]] || show_error "No active Wi-Fi connection"

connection_uuid=$(nmcli --escape no -g GENERAL.CON-UUID device show "$device")
[[ -n "$connection_uuid" ]] || show_error "The active Wi-Fi connection has no UUID"
ssid=$(nmcli --escape no -g 802-11-wireless.ssid connection show "$connection_uuid")
key_mgmt=$(nmcli --escape no -g 802-11-wireless-security.key-mgmt connection show "$connection_uuid")
hidden=$(nmcli --escape no -g 802-11-wireless.hidden connection show "$connection_uuid")
[[ -n "$ssid" ]] || show_error "The active Wi-Fi network has no SSID"

password=""
case "$key_mgmt" in
"" | none)
  password=$(nmcli -s --escape no -g 802-11-wireless-security.wep-key0 \
    connection show "$connection_uuid" 2>/dev/null || true)
  if [[ -n "$password" ]]; then
    security=WEP
  else
    security=nopass
  fi
  ;;
wpa-psk | sae | wpa-none)
  security=WPA
  password=$(nmcli -s --escape no -g 802-11-wireless-security.psk connection show "$connection_uuid")
  [[ -n "$password" ]] || show_error "NetworkManager did not provide the Wi-Fi password"
  ;;
wpa-eap | ieee8021x)
  show_error "Enterprise Wi-Fi QR sharing is not supported"
  ;;
*)
  show_error "Unsupported Wi-Fi security type: $key_mgmt"
  ;;
esac

ssid_escaped=$(escape_wifi_field "$ssid")
password_escaped=$(escape_wifi_field "$password")
[[ "$hidden" == yes ]] && hidden=true || hidden=false
payload="WIFI:T:$security;S:$ssid_escaped;P:$password_escaped;H:$hidden;;"

qr_file=$(mktemp "$XDG_RUNTIME_DIR/wifi-qr.XXXXXX.png")
trap 'rm -f "$qr_file"' EXIT
printf '%s' "$payload" | qrencode -t PNG -s 8 -m 2 -o "$qr_file"
unset password password_escaped payload

printf 'Scan to join %s\0icon\x1f%s\n' "$ssid" "$qr_file" |
  rofi -dmenu -p "Wi-Fi QR" -show-icons -no-custom \
    -theme-str 'window { width: 360px; } listview { lines: 1; } element { orientation: vertical; } element-icon { size: 256px; } element-text { horizontal-align: 0.5; }' \
    >/dev/null || true
