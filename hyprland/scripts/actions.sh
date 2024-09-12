options="Screenshot region|Screenshot window|Screenshot screen"

case $(echo "$options" | rofi -sep '|' -dmenu | tr '[:upper:]' '[:lower:]' | tr ' ' '-') in
"screenshot-region")
  hyprshot -m region --clipboard && wl-paste | swappy -f -
  ;;
"screenshot-window")
  hyprshot -m window --clipboard && wl-paste | swappy -f -
  ;;
"screenshot-screen")
  # we use grim for fullscreen screenshot because for some reason hyprshot takes too long to complete
  grim - | swappy -f -
  ;;
esac
