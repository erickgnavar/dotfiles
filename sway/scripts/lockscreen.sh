#!/usr/bin/env bash
set -euo pipefail

# Serialize startup so duplicate requests wait for the first locker's readiness.
exec 8>"${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/sway-lockscreen-startup.lock"
flock 8

# Keep this second lock held by the daemon until unlock.
exec 9>"$XDG_RUNTIME_DIR/sway-lockscreen.lock"
flock --nonblock 9 || exit 0

VIDEO_DIR="$HOME/Wallpapers/"
videos=()
if [[ -d "$VIDEO_DIR" ]] && command -v mpvpaper >/dev/null; then
  mapfile -d '' -t videos < <(find "$VIDEO_DIR" -type f -readable -iname '*.mp4' -print0)
fi

# Ignore user-configured backgrounds so the non-video fallback stays predictable.
args=(--config /dev/null --daemonize --color 000000)
if ((${#videos[@]})); then
  # Pass the path through the environment, not interpolation into a shell command.
  export SWAYLOCK_VIDEO="${videos[RANDOM % ${#videos[@]}]}"
  # Expanded by the plugin's shell, not this script.
  # shellcheck disable=SC2016
  args+=(--command 'mpvpaper -o "hwdec=vaapi no-audio loop" "*" "$SWAYLOCK_VIDEO"; exec swaybg -c "#000000"')
fi

# Keep the startup guard until the daemonization handshake completes, but do not
# pass it to the daemon. The daemon retains fd 9 until unlock.
swaylock-plugin "${args[@]}" 8>&-
