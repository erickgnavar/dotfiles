-- prefix used to call all the hot keys
leader = { "cmd", "alt", "ctrl" }

hs.hotkey.bind(leader, "R", function()
  hs.reload()
end)

hs.hotkey.bind(leader, "T", function()
  hs.application.open "Terminal.app"
end)

-- windows management config
require "windows"

-- shortcuts to open more common application
hs.hotkey.bind("alt", "1", function()
  hs.application.open "Alacritty.app"
end)

hs.hotkey.bind("alt", "2", function()
  local defaultBrowser = hs.urlevent.getDefaultHandler "http"
  hs.application.launchOrFocusByBundleID(defaultBrowser)
end)

hs.hotkey.bind("alt", "3", function()
  hs.application.open "Emacs.app"
end)
