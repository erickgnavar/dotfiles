#!/usr/bin/env bash
set -euo pipefail

echo "Setting up your system!"

platform="${1:-$(uname -s)}"

case "$platform" in
Darwin | darwin | macOS | macos) platform_file="placements/macos.txt" ;;
Linux | linux) platform_file="placements/linux.txt" ;;
*)
  echo "Unsupported platform: $platform" >&2
  exit 1
  ;;
esac

while read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  source_path="${line%% *}"
  path="${line#* }"
  config_file="$(pwd)/$source_path"
  # Expand ~ to $HOME (avoids unsafe eval)
  path="${path/#\~/$HOME}"
  parent_dir=$(dirname "$path")

  # ensure the parent directory exists
  if [ ! -d "$parent_dir" ]; then
    echo "creating $parent_dir"
    mkdir -p "$parent_dir"
  fi

  if [ -e "$path" ]; then
    echo "$path already exists"
  else
    ln -s "$config_file" "$path"
    echo "symlink created: $config_file -> $path"
  fi
done < <(cat placements/common.txt "$platform_file")
