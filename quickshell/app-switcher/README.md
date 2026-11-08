# Application switcher

A dark/blue, icon-based switcher for running applications, grouped by desktop entry.
It focuses the most recently used surviving window of the selected application.
Focus history starts when this Quickshell configuration starts; older windows have
no historical ordering until focused.

- **Super+Tab**: open and select the next app, or cycle forward.
- **Super+Shift+Tab**: open/cycle backward.
- **Release Super**: focus the selection.
- **Escape**: cancel. **Enter** or clicking an app also selects it.
- **Left/Right**: cycle while open; long lists scroll horizontally.

The overlay takes exclusive keyboard focus only while visible. Window-list changes
close it to avoid activating destroyed windows. One persistent `swaymsg` subscription
receives ordered shortcut events, including Super releases before the overlay gains
focus. Cycling does not launch IPC processes. On selection, a Sway tree query
resolves the selected app/title to a container ID, then `swaymsg` focuses it.
Duplicate titles and changed titles use Sway's most-recent focus order within the app.
This avoids foreign-toplevel activation's dependency on a prior overlay keypress.
No previews or polling are used. The compositor chooses the screen for this overlay.

`placements/linux.txt` already deploys the entire `quickshell` directory. Apply
placements with `bash setup.sh linux`, then start the new configuration once:

```sh
qs -c app-switcher
```

Leave it running and run `swaymsg reload` in another terminal. Future Sway logins
start it automatically. After QML changes, restart with `qs -c app-switcher kill` and
`qs -c app-switcher`.

Live Sway validation is required for the exclusive keyboard grab and Super-release
handoff, including quick taps, reverse cycling, and both Super keys. Enter/Escape
also provide explicit selection/cancellation.

Run regression tests with:

```sh
python3 -B -m unittest discover -s quickshell/app-switcher/tests -v
```
