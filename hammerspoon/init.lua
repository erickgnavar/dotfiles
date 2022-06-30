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
