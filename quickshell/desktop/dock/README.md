# Application dock

A Quickshell dock matching the dark capture toolbar, with blue active-window accents.

- Hover anywhere along the left screen edge to reveal it (100 ms delay).
- Move away to hide it (350 ms grace period).
- Pins appear in order: Helium, Alacritty, Emacs, Spotify, and Nautilus.
- Click a closed pinned app to launch it using its installed desktop entry.
- Click an app with one window to focus it, including on another workspace.
- Click an app with multiple windows to open a scrollable chooser with icons and window titles.
- Chooser rows show the workspace and focused/urgent state, using Sway events while open.
  Identical app/title matches show “Workspace unknown” instead of guessing; titles still work.
- Click a title to focus that window; click the app again or move away to dismiss the chooser.
- Hover over an icon for its application name (100 ms delay), centered to its right.
- Each screen shares one click-through tooltip, with a 4-pixel gap from the dock.
- Scroll the dock when there are more windows than fit on screen.
- Pinned apps group their windows into one icon; other windows appear after the pins.
- Running apps have an indicator; active apps also have a blue outline.
- Missing application icons fall back to the application's initial.

The dock appears on each output. Edit `pinnedApps` in `Dock.qml` to change the desktop IDs
or their order. Apps must be installed for desktop-entry launching and icon lookup.
It does not reserve workspace space, take keyboard focus, or run polling scripts.
Only a 3-pixel-wide, full-height activation strip receives input while hidden.
The trigger is available from startup, without first enabling the dock through IPC.
It requires the compositor's foreign-toplevel protocol (supported by Sway).

## Start

The repository's Quickshell directory must be linked at `~/.config/quickshell`
(as configured in `placements/linux.txt`). Then run:

```sh
qs -c desktop
```

The dock now lives in the merged `desktop` Quickshell configuration together with the
capture toolbar, app switcher, and wallpaper picker, so they share one process.
`sway/config` starts it for new sessions. Reloading Sway does not rerun `exec` commands, so start it
manually for the current session. Avoid launching duplicates. To apply later QML edits,
stop that instance and run the command again.

To force the dock open for testing:

```sh
qs -c desktop ipc call dock toggle
```

Run it again to restore hover-only behavior. Forced mode stays open when the pointer leaves.

## Regression checks

```sh
python3 -B -m unittest discover -s quickshell/desktop/dock/tests -v
```

These require Python and Node.js. They check QML wiring and execute the actual JavaScript
handlers with mocked objects; they do not replace live Wayland positioning tests.

## Qt runtime tests

From the repository root:

```sh
nix-shell quickshell/qml-check.nix --run \
  'python3 -B quickshell/desktop/dock/tests/run_qt_tests.py'
```

The runner uses `qmltestrunner` with the offscreen platform and software rendering by default.
It extracts the production slide/fade bindings from `Dock.qml` into a temporary Qt Quick scene.
Tests exercise intermediate frames, synchronized motion, endpoints, and mid-animation reversal.
The `.qml.in` template becomes a QML test beside that generated scene; no fixture is kept in-tree.
These tests do not instantiate Quickshell windows or verify input masks, hover, or Wayland behavior.
