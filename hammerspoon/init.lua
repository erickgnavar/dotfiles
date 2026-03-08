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
  local app = hs.application.find "Emacs"

  if app then
    app:activate()
  else
    -- we need to execute Emacs this way to be able to use mise
    -- properly, otherwise we can't execute stuff like, mix, elixir
    -- and so on
    hs.task.new("/bin/zsh", nil, { "-l", "-c", "emacs > /dev/null 2>&1 & disown" }):start()

    -- Poll until Emacs is available, then focus it
    hs.timer.doUntil(
      function()
        local emacs = hs.application.find "Emacs"
        if emacs then
          emacs:activate()
          return true
        end
        return false
      end,
      0.1 -- check every 500ms
    )
  end
end)

hs.hotkey.bind("alt", "4", function()
  hs.application.open "Spotify.app"
end)
