#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(cd -- "$script_dir/.." && pwd)
if (($# != 1)); then
  echo "Usage: $0 OUTPUT" >&2
  exit 64
fi
output=$1
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Isolate package.el and all Emacs state from the user's configuration. This
# makes the batch export reproducible and prevents installed packages or an
# existing init file from affecting it.
export HOME="$work_dir/home"
export XDG_CONFIG_HOME="$work_dir/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

{
  echo "#+HTML_LINK_HOME: index.html"
  cat "$root_dir/.emacs.d/bootstrap.org"
} >"$work_dir/index.org"

emacs --batch \
  -Q \
  --load "$script_dir/org-render-html-minimal.el" \
  "$work_dir/index.org" \
  -f org-html-export-to-html

mkdir -p "$(dirname -- "$output")"
mv "$work_dir/index.html" "$output"
