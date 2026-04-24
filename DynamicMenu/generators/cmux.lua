-- cmux workspace switcher generator
-- Lists cmux workspaces and switches to them on selection
-- Usage: dynamic:cmux

local CMUX = "/Applications/cmux.app/Contents/Resources/bin/cmux"

return function(args)
  local items = {}

  -- Hardcoded KM trigger for Claude workspace
  table.insert(items, {
    label = "Claude - needs input",
    key = "1_j",
    action = function()
      local kmCmd = string.format('osascript -e \'tell application "Keyboard Maestro Engine" to do script "%s"\'', "Launch CMUX - latest change")
      os.execute(kmCmd .. " &")
    end
  })

  local handle = io.popen(CMUX .. " list-workspaces 2>/dev/null")
  if not handle then
    return {{label = "cmux not available", action = function() end}}
  end

  for line in handle:lines() do
    if line == "" then goto continue end

    -- Parse: optional "*" (selected), "workspace:N", then the title
    -- Example lines:
    --   workspace:1  Tidbits
    -- * workspace:6  ⠂ Claude Code  [selected]
    --   workspace:2  telemetry | ✳ Claude Code
    local selected = line:match("^%*") ~= nil
    local ref = line:match("(workspace:%d+)")
    -- Title is everything after "workspace:N  "
    local title = line:match("workspace:%d+%s+(.+)$")

    if not ref or not title then goto continue end

    -- Strip [selected] suffix
    title = title:gsub("%s*%[selected%]%s*$", "")

    -- Show only the part before "|" as the display name
    local displayName = title:match("^(.-)%s*|") or title
    displayName = displayName:gsub("^%s+", ""):gsub("%s+$", "")

    -- Mark the currently selected workspace
    if selected then
      displayName = "● " .. displayName
    end

    local capturedRef = ref
    table.insert(items, {
      label = displayName,
      action = function()
        hs.execute(CMUX .. " select-workspace --workspace " .. capturedRef, true)
        -- Activate the cmux app
        local app = hs.application.get("cmux")
        if app then app:activate() end
      end
    })

    ::continue::
  end
  handle:close()

  if #items == 0 then
    return {{label = "No cmux workspaces found", action = function() end}}
  end

  return items
end
