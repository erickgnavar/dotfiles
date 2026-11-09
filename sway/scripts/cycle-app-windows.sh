#!/usr/bin/env bash
set -euo pipefail

# Keep tree order stable so repeated presses cycle rather than toggle by recency.
target=$(swaymsg -t get_tree -r | jq -r '
  def windows($workspace):
    (if .type == "workspace" then .name else $workspace end) as $ws
    | if .type == "con" and (.app_id or .window_properties.class) then
        {id, focused, app: (.app_id // .window_properties.class),
         hidden: ($ws == "__i3_scratch")}
      else
        ((.nodes // []) + (.floating_nodes // []))[] | windows($ws)
      end;
  [windows(null)] as $windows
  | ($windows | map(select(.focused)) | first) as $focused
  | if $focused == null then empty else
      [$windows[] | select(.app == $focused.app)] as $matching
      | if ($matching | length) < 2 then empty else
          ($matching | map(.id) | index($focused.id)) as $index
          | $matching[($index + 1) % ($matching | length)]
          | "[con_id=\(.id)] " +
            (if .hidden then "scratchpad show; [con_id=\(.id)] " else "" end) + "focus"
        end
    end
')

[[ -n $target ]] || exit 0
swaymsg "$target" >/dev/null
