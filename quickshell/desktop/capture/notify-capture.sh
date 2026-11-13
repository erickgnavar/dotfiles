#!/usr/bin/env bash
set -euo pipefail

kind=${1:-}
file=${2:-}
[[ -f "$file" ]] || exit 2
case "$kind" in
screenshot)
  title="Screenshot saved and copied"
  actions=(--action=edit="Edit in Swappy")
  ;;
record)
  title="Recording saved"
  actions=(--action=trim="Trim")
  ;;
*) exit 2 ;;
esac

# notify-send waits for an action or dismissal; keep this outside the capture
# process so recording controls and cleanup never wait for user interaction.
action=$(notify-send -a Capture --wait --action=open=Open \
  "${actions[@]}" --action=reveal="Reveal in folder" \
  --action=share="Share via LocalSend" "$title" "$file") || exit 0
case "$action" in
open) xdg-open "$file" ;;
edit)
  [[ "$kind" == screenshot ]] || exit 2
  swappy -f "$file" -o "$file"
  ;;
trim)
  [[ "$kind" == record ]] || exit 2
  qs -c desktop ipc call trimmer open "$file"
  ;;
reveal) nautilus --select "$file" ;;
share) localsend_app "$file" ;;
*) exit 0 ;;
esac
