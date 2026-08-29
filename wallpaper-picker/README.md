# Wallpaper Picker

A small GTK4 wallpaper picker for Sway. It accepts a wallpaper directory, displays image
and video thumbnails, plays the selected video in the preview pane, and lets you navigate with
the keyboard.

## Usage

```bash
wallpaper-picker ~/Wallpapers
```

- Arrow keys or `Ctrl+N`/`Ctrl+P`: navigate wallpapers
- Enter: print the selected wallpaper path and exit
- Escape: cancel

The selected path is written to stdout, so it can be composed with other commands:

```bash
selected=$(wallpaper-picker "$HOME/Wallpapers")
[[ -n "$selected" ]] && printf '%s\n' "$selected"
```

Video thumbnails are generated with FFmpeg and cached in:

```text
~/.cache/wallpaper-picker/
```

## Build with Nix

Build without installing:

```bash
nix-build -E 'with import <nixpkgs> {}; callPackage ./wallpaper-picker {}'
```

Or build the derivation directly from this directory:

```bash
nix-build default.nix
./result/bin/wallpaper-picker ~/Wallpapers
```

The package wraps FFmpeg so video thumbnails work at runtime.

## Local build

```bash
nix-shell -p gcc pkg-config gtk4 gdk-pixbuf glib ffmpeg \
  gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good \
  gst_all_1.gst-plugins-bad gst_all_1.gst-libav --run bash
cc -O3 -Wall -Wextra -o wallpaper-picker main.c \
  $(pkg-config --cflags --libs gtk4 gdk-pixbuf-2.0)
./wallpaper-picker ~/Wallpapers
```
