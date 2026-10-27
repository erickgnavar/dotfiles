# Running-window dock

A Quickshell dock matching the dark capture toolbar, with blue active-window accents.

- Hover anywhere along the left screen edge to reveal it (100 ms delay).
- Move away to hide it (350 ms grace period).
- Click an icon to focus that window, including windows on other workspaces.
- Hover over an icon for its application name (100 ms delay), centered to its right.
- Each screen shares one click-through tooltip, with a 4-pixel gap from the dock.
- Scroll the dock when there are more windows than fit on screen.
- Each window has its own icon; the active window has a blue outline and indicator.
- Missing application icons fall back to the application's initial.

The dock appears on each output and lists all running windows. It does not reserve
workspace space, take keyboard focus, pin launchers, or run polling scripts.
Only a 3-pixel-wide, full-height activation strip receives input while hidden.
The trigger is available from startup, without first enabling the dock through IPC.
It requires the compositor's foreign-toplevel protocol (supported by Sway).

## Start

The repository's Quickshell directory must be linked at `~/.config/quickshell`
(as configured in `placements/linux.txt`). Then run:

```sh
qs -c dock
```

`sway/config` starts the dock for new sessions. Reloading Sway does not rerun `exec`
commands, so start it manually for the current session. Avoid launching duplicates.
To apply later QML edits, stop that dock instance and run the command again.

To force the dock open for testing:

```sh
qs -c dock ipc call dock toggle
```

Run it again to restore hover-only behavior. Forced mode stays open when the pointer leaves.

## Regression checks

```sh
python3 -B -m unittest discover -s quickshell/dock/tests -v
```

These require Python and Node.js. They check QML wiring and execute the actual JavaScript
handlers with mocked objects; they do not replace live Wayland positioning tests.
