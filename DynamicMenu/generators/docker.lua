-- Docker container management generator
-- Lists docker containers and provides actions
-- Usage: dynamic:docker

return function(args)
  local items = {}
  
  -- Check if docker is available
  local handle = io.popen('which docker 2>/dev/null')
  local dockerPath = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  
  if dockerPath == "" then
    return {{label = "⚠️ Docker not found", action = function() end}}
  end
  
  -- Get docker containers
  handle = io.popen('docker ps -a --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}" 2>/dev/null')
  if handle then
    local hasContainers = false
    for line in handle:lines() do
      hasContainers = true
      local id, name, status, image = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
      
      if id and name then
        local isRunning = status:match("^Up")
        local icon = isRunning and "🟢" or "🔴"
        local displayName = string.format("%s %s (%s)", icon, name, image)
        
        table.insert(items, {
          label = displayName,
          action = {
            type = "submenu",
            items = {
              {
                label = isRunning and "Stop" or "Start",
                action = function()
                  local cmd = isRunning and "stop" or "start"
                  os.execute('docker ' .. cmd .. ' ' .. id)
                  hs.alert((isRunning and "Stopped" or "Started") .. " container: " .. name)
                end
              },
              {
                label = "Restart",
                action = function()
                  os.execute('docker restart ' .. id)
                  hs.alert("Restarted container: " .. name)
                end
              },
              {
                label = "View Logs",
                action = function()
                  -- Open Terminal with docker logs
                  hs.execute('open -a Terminal')
                  hs.timer.doAfter(0.5, function()
                    hs.eventtap.keyStrokes('docker logs -f ' .. id)
                  end)
                end
              },
              {
                label = "Shell into Container",
                action = function()
                  -- Open Terminal with docker exec
                  hs.execute('open -a Terminal')
                  hs.timer.doAfter(0.5, function()
                    hs.eventtap.keyStrokes('docker exec -it ' .. id .. ' /bin/bash')
                  end)
                end
              },
              {
                label = "Remove Container",
                action = function()
                  os.execute('docker rm -f ' .. id)
                  hs.alert("Removed container: " .. name)
                end
              }
            }
          }
        })
      end
    end
    handle:close()
    
    if not hasContainers then
      table.insert(items, {label = "No containers found", action = function() end})
    end
  end
  
  -- Add docker compose options if docker-compose.yml exists
  local composeExists = os.execute('test -f docker-compose.yml || test -f docker-compose.yaml') == 0
  if composeExists then
    table.insert(items, {
      label = "📦 Docker Compose",
      action = {
        type = "submenu",
        items = {
          {
            label = "Up",
            action = function()
              os.execute('docker-compose up -d')
              hs.alert("Docker Compose: Started services")
            end
          },
          {
            label = "Down",
            action = function()
              os.execute('docker-compose down')
              hs.alert("Docker Compose: Stopped services")
            end
          },
          {
            label = "Restart",
            action = function()
              os.execute('docker-compose restart')
              hs.alert("Docker Compose: Restarted services")
            end
          }
        }
      }
    })
  end
  
  return items
end