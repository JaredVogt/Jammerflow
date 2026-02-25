-- Cursor window switcher generator
-- Returns a list of Cursor editor windows that can be focused
-- Uses native Hammerspoon window API (no AppleScript)

return function(args)
  local items = {}

  local app = hs.application.get("Cursor")
  if not app then return items end

  for _, win in ipairs(app:allWindows()) do
    local windowName = win:title() or ""
    if windowName == "" then goto continue end

    local displayName = windowName
    local separator = " — "
    local separatorPos = windowName:find(separator, 1, true)
    if separatorPos then
      local tab = windowName:sub(1, separatorPos - 1)
      local folder = windowName:sub(separatorPos + #separator)
      displayName = folder .. separator .. tab
    end

    local targetWin = win
    table.insert(items, {
      label = displayName,
      icon = "cursor.png",
      action = function()
        targetWin:application():activate()
        targetWin:raise()
        targetWin:focus()
      end
    })

    ::continue::
  end

  return items
end
