-- Finder window switcher generator
-- Lists all open Finder windows and allows direct navigation

return function(args)
  local items = {}
  local home = os.getenv("HOME")

  -- Static "Finder" item at top to just bring Finder to front
  table.insert(items, {
    key = "f",
    sortKey = "1_",
    label = "Finder",
    icon = "finder.png",
    action = "Finder"
  })

  -- Downloads shortcut
  table.insert(items, {
    key = "d",
    sortKey = "2_",
    label = "Downloads",
    icon = "finder.png",
    action = function()
      hs.execute("open ~/Downloads")
    end
  })

  local ok, result = hs.osascript.applescript([[
    tell application "System Events"
      set finderWindows to name of windows of application process "Finder"
    end tell
  ]])

  if ok and result then
    for _, windowName in ipairs(result) do
      local displayName = windowName:gsub(home, "~")
      table.insert(items, {
        label = displayName,
        icon = "finder.png",
        action = function()
          local script = string.format([[
            tell application "System Events"
              tell application process "Finder"
                set frontmost to true
                perform action "AXRaise" of window "%s"
              end tell
            end tell
          ]], windowName:gsub('"', '\\"'))
          hs.osascript.applescript(script)
        end
      })
    end
  end

  return items
end
