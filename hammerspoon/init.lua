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
  -- nix-launched Emacs registers only as name=emacs (no bundle ID or path),
  -- and hs.application.find can return an hs.window instead, so scan by name.
  local app
  for _, running in ipairs(hs.application.runningApplications()) do
    if running:name() == "emacs" then
      app = running
      break
    end
  end

  if app then
    app:activate()
  else
    -- we need to execute Emacs this way to be able to use mise
    -- properly, otherwise we can't execute stuff like, mix, elixir
    -- and so on
    hs.task.new("/bin/zsh", nil, { "-l", "-c", "emacs > /dev/null 2>&1 & disown" }):start()
  end
end)

hs.hotkey.bind("alt", "4", function()
  hs.application.open "Spotify.app"
end)
