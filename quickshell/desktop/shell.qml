//@ pragma IconTheme Papirus-Dark

// One Quickshell process hosts the dock, capture toolbar, app switcher, and
// wallpaper picker, so a single Qt/QML engine serves them all instead of one
// engine per process. Components keep their original directories so relative
// script paths (capture.sh, scan.py, …) continue to resolve.
import Quickshell

import "./dock"
import "./capture"
import "./app_switcher"
import "./wallpaper_picker"
import "./color_picker"

ShellRoot {
    Dock { }
    Capture { }
    AppSwitcher { }
    WallpaperPicker { }
    ColorPicker { }
}
