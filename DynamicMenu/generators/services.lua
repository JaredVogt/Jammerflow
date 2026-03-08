-- Services generator: reads ~/.config/dev-ports/registry.yaml
-- Shows dev server status (running/stopped) and live URLs
-- Usage: dynamic:services

return function(args)
  local items = {}
  local registryPath = os.getenv("HOME") .. "/.config/dev-ports/registry.yaml"

  -- Read the registry file
  local file = io.open(registryPath, "r")
  if not file then
    return {{label = "Registry not found: " .. registryPath, action = function() end}}
  end
  local content = file:read("*a")
  file:close()

  -- Parse YAML line-by-line into services table
  local services = {}
  local currentService = nil
  local inPorts = false
  local inPortType = false
  local currentPortType = nil

  for line in content:gmatch("[^\r\n]+") do
    -- Top-level service key (no leading whitespace, ends with colon)
    local topKey = line:match("^(%S+):%s*$")
    if topKey then
      currentService = {id = topKey, ports = {}}
      table.insert(services, currentService)
      inPorts = false
      inPortType = false
    elseif currentService then
      -- display_name
      local displayName = line:match("^%s+display_name:%s*(.+)%s*$")
      if displayName then
        currentService.display_name = displayName
      end

      -- live_url
      local liveUrl = line:match("^%s+live_url:%s*(.+)%s*$")
      if liveUrl then
        currentService.live_url = liveUrl
      end

      -- ports: section
      if line:match("^%s+ports:%s*$") then
        inPorts = true
        inPortType = false
      elseif inPorts then
        -- Port type line like "    dev:" or "    api:" or "    ws:"
        local portType = line:match("^%s%s%s%s(%S+):%s*$")
        if portType then
          currentPortType = portType
          inPortType = true
        elseif inPortType then
          -- port: 3515
          local port = line:match("^%s+port:%s*(%d+)")
          if port and currentPortType then
            currentService.ports[currentPortType] = tonumber(port)
          end
        end
      end

      -- Non-indented or less-indented line that isn't ports-related resets ports parsing
      if not line:match("^%s") then
        inPorts = false
        inPortType = false
      end
    end
  end

  -- Get all listening ports in one batch call
  local listeningPorts = {}
  local handle = io.popen("lsof -i TCP -sTCP:LISTEN -P -n 2>/dev/null")
  if handle then
    for line in handle:lines() do
      local port = line:match(":(%d+)%s+%(LISTEN%)")
      if port then
        listeningPorts[tonumber(port)] = true
      end
    end
    handle:close()
  end

  -- Sort services alphabetically by display name
  table.sort(services, function(a, b)
    local nameA = (a.display_name or a.id):lower()
    local nameB = (b.display_name or b.id):lower()
    return nameA < nameB
  end)

  -- Build menu items
  for _, svc in ipairs(services) do
    local name = svc.display_name or svc.id
    local devPort = svc.ports.dev

    if devPort then
      local isRunning = listeningPorts[devPort] == true
      local icon = isRunning and "\u{1F7E2}" or "\u{1F534}"
      local devLabel = string.format("%s %s (:%d)", icon, name, devPort)
      local devUrl = "tab:chrome:http://localhost:" .. devPort .. "/"

      table.insert(items, {
        label = devLabel,
        action = devUrl
      })
    end

    if svc.live_url then
      local liveLabel = string.format("\u{1F310} %s - Live", name)
      table.insert(items, {
        label = liveLabel,
        action = "tab:chrome:" .. svc.live_url
      })
    end
  end

  if #items == 0 then
    return {{label = "No services found", action = function() end}}
  end

  return items
end
