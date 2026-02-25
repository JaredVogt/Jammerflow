-- Linear issues generator
-- Fetches Linear issues assigned to you
-- Usage: dynamic:linear

return function(args)
  local items = {}
  
  -- This is a mock implementation since it requires Linear API setup
  -- In a real implementation, you would:
  -- 1. Set up Linear API key in a config file
  -- 2. Make HTTP requests to Linear's GraphQL API
  -- 3. Parse the response and create menu items
  
  -- Mock data for demonstration
  local mockIssues = {
    {
      title = "Fix navigation bug in mobile app",
      identifier = "MOB-123",
      status = "In Progress",
      priority = "High",
      url = "https://linear.app/team/issue/MOB-123"
    },
    {
      title = "Implement dark mode for dashboard",
      identifier = "WEB-456",
      status = "Todo",
      priority = "Medium",
      url = "https://linear.app/team/issue/WEB-456"
    },
    {
      title = "Update API documentation",
      identifier = "DOC-789",
      status = "In Review",
      priority = "Low",
      url = "https://linear.app/team/issue/DOC-789"
    }
  }
  
  -- Priority icons
  local priorityIcons = {
    High = "🔴",
    Medium = "🟡",
    Low = "🟢"
  }
  
  -- Status icons
  local statusIcons = {
    Todo = "📝",
    ["In Progress"] = "🔄",
    ["In Review"] = "👀",
    Done = "✅"
  }
  
  for _, issue in ipairs(mockIssues) do
    local priorityIcon = priorityIcons[issue.priority] or "⚪"
    local statusIcon = statusIcons[issue.status] or "📋"
    
    table.insert(items, {
      label = string.format("%s %s %s - %s", 
        priorityIcon, statusIcon, issue.identifier, issue.title),
      action = function()
        -- Open issue in browser
        os.execute('open "' .. issue.url .. '"')
      end
    })
  end
  
  -- Add option to create new issue
  table.insert(items, {
    label = "➕ Create new issue",
    action = function()
      os.execute('open "https://linear.app/team/new-issue"')
    end
  })
  
  -- Add note about API setup
  table.insert(items, {
    label = "ℹ️ Note: Using mock data (setup Linear API for real data)",
    action = function()
      hs.alert("To use real Linear data, configure your API key")
    end
  })
  
  return items
end

--[[ 
Real implementation would look like:

return function(args)
  local items = {}
  
  -- Load API key from config
  local apiKey = hs.settings.get("linearApiKey")
  if not apiKey then
    return {{label = "⚠️ Linear API key not configured", action = function() end}}
  end
  
  -- GraphQL query for assigned issues
  local query = [[
    query {
      issues(filter: { assignee: { isMe: { eq: true } } }) {
        nodes {
          identifier
          title
          state { name }
          priority
          url
        }
      }
    }
  ]]
  
  -- Make API request
  local headers = {
    ["Authorization"] = apiKey,
    ["Content-Type"] = "application/json"
  }
  
  local body = hs.json.encode({ query = query })
  local status, response = hs.http.post("https://api.linear.app/graphql", body, headers)
  
  if status == 200 then
    local data = hs.json.decode(response)
    for _, issue in ipairs(data.data.issues.nodes) do
      table.insert(items, {
        label = issue.identifier .. " - " .. issue.title,
        action = function() os.execute('open "' .. issue.url .. '"') end
      })
    end
  end
  
  return items
end
--]]