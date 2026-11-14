# Qt runtime tests

Run from the repository root:

```sh
nix-shell --pure quickshell/qml-check.nix --run \
  'python3 -B quickshell/tests/run_qt_tests.py'
nix-shell --pure quickshell/qml-check.nix --run \
  'python3 -B quickshell/desktop/dock/tests/run_qt_tests.py'
```

Both commands run in Quickshell CI. They use Qt Quick Test with offscreen rendering and the
software backend by default; failures or missing Qt modules return a nonzero exit status.

## Coverage

- App switcher: cycling, accepting, empty lists, and windows removed before acceptance.
- Capture: busy guards, delayed capture, stopping exactly once, and disabled button appearance.
- Trimmer: real RangeSlider bindings, validity, playback boundaries, busy guards, and cancellation.
- Color picker: selection, derived patch paths, URL encoding, and safe cancellation.
- Wallpaper picker: model selection, preview fallback, video timers, opening, closing, and apply guards.
- Lock screen: empty submissions, busy guards, failed starts, challenges, input clearing, and accent.
- Desktop shell: production composition instantiates all six desktop components with safe fixtures.
- Dock: intermediate animation frames, synchronized slide/fade, endpoints, and reversal (separate suite).

## Isolation and limitations

`run_qt_tests.py` extracts selected properties and functions directly from production QML into
transient Qt Quick fixtures. Assertions run in Qt's QML engine, exercising property notifications,
signals, timers, ListModel, RangeSlider, and the production CaptureButton. Each test gets a fresh
fixture. Production files are not modified, and fixture output is removed after each run.

External processes, media playback, desktop-entry lookup, window enumeration, and PAM use service
doubles. The app switcher's singleton references are redirected to those doubles. The desktop
composition keeps its production component declarations, but resolves them to the generated fixtures;
its ShellRoot becomes an Item. The dock is a composition-only double in that suite.

These are isolated runtime tests, not full component/window integration tests. They do not cover
all UI bindings or handlers, real IPC, PAM authentication, media decoding, PipeWire, multi-screen
presentation, focus, input masks, or Wayland positioning. Those still require integration testing
with Quickshell and a compositor. Never load a real lock screen or authentication service in these
headless tests.
