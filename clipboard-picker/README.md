# Clipboard Picker

This is the active C/GTK4 clipboard picker. It compiles with GCC, GTK4, GLib, and JSON-GLib
development files.

It provides:

- Cliphist history in a virtualized `Gtk.ListView`.
- Cancellable worker-thread search with generation-safe result updates.
- Text and image previews.
- MIME, size, and content details.
- `Ctrl+N`/`Ctrl+P` and arrow-key list navigation.
- `Escape` to quit and activation to copy with `wl-copy`.
- Terminal-aware paste injection through `wtype`.
- The `com.erick.ClipboardPicker` app ID for Sway window matching.
- Full redraws forced to work around partial-redraw artifacts across renderers
  ([GTK issue #8339](https://gitlab.gnome.org/GNOME/gtk/-/work_items/8339)).
- Binary-safe decoding for image previews and clipboard writes.
- A 12px transparent gap between the history and preview panels.

## Build locally

From this directory, with GTK4 and JSON-GLib development files installed:

```bash
cc -O3 -march=native -Wall -Wextra -o clipboard-picker main.c \
  $(pkg-config --cflags --libs gtk4 gio-2.0 json-glib-1.0)
./clipboard-picker
```

On NixOS, enter a temporary development shell first:

```bash
nix-shell -p gcc pkg-config gtk4 glib.dev json-glib --run bash
```

Then compile and run it:

```bash
cc -O3 -march=native -Wall -Wextra -o clipboard-picker main.c \
  $(pkg-config --cflags --libs gtk4 gio-2.0 json-glib-1.0)
./clipboard-picker
```

History loading, parsing, and preview decoding are asynchronous. Preview loading is debounced, and
decoded entries are retained in a bounded LRU cache for faster navigation.

Manual local builds use `-O3 -march=native`, which optimizes for the local CPU and is not portable
between machines. The Nix package uses `-O3` because Nix deliberately rejects native CPU flags for
reproducible builds.

## Install with Nix

Build the package from this directory:

```bash
nix-build default.nix
./result/bin/clipboard-picker
```

Install it into the current Nix profile with:

```bash
nix-env -if default.nix
```

## Resident user service

The NixOS configuration starts the picker with `--gapplication-service`. This preloads GTK without
opening a window. Running the normal executable then activates the resident process over D-Bus.
Escape and successful paste actions hide the resident window instead of stopping the service.

Build the package before starting the service, then rebuild NixOS:

```bash
nix-build default.nix
sudo nixos-rebuild switch --flake ../nixos
systemctl --user restart clipboard-picker.service
```

The package includes GTK4, GLib, and JSON-GLib build dependencies plus runtime paths for Cliphist,
`wl-copy`, Sway, and `wtype`. Focused-application detection uses Sway's Unix IPC directly, without
`jq` or `swaymsg`.
