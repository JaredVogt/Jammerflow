-- File browser generator
-- Lists files and directories in a given path
-- Usage: dynamic:files(~/Downloads)

return function(args)
  local path = args or os.getenv("HOME")
  
  -- Expand tilde to home directory
  if path:sub(1, 1) == "~" then
    path = os.getenv("HOME") .. path:sub(2)
  end
  
  local items = {}
  
  -- Get list of files and directories
  local handle = io.popen('ls -1ap "' .. path .. '" 2>/dev/null | head -50')
  if handle then
    for file in handle:lines() do
      if file ~= "./" and file ~= "../" then
        local isDir = file:match("/$")
        local displayName = isDir and file:sub(1, -2) or file
        local fullPath = path .. "/" .. displayName
        
        table.insert(items, {
          label = displayName,
          icon = isDir and "folder.png" or "file.png",
          action = isDir and ("dynamic:files(" .. fullPath .. ")") or ("code:" .. fullPath)
        })
      end
    end
    handle:close()
  end
  
  -- Add parent directory option if not at root
  if path ~= "/" then
    table.insert(items, 1, {
      label = "↩ Parent Directory",
      icon = "folder.png",
      action = "dynamic:files(" .. path:match("(.*/)[^/]+/?$") .. ")"
    })
  end
  
  return items
end