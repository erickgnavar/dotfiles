# Quickshell lock screen

A Sway lock screen with per-monitor video backgrounds, clock/date, PAM authentication,
and animated password feedback. The layout adapts to small displays and long PAM messages.

## Setup

1. Deploy `quickshell/` to `~/.config/quickshell/` and `sway/scripts/lockscreen.sh` to
   `~/.config/sway/scripts/lockscreen.sh` using `placements/linux.txt`.
2. Rebuild NixOS to install the PAM service and Quickshell multimedia wrapper.
3. Test manually before relying on idle locking or suspend:

   ```sh
   ~/.config/sway/scripts/lockscreen.sh
   ```

The existing `Mod+Ctrl+Q` shortcut and swayidle configuration use this launcher.
Use the launcher rather than starting QML directly: it waits for compositor-confirmed locking.
Quickshell and its PAM service are required; missing dependencies or failed startup return an error.
There is no fallback locker.

## Behavior

- An inline Bash command uses GNU `find` and `shuf` to select a random readable MP4 recursively
  under `~/Wallpapers` during startup. Null-separated paths preserve special filenames.
  Video initializes only after locking, then fades in over a dark gradient when its first frame
  arrives. The gradient remains if media is missing or fails; media never gates lock readiness.
- The password input stays focused but hidden. Enter submits; Escape clears it and resets feedback.
  Additional PAM prompts are supported; prompts requesting visible responses show an input field.
- Typing pulses a circle, checking shows an ellipsis, failure turns it red and shakes it,
  and success shows a green checkmark before fading out.
- Configuration reload is disabled while locked; no IPC unlock method is exposed.

## Diagnostics and limitations

Logs, including video playback errors: `$XDG_RUNTIME_DIR/quickshell-lockscreen.log`.
Startup waits default to 10 seconds, configurable with `QUICKSHELL_LOCK_TIMEOUT`.
Duplicate requests verify the existing locker's secure state. A timeout or failed verification
returns an error, not a claim that the session is locked.

Swayidle's `before-sleep` integration is best-effort: a failed or slow lock does not guarantee
suspend will be canceled. Waybar's idle inhibitor does not disable before-sleep locking.

If the locker crashes after securing the screen, Sway keeps the session locked. Recovery may
require terminating the graphical session from another TTY, which closes its applications.

Password fields and pending references are cleared, but Qt/JavaScript does not guarantee secure
memory wiping or locked password buffers. This is not password-memory-security parity with
swaylock. Treat dumps as sensitive and verify swap/hibernation encryption separately.

## Testing

From the repository root, with Python 3, Node.js, Bash, ShellCheck, util-linux,
and GNU findutils/coreutils:

```sh
python3 -B -m unittest discover -s quickshell/lockscreen/tests -v
bash -n sway/scripts/lockscreen.sh
shellcheck sway/scripts/lockscreen.sh
```

Tests use mocks; they do not lock or suspend the machine. Save work and keep a recovery TTY
available for initial live testing:

1. Test wrong passwords, retries, rapid Enter presses, and successful authentication.
2. Check short/narrow displays, long feedback, mixed-DPI monitors, and monitor hotplug.
3. Test the shortcut and idle locking, then suspend/resume. Confirm the desktop stays locked
   until authentication succeeds.
