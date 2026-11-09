#!/usr/bin/env bash
set -euo pipefail

pane="${1:?Missing source pane}"
selection=$(tmux save-buffer -)

if [[ -z "$selection" ]]; then
  tmux display-message 'No text selected'
  exit 0
fi

action=$(printf '%s\n' 'Open URL' 'Execute in side panel' |
  fzf --reverse --color=bg:-1 --prompt='selection> ') || exit 0

case "$action" in
'Open URL')
  if [[ ! "$selection" =~ ^https?://[^[:space:]]+$ ]]; then
    tmux display-message 'Select a single http:// or https:// URL'
    exit 0
  fi
  if [[ "$(uname -s)" == Darwin ]]; then
    open "$selection"
  else
    xdg-open "$selection"
  fi
  ;;
'Execute in side panel')
  shell=$(tmux show-options -gv default-shell)
  socket=$(tmux display-message -p '#{socket_path}')
  # Let the server own execution independently of the popup's lifetime.
  command=
  # shellcheck disable=SC2016 # Arguments expand in the new pane's shell.
  for argument in tmux -S "$socket" split-window -h -t "$pane" -c "$PWD" \
    "$shell" -ic 'eval "$1"; exec "$0" -i' "$shell" "$selection"; do
    command+="'${argument//\'/\'\\\'\'}' "
  done
  tmux run-shell -b -t "$pane" "$command"
  ;;
esac
