-- Git branch switcher generator
-- Lists git branches in the current repository
-- Usage: dynamic:git

return function(args)
  local items = {}
  
  -- Get current directory (or use provided path)
  local path = args or hs.window.focusedWindow():application():path()
  if not path then
    -- Try to get from Terminal/iTerm if that's the focused app
    local app = hs.application.frontmostApplication()
    local appName = app:name()
    
    if appName == "Terminal" or appName == "iTerm2" then
      -- Get current directory from terminal
      local ok, pwd = hs.osascript.applescript([[
        tell application "]] .. appName .. [["
          tell current session of current window
            return (do shell script "pwd")
          end tell
        end tell
      ]])
      if ok then path = pwd end
    end
  end
  
  if not path then
    return {{label = "⚠️ No git repository found", action = function() end}}
  end
  
  -- Check if it's a git repository
  local handle = io.popen('cd "' .. path .. '" && git rev-parse --git-dir 2>/dev/null')
  local gitDir = handle:read("*a")
  handle:close()
  
  if gitDir == "" then
    return {{label = "⚠️ Not a git repository", action = function() end}}
  end
  
  -- Get current branch
  handle = io.popen('cd "' .. path .. '" && git branch --show-current 2>/dev/null')
  local currentBranch = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  
  -- Get all branches
  handle = io.popen('cd "' .. path .. '" && git branch -a 2>/dev/null')
  if handle then
    for branch in handle:lines() do
      local branchName = branch:match("^%s*%*?%s*(.+)$")
      if branchName and not branchName:match("HEAD") then
        local isCurrent = branch:match("^%s*%*")
        local isRemote = branchName:match("^remotes/")
        
        local displayName = branchName
        if isRemote then
          displayName = "☁️ " .. branchName:gsub("^remotes/origin/", "")
        elseif isCurrent then
          displayName = "✓ " .. branchName
        end
        
        table.insert(items, {
          label = displayName,
          action = function()
            if not isRemote then
              -- Checkout local branch
              os.execute('cd "' .. path .. '" && git checkout "' .. branchName .. '"')
              hs.alert("Switched to branch: " .. branchName)
            else
              -- Checkout remote branch
              local localName = branchName:gsub("^remotes/origin/", "")
              os.execute('cd "' .. path .. '" && git checkout -b "' .. localName .. '" "' .. branchName .. '"')
              hs.alert("Checked out remote branch: " .. localName)
            end
          end
        })
      end
    end
    handle:close()
  end
  
  -- Add option to create new branch
  table.insert(items, {
    label = "➕ Create new branch",
    action = function()
      -- This would ideally prompt for a branch name
      hs.alert("Feature coming soon: Create new branch")
    end
  })
  
  return items
end