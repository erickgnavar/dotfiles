#!/usr/bin/env bash
set -euo pipefail

notify() {
  notify-send "Region OCR" "$1" || true
}

# slurp returns 1 when selection is cancelled.
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
if ! tesseract "$workdir/region.png" "$workdir/text" -l eng; then
  notify "Text recognition failed."
  exit 1
fi
if ! grep -q '[^[:space:]]' "$workdir/text.txt"; then
  notify "No text found. Clipboard unchanged."
  exit 0
fi
if ! wl-copy --type text/plain <"$workdir/text.txt"; then
  notify "Could not copy recognized text."
  exit 1
fi
notify "Text copied to clipboard."
