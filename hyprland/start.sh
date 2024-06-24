#!/usr/bin/env bash

# wayland wallpapers support
swwww init &

# network manager
nm-applet --indicator &

waybar &

# notification daemon
dunst
