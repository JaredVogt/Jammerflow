-- Ghostty window switcher generator
-- Returns a list of Ghostty terminal windows that can be focused
-- Uses native Hammerspoon window API (no AppleScript)
-- Optional arg: path to a dev/custom Ghostty .app bundle
-- Example: dynamic:ghostty|/path/to/Ghostty.app

return function(args)
  local items = {}
  local devAppPath = (args and args ~= "") and args or nil

  local app = hs.application.get("Ghostty")
  if not app then
    -- If dev path provided, offer launcher even when Ghostty isn't running
    if devAppPath then
      table.insert(items, {
        key = "1_g",
        label = "Ghostty (Dev)",
        icon = "ghostty.png",
        action = function()
          os.execute('open "' .. devAppPath .. '"')
        end
      })
    end
    return items
  end

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

    if displayName:find("|") then
      displayName = displayName:match("^(.-)%s*|") or displayName
    end

    local targetWin = win
    table.insert(items, {
      label = displayName,
      icon = "ghostty.png",
      action = function()
        targetWin:application():activate()
        targetWin:raise()
        targetWin:focus()
      end
    })

    ::continue::
  end

  -- Dev launcher (only if path provided via args)
  if devAppPath then
    table.insert(items, {
      key = "1_g",
      label = "Ghostty (Dev)",
      icon = "ghostty.png",
      action = function()
        os.execute('open "' .. devAppPath .. '"')
      end
    })
  end

  return items
end
