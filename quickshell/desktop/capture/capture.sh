#!/usr/bin/env bash
set -euo pipefail

kind=${1:-}
area=${2:-}
case "$kind:$area" in
screenshot:screen | screenshot:region | record:screen | record:region) ;;
*) exit 2 ;;
esac

recorder_pid=
selection_errors=
state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell-recording.pid"
refresh_waybar() {
  pkill -RTMIN+8 -u "$(id -u)" -x waybar 2>/dev/null || true
}
# Bash reaps exited background jobs while polling; never wait on a live recorder.
wait_for_recorder() {
  local ticks=$1
  while kill -0 "$recorder_pid" 2>/dev/null; do
    if ((ticks-- == 0)); then
      return 1
    fi
    sleep 0.1
  done
}
stop_recorder() {
  local status=0
  if kill -0 "$recorder_pid" 2>/dev/null; then
    kill -INT "$recorder_pid" 2>/dev/null || true
    if ! wait_for_recorder 50; then
      printf 'Recorder did not finalize within 5s; sending SIGTERM.\n' >&2
      status=1
      kill -TERM "$recorder_pid" 2>/dev/null || true
      if ! wait_for_recorder 20; then
        printf 'Recorder did not exit within 2s; sending SIGKILL.\n' >&2
        kill -KILL "$recorder_pid" 2>/dev/null || true
      fi
    fi
  fi
  wait "$recorder_pid" || status=$?
  recorder_pid=
  return "$status"
}
cleanup() {
  trap '' INT TERM HUP
  if [[ -n "$selection_errors" ]]; then
    rm -f "$selection_errors"
  fi
  if [[ -n "$recorder_pid" ]]; then
    stop_recorder || true
  fi
  if [[ -f "$state_file" && "$(<"$state_file")" == "$$" ]]; then
    rm -f "$state_file"
    refresh_waybar
  fi
}
trap cleanup EXIT
# Bash's `read -t` arms a longjmp timeout: once it expires, check_signals()
# jumps back into read, abandoning whatever a signal trap handler was still
# doing. Handlers must stay trivial, so signals only set a flag and the read
# loop below finalizes on the main flow, outside read's dynamic scope.
signal_stop=
trap 'signal_stop=1' INT TERM HUP
trap 'notify-send -a Capture -u critical "Capture failed" "Check the capture shell logs." || true' ERR

# Screen means the currently focused Sway output, not the entire desktop.
if [[ "$area" == region ]]; then
  # Keep the recording control pipe separate from slurp's rectangle input.
  selection_errors=$(mktemp)
  status=0
  geometry=$(slurp </dev/null 2>"$selection_errors") || status=$?
  if [[ "$status" -ne 0 ]]; then
    diagnostic=$(<"$selection_errors")
    # slurp uses exit status 1 for both cancellation and setup failures.
    if [[ "$status" -eq 1 && "$diagnostic" == "selection cancelled" ]]; then
      exit 0
    fi
    printf '%s\n' "$diagnostic" >&2
    notify-send -a Capture -u critical "Region selection failed" "${diagnostic:-slurp exited with status $status.}" || true
    exit "$status"
  fi
  if [[ -z "$geometry" ]]; then
    notify-send -a Capture -u critical "Region selection failed" "slurp returned an empty selection." || true
    exit 1
  fi
  rm -f "$selection_errors"
  selection_errors=
  capture_args=(-g "$geometry")
else
  output=$(swaymsg -t get_outputs | jq -r 'first(.[] | select(.focused)) | .name // empty')
  [[ -n "$output" ]]
  capture_args=(-o "$output")
fi

if [[ "$kind" == screenshot ]]; then
  directory="$HOME/Pictures/Screenshots"
  mkdir -p "$directory"
  file="$directory/screenshot-$(date +%Y-%m-%d_%H-%M-%S-%N).png"
  grim "${capture_args[@]}" "$file"
  wl-copy --type image/png <"$file"
  bash "$(dirname -- "${BASH_SOURCE[0]}")/notify-capture.sh" screenshot "$file" </dev/null >/dev/null 2>&1 &
  exit 0
fi

audio=${3:-silent}
audio_source=${4:-default}
case "$audio" in
silent) recorder_args=("${capture_args[@]}") ;;
audio)
  recorder_args=("${capture_args[@]}")
  if [[ "$audio_source" == default ]]; then
    recorder_args+=(--audio)
  elif [[ -n "$audio_source" && "$audio_source" != *$'\n'* ]]; then
    recorder_args+=("--audio=$audio_source")
  else
    exit 2
  fi
  ;;
*) exit 2 ;;
esac

directory="$HOME/Videos/Recordings"
mkdir -p "$directory"
file="$directory/recording-$(date +%Y-%m-%d_%H-%M-%S-%N).mp4"
wf-recorder "${recorder_args[@]}" -f "$file" &
recorder_pid=$!
# Report recording only once the process has survived initial startup.
sleep 0.3
kill -0 "$recorder_pid"
printf '%s\n' "$$" >"$state_file"
refresh_waybar
if [[ "$area" == region ]]; then
  printf 'REGION %s\n' "$geometry"
fi
printf 'RECORDING\n'
while kill -0 "$recorder_pid" 2>/dev/null; do
  [[ -n "$signal_stop" ]] && break
  if IFS= read -r -t 0.2 request; then
    [[ "$request" == stop ]] && break
  elif [[ $? -le 128 ]]; then
    # The UI closed its input: finalize instead of leaving an orphan recording.
    break
  fi
done
if [[ -n "$signal_stop" ]]; then
  stop_recorder || true
  exit 130
fi
stop_recorder
bash "$(dirname -- "${BASH_SOURCE[0]}")/notify-capture.sh" record "$file" </dev/null >/dev/null 2>&1 &
