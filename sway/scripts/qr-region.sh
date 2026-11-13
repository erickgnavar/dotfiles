#!/usr/bin/env bash
set -euo pipefail

notify() {
  notify-send "Region QR code" "$1" || true
}

if region=$(slurp); then
  [[ -n "$region" ]] || exit 0
else
  status=$?
  [[ "$status" -eq 1 ]] && exit 0
  notify "Region selection failed."
  exit "$status"
fi

umask 077
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
trap 'exit 130' INT TERM HUP

if ! grim -g "$region" "$workdir/region.png"; then
  notify "Could not capture the selected region."
  exit 1
fi
if zbarimg --quiet --raw --set '*.disable' --set 'qrcode.enable' \
  "$workdir/region.png" >"$workdir/text.txt"; then
  :
else
  status=$?
  if [[ "$status" -eq 4 ]]; then
    notify "No QR code found. Clipboard unchanged."
    exit 0
  fi
  notify "QR recognition failed."
  exit "$status"
fi
if [[ ! -s "$workdir/text.txt" ]]; then
  notify "No QR code found. Clipboard unchanged."
  exit 0
fi
if ! wl-copy --type text/plain <"$workdir/text.txt"; then
  notify "Could not copy decoded text."
  exit 1
fi
notify "QR code text copied to clipboard."
