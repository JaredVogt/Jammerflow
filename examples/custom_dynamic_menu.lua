-- Example: Creating Custom Dynamic Menu Generators for Hammerflow
-- With the new modular architecture, generators are separate files

-- ===========================
-- MODULAR APPROACH (Preferred)
-- ===========================

-- To create a new generator, simply create a new file in DynamicMenu/generators/
-- For example: DynamicMenu/generators/myprojects.lua

-- The file should return a function that takes optional arguments and returns menu items:

--[[
-- File: DynamicMenu/generators/myprojects.lua
return function(args)
  return {
    {label = "Website", action = "code:~/projects/website"},
    {label = "Mobile App", action = "code:~/projects/mobile-app"},
    {label = "API Server", action = "code:~/projects/api"},
    {label = "Documentation", action = "code:~/projects/docs"}
  }
end
]]

-- Then use it in config.toml:
-- p = "dynamic:myprojects"

-- ===========================
-- GENERATOR EXAMPLES
-- ===========================

-- Example 1: Bookmarks Generator
-- File: DynamicMenu/generators/bookmarks.lua
--[[
return function(args)
  local bookmarks = {
    {label = "GitHub", action = "https://github.com"},
    {label = "Hacker News", action = "https://news.ycombinator.com"},
    {label = "Reddit", action = "https://reddit.com"},
    {label = "Linear", action = "https://linear.app"},
    {label = "Documentation", action = "https://docs.hammerspoon.org"}
  }
  
  -- Add icons if available
  for _, bookmark in ipairs(bookmarks) do
    bookmark.icon = "bookmark.png"  -- Use a generic bookmark icon
  end
  
  return bookmarks
end
]]

-- Example 2: System Control Generator with Rich Actions
-- File: DynamicMenu/generators/system.lua
--[[
return function(args)
  return {
    {
      label = "Lock Screen",
      icon = "lock.png",
      action = function() hs.caffeinate.lockScreen() end
    },
    {
      label = "Sleep",
      icon = "sleep.png",
      action = function() hs.caffeinate.systemSleep() end
    },
    {
      label = "Restart",
      icon = "restart.png",
      action = function() hs.caffeinate.restartSystem() end
    },
    {
      label = "Empty Trash",
      icon = "trash.png",
      action = "cmd:osascript -e 'tell application \"Finder\" to empty trash'"
    },
    {
      label = "Show Desktop",
      icon = "desktop.png",
      action = "shortcut:cmd f3"
    }
  }
end
]]

-- Example 3: Context-Aware Generator
-- File: DynamicMenu/generators/context.lua
--[[
return function(args)
  local app = hs.application.frontmostApplication()
  local appName = app:name()
  
  -- Different menus for different apps
  if appName == "Safari" or appName == "Google Chrome" then
    return {
      {label = "New Tab", action = "shortcut:cmd t"},
      {label = "New Window", action = "shortcut:cmd n"},
      {label = "Private/Incognito", action = "shortcut:cmd shift n"},
      {label = "Developer Tools", action = "shortcut:cmd alt i"},
      {label = "View Source", action = "shortcut:cmd alt u"}
    }
  elseif appName == "Visual Studio Code" or appName == "Cursor" then
    return {
      {label = "Command Palette", action = "shortcut:cmd shift p"},
      {label = "Quick Open", action = "shortcut:cmd p"},
      {label = "Terminal", action = "shortcut:ctrl `"},
      {label = "Explorer", action = "shortcut:cmd shift e"},
      {label = "Search", action = "shortcut:cmd shift f"}
    }
  else
    -- Default actions for other apps
    return {
      {label = "Copy", action = "shortcut:cmd c"},
      {label = "Paste", action = "shortcut:cmd v"},
      {label = "Undo", action = "shortcut:cmd z"},
      {label = "Select All", action = "shortcut:cmd a"}
    }
  end
end
]]

-- Example 4: Keyboard Maestro Integration
-- File: DynamicMenu/generators/kmacros.lua
--[[
return function(args)
  -- Example showing how to pass multiple variables to KM
  local projects = {
    {name = "Website", path = "~/projects/website", type = "node"},
    {name = "iOS App", path = "~/projects/ios-app", type = "swift"},
    {name = "Python API", path = "~/projects/api", type = "python"}
  }
  
  local items = {}
  for _, project in ipairs(projects) do
    table.insert(items, {
      label = project.name,
      icon = project.type .. ".png",
      action = {
        type = "km",
        macro = "OpenProject",
        variables = {
          ProjectName = project.name,
          ProjectPath = project.path,
          ProjectType = project.type
        }
      }
    })
  end
  
  return items
end
]]

-- Example 5: API Integration with Caching Control
-- File: DynamicMenu/generators/weather.lua
--[[
return function(args)
  local city = args or "San Francisco"
  
  -- Note: Real implementation would make actual API call
  local weather = {
    temp = "72°F",
    condition = "Sunny",
    humidity = "45%"
  }
  
  return {
    {label = city .. ": " .. weather.condition, action = function() end},
    {label = "Temperature: " .. weather.temp, action = function() end},
    {label = "Humidity: " .. weather.humidity, action = function() end},
    {label = "Refresh", action = "dynamic:weather(" .. city .. ")"}
  }
end
]]

-- ===========================
-- ADVANCED FEATURES
-- ===========================

-- 1. Generators can accept arguments:
--    "f" = "dynamic:files(~/Downloads)"
--    "w" = "dynamic:weather(London)"

-- 2. Generators can return rich action objects:
--    - Simple strings: "Safari" (launches app)
--    - URLs: "https://example.com"
--    - Functions: function() ... end
--    - Keyboard Maestro: {type = "km", macro = "...", variables = {...}}
--    - Shell commands: "cmd:echo hello"
--    - Shortcuts: "shortcut:cmd shift p"

-- 3. Special handling:
--    - The "cursor" generator skips caching for real-time data
--    - Icons can be specified per item
--    - Labels can include emojis and special characters

-- 4. File structure:
--    DynamicMenu/
--    ├── init.lua          # Core module (don't modify)
--    └── generators/       # Your generators go here
--        ├── cursor.lua    # Built-in
--        ├── files.lua     # Built-in
--        ├── git.lua       # Built-in
--        ├── docker.lua    # Built-in
--        ├── linear.lua    # Built-in
--        └── custom.lua    # Your custom generator

-- To use in config.toml:
-- m = "dynamic:myprojects"
-- b = "dynamic:bookmarks"
-- s = "dynamic:system"
-- c = "dynamic:context"
-- k = "dynamic:kmacros"