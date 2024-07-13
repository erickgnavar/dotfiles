if [ "$(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2}')" = "1.000000" ]; then
  hyprctl keyword cursor:zoom_factor 1.8
else
  hyprctl keyword cursor:zoom_factor 1.0
fi
