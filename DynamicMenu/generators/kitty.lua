-- Kitty window switcher generator
-- Returns a list of Kitty terminal windows that can be focused
-- Uses native Hammerspoon window API (no AppleScript)

return function(args)
  local items = {}

  local app = hs.application.get("kitty")
  if not app then return items end

  for _, win in ipairs(app:allWindows()) do
    local windowName = win:title() or ""
    if windowName == "" then goto continue end

    local displayName = windowName
    if windowName:match("^/") then
      displayName = windowName:match("([^/]+)/?$") or windowName
    elseif windowName:match(" in /") then
      local cmd, path = windowName:match("^(.+) in (/.*)")
      if cmd and path then
        local dir = path:match("([^/]+)/?$") or path
        displayName = cmd .. " → " .. dir
      end
    end

    local targetWin = win
    table.insert(items, {
      label = displayName,
      icon = "kitty.png",
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
