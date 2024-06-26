#!/bin/env bash

echo "Setting up your system!"

while read -r line; do
    config_file="$(pwd)/$(echo "$line" | awk '{print $1}')"
    path=$(eval echo "$(echo "$line" | awk '{print $2}')")
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
done <placements.txt

if [ ! -d "$HOME/.tmuxifier/" ]; then
    echo "tmuxifier not installed, cloning..."
    git clone https://github.com/jimeh/tmuxifier.git ~/.tmuxifier
fi
