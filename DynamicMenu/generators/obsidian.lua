-- Generic Obsidian folder browser with pagination
-- Usage: dynamic:obsidian|vault,path,limit,offset
-- Vault root defaults to $HOME/Obsidian/<vault>/
-- Example: dynamic:obsidian|MyVault,Notes/subfolder,10
-- Example with offset: dynamic:obsidian|MyVault,Daily,15,30

return function(args)
  local items = {}

  -- Parse args: vault,path,limit,offset
  local vault, path, limit, offset = "Obsidian", "", nil, 0
  if args then
    local parts = {}
    for part in args:gmatch("[^,]+") do
      table.insert(parts, part)
    end
    vault = (parts[1] and parts[1] ~= "") and parts[1] or "Obsidian"
    path = parts[2] or ""
    limit = tonumber(parts[3])
    offset = tonumber(parts[4]) or 0
  end

  local vaultRoot = os.getenv("HOME") .. "/Obsidian/" .. vault
  local fullPath = vaultRoot .. "/" .. path

  -- Get files with modification times for sorting
  local files = {}
  local iter, dir = hs.fs.dir(fullPath)
  if iter then
    for file in iter, dir do
      if file:match("%.md$") then
        local filePath = fullPath .. "/" .. file
        local attrs = hs.fs.attributes(filePath)
        table.insert(files, {
          name = file,
          mtime = attrs and attrs.modification or 0
        })
      end
    end
  end

  -- Sort by most recent
  table.sort(files, function(a, b) return a.mtime > b.mtime end)

  -- Calculate how many nav items we'll have
  local totalFiles = #files
  local willHaveNext = limit and limit > 0 and totalFiles > (offset + limit)
  local willHavePrev = offset > 0
  local navCount = (willHaveNext and 1 or 0) + (willHavePrev and 1 or 0)

  -- Reduce file limit to make room for nav items (maintain single column)
  local fileLimit = limit
  if limit and limit > 0 and navCount > 0 then
    fileLimit = limit - navCount
  end

  -- Apply offset and adjusted limit
  local hasMore = false
  if fileLimit and fileLimit > 0 then
    hasMore = totalFiles > (offset + fileLimit)
    local chunk = {}
    for i = offset + 1, math.min(offset + fileLimit, totalFiles) do
      table.insert(chunk, files[i])
    end
    files = chunk
  end

  -- Build menu items as array first
  local fileItems = {}
  for _, f in ipairs(files) do
    local basename = f.name:match("(.+)%.md$")
    local label = basename:gsub("^%d+[a-z]?%-", ""):gsub("%-", " ")
    local vaultPath = path:gsub(" ", "%%20") .. "/" .. basename
    local action = "obsidian://open?vault=" .. vault .. "&file=" .. vaultPath

    table.insert(fileItems, {
      label = label,
      action = action,
      icon = "obsidian.png"
    })
  end

  -- Convert to key-value with a-z keys (sortKey ensures proper ordering)
  local chars = "abcdefghijklmnopqrstuvwxyz1234567890"
  for i, item in ipairs(fileItems) do
    if i <= #chars then
      local key = chars:sub(i, i)
      item.sortKey = "1" .. key  -- Files sort in middle (after "0", before "~")
      items[key] = item
    end
  end

  -- Add navigation items with sortKey for positioning
  if limit and limit > 0 then
    -- "Next" at TOP (sortKey "0" sorts first)
    if hasMore then
      local nextOffset = offset + fileLimit
      local nextAction = "dynamic:obsidian|" .. vault .. "," .. path .. "," .. limit .. "," .. nextOffset
      items["down"] = {
        label = "Next ↓",
        action = nextAction,
        icon = "obsidian.png",
        sortKey = "0"  -- Sorts first (top of menu)
      }
    end

    -- "Prev" at BOTTOM (sortKey "~" sorts last)
    if offset > 0 then
      local prevOffset = math.max(0, offset - fileLimit)
      local prevAction = "dynamic:obsidian|" .. vault .. "," .. path .. "," .. limit .. "," .. prevOffset
      items["up"] = {
        label = "↑ Prev",
        action = prevAction,
        icon = "obsidian.png",
        sortKey = "~"  -- Sorts last (bottom of menu)
      }
    end
  end

  return items
end
