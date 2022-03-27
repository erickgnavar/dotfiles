-- coordinates X from left to right and Y from top to bottom

-- remove window movement animation
hs.window.animationDuration = 0

-- put to left
hs.hotkey.bind(leader, "H", function()
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x
  frame.y = max.y
  frame.w = max.w / 2
  frame.h = max.h
  window:setFrame(frame)
end)

-- put to right
hs.hotkey.bind(leader, "L", function()
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x + (max.w / 2)
  frame.y = max.y
  frame.w = max.w / 2
  frame.h = max.h
  window:setFrame(frame)
end)

-- put to top
hs.hotkey.bind(leader, "K", function()
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x
  frame.y = max.y - (max.h / 2)
  frame.w = max.w
  frame.h = max.h / 2
  window:setFrame(frame)
end)

-- put to bottom
hs.hotkey.bind(leader, "J", function()
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x
  frame.y = max.y + (max.h / 2)
  frame.w = max.w
  frame.h = max.h / 2
  window:setFrame(frame)
end)

-- maximize frame
hs.hotkey.bind(leader, "RETURN", function()
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x
  frame.y = max.y
  frame.w = max.w
  frame.h = max.h
  window:setFrame(frame)
end)

-- center frame
hs.hotkey.bind(leader, "\\", function()
  -- base grid layout will be 6 x 5 and center frame should be 4 x 3
  local window = hs.window.focusedWindow()
  local frame = window:frame()
  local screen = window:screen()
  local max = screen:frame()

  frame.x = max.x + (max.w / 6) * 1
  frame.y = max.y + (max.h / 5) * 1
  frame.w = (max.w / 6) * 4
  frame.h = (max.h / 5) * 3
  window:setFrame(frame)
end)
