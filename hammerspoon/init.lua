-- prefix used to call all the hot keys
leader = { "cmd", "alt", "ctrl" }

hs.hotkey.bind(leader, "R", function()
  hs.reload()
end)

-- windows management config
require "windows"
