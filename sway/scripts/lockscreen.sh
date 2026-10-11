#!/usr/bin/env bash
set -euo pipefail

startup_timeout=${QUICKSHELL_LOCK_TIMEOUT:-10}
if [[ ! "$startup_timeout" =~ ^[1-9][0-9]*$ ]]; then
  echo "QUICKSHELL_LOCK_TIMEOUT must be a positive number of seconds." >&2
  exit 1
fi

# Serialize startup so duplicate requests wait for the first locker's readiness.
exec 8>"${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/sway-lockscreen-startup.lock"
if ! flock --timeout "$startup_timeout" 8; then
  echo "Timed out waiting for another lock startup; readiness is not confirmed." >&2
  exit 1
fi

# Keep this second lock held by the daemon until unlock.
exec 9>"$XDG_RUNTIME_DIR/sway-lockscreen.lock"
if ! flock --nonblock 9; then
  # Guard occupancy is not proof of locking: the owner may be cleaning up after
  # a failed startup or an unlock. Query the live locker without exposing unlock.
  if secure=$(timeout --kill-after=1 "$startup_timeout" \
    qs -c lockscreen ipc call lock isSecure 8>&- 9>&- 2>/dev/null) \
    && [[ "$secure" == true ]]; then
    exit 0
  fi
  echo "A lock guard is held, but the session's secure state could not be confirmed." >&2
  exit 1
fi

# Quickshell and its PAM service are required; there is no fallback locker.
if command -v qs >/dev/null && [[ -f /etc/pam.d/quickshell-lockscreen ]]; then
  ready_dir=$(mktemp -d "$XDG_RUNTIME_DIR/quickshell-lock.XXXXXX")
  export QUICKSHELL_LOCK_READY="$ready_dir/ready"

  # Retain both guards until readiness, then only fd 9 until unlock. Qt receives
  # neither guard. If the caller times out, duplicates cannot claim success.
  (
    trap 'rm -rf -- "$ready_dir"' EXIT
    qs -c lockscreen 8>&- 9>&- &
    locker=$!
    while [[ ! -f "$QUICKSHELL_LOCK_READY" ]]; do
      kill -0 "$locker" 2>/dev/null || break
      sleep 0.05
    done
    if [[ -f "$QUICKSHELL_LOCK_READY" ]]; then
      exec 8>&-
    fi
    # Without readiness, retain fd 8 through wait, cleanup, and guard release.
    wait "$locker"
  ) </dev/null >"$XDG_RUNTIME_DIR/quickshell-lockscreen.log" 2>&1 &
  supervisor=$!
  deadline=$((SECONDS + startup_timeout))

  while [[ ! -f "$QUICKSHELL_LOCK_READY" ]]; do
    if ! kill -0 "$supervisor" 2>/dev/null; then
      wait "$supervisor" || true
      # A crashed session lock may still own the screen: never claim readiness.
      echo "Quickshell lock failed; see $XDG_RUNTIME_DIR/quickshell-lockscreen.log" >&2
      exit 1
    fi
    if ((SECONDS >= deadline)); then
      echo "Quickshell lock readiness timed out; see $XDG_RUNTIME_DIR/quickshell-lockscreen.log" >&2
      # It may already own the session lock. Do not kill it, launch a competing
      # locker, or return success. The supervisor keeps the startup guard.
      exit 1
    fi
    sleep 0.05
  done
  [[ ! -f "$QUICKSHELL_LOCK_READY" ]] || exit 0
fi

echo "Quickshell and its PAM service are required to lock the session." >&2
exit 1
