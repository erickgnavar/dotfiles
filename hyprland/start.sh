#!/usr/bin/env bash

# wayland wallpapers support
swwww init &

# network manager
nm-applet --indicator &

waybar &

# start clipboard manager
wl-paste --watch cliphist store &

# notification daemon
swaync
