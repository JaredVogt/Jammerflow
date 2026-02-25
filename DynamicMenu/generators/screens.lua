return function(args)
  local items = {}
  local allScreens = hs.screen.allScreens()

  if #allScreens < 2 then
    return {{ label = "Only one screen connected", action = function() end }}
  end

  local win = hs.window.focusedWindow()
  if not win then
    return {{ label = "No focused window", action = function() end }}
  end

  local currentScreen = win:screen()
  local currentFrame = currentScreen:frame()

  local function getPosition(targetScreen)
    local tf = targetScreen:frame()
    if tf.x + tf.w <= currentFrame.x then return "left"
    elseif tf.x >= currentFrame.x + currentFrame.w then return "right"
    elseif tf.y + tf.h <= currentFrame.y then return "above"
    elseif tf.y >= currentFrame.y + currentFrame.h then return "below"
    else return "" end
  end

  for _, screen in ipairs(allScreens) do
    if screen:id() ~= currentScreen:id() then
      local name = screen:name() or "Screen"
      local f = screen:frame()
      local pos = getPosition(screen)
      local label = string.format("%s (%dx%d)%s", name, f.w, f.h, pos ~= "" and " — " .. pos or "")

      table.insert(items, {
        label = label,
        action = function()
          local w = hs.window.focusedWindow()
          if w then
            w:moveToScreen(screen, false, true)
            hs.alert("→ " .. name, 1)
          end
        end
      })
    end
  end

  return items
end
