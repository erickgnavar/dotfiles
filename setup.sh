#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
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

for manifest in placements/common.txt "$platform_file"; do
  if [[ ! -r "$manifest" ]]; then
    echo "Missing or unreadable manifest: $manifest" >&2
    exit 1
  fi
done

status=0
while read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  source_path="${line%% *}"
  path="${line#* }"
  config_file="$(pwd)/$source_path"
  # Expand ~ to $HOME (avoids unsafe eval)
  path="${path/#\~/$HOME}"
  if [[ ! -e "$config_file" ]]; then
    echo "Missing source: $config_file" >&2
    status=1
    continue
  fi

  if [[ -L "$path" && "$(readlink "$path")" == "$config_file" ]]; then
    echo "$path already linked"
    continue
  elif [[ -e "$path" ]]; then
    echo "Conflict: $path already exists; leaving unchanged" >&2
    status=1
    continue
  fi

  parent_dir=$(dirname "$path")

  # ensure the parent directory exists
  if [ ! -d "$parent_dir" ]; then
    echo "creating $parent_dir"
    mkdir -p "$parent_dir"
  fi

  ln -sf "$config_file" "$path"
  echo "symlink created: $config_file -> $path"
done < <(cat placements/common.txt "$platform_file")
exit "$status"
