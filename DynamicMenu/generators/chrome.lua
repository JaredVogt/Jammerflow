-- Chrome/Canary tab switcher generator
-- Returns a list of Chrome/Canary tabs filtered by keyword(s)
-- Args format: "keyword,browser" where browser is "chrome" or "canary" (default: canary)
-- Multiple keywords can be separated by | for OR matching
-- Examples:
--   dynamic:chrome|gmail,canary                    - search "gmail" in Canary
--   dynamic:chrome|github,chrome                   - search "github" in Chrome
--   dynamic:chrome|mail.google|calendar.google,canary - search mail OR calendar in Canary
--   dynamic:chrome|,canary                         - show all Canary tabs
--
-- PERFORMANCE: Uses AppleScript batch fetching (title of every tab of every window)
-- instead of JXA per-tab calls. This is ~20x faster for browsers with many tabs.

return function(args)
  local items = {}

  -- Parse args: "keyword(s),browser"
  -- Keywords can be separated by | for OR matching
  args = args or ""
  local keywordStr = ""
  local browser = "canary"  -- default to Canary

  if args ~= "" then
    local parts = {}
    for part in args:gmatch("[^,]+") do
      table.insert(parts, part)
    end
    keywordStr = parts[1] or ""
    browser = parts[2] or "canary"
  end

  -- Parse keywords into array (split by |)
  local patterns = {}
  if keywordStr ~= "" then
    for pattern in keywordStr:gmatch("[^|]+") do
      table.insert(patterns, pattern:lower())
    end
  end

  -- Determine app name
  local appName = browser == "chrome" and "Google Chrome" or "Google Chrome Canary"
  local iconName = browser == "chrome" and "chrome.png" or "canary.png"

  -- AppleScript with BATCH fetching - much faster than JXA per-tab calls
  -- Uses "title of every tab of every window" to get all data in 2 IPC calls
  local script = string.format([[
    tell application "%s"
      if not running then return ""

      -- Batch fetch ALL titles and URLs at once (2 IPC calls total)
      set allTitles to title of every tab of every window
      set allURLs to URL of every tab of every window

      set output to ""
      set winIndex to 0
      repeat with winTitles in allTitles
        set tabIndex to 0
        repeat with tabTitle in winTitles
          set tabURL to item (tabIndex + 1) of item (winIndex + 1) of allURLs
          set output to output & winIndex & "|||" & tabIndex & "|||" & tabTitle & "|||" & tabURL & linefeed
          set tabIndex to tabIndex + 1
        end repeat
        set winIndex to winIndex + 1
      end repeat
      return output
    end tell
  ]], appName)

  -- Execute AppleScript
  local ok, result = hs.osascript.applescript(script)

  if ok and result and result ~= "" then
    -- Parse the delimited output and filter
    for line in result:gmatch("[^\n]+") do
      local winIndex, tabIndex, title, url = line:match("^(%d+)|||(%d+)|||(.-)|||(.+)$")

      if winIndex and tabIndex and title and url then
        local titleLower = title:lower()
        local urlLower = url:lower()

        -- Filter by patterns (OR logic) or show all if no patterns
        local matches = (#patterns == 0)  -- empty = match all
        for _, pattern in ipairs(patterns) do
          if titleLower:find(pattern, 1, true) or urlLower:find(pattern, 1, true) then
            matches = true
            break
          end
        end

        if matches then
          -- Extract domain from URL
          local domain = url:match("^https?://([^/]+)") or url

          local displayLabel
          local useIcon = iconName

          -- Special formatting for Gmail tabs - show email address
          if domain == "mail.google.com" then
            local email = title:match("([%w%._%+%-]+@[%w%._%+%-]+)")
            if email then
              displayLabel = email
              useIcon = "generic.png"
            else
              displayLabel = "Gmail"
              useIcon = "generic.png"
            end
          -- Special formatting for Calendar tabs - show "Account - Calendar"
          elseif domain == "calendar.google.com" then
            -- Title format: "Account - Calendar - Week of Date"
            local account = title:match("^(.-)%s+%-%s+Calendar")
            if account then
              displayLabel = account .. " - Calendar"
            else
              displayLabel = "Calendar"
            end
            useIcon = "generic.png"
          else
            -- Default format: "Title — domain.com"
            displayLabel = title .. " — " .. domain
            useIcon = iconName
          end

          local winIdx = tonumber(winIndex)
          local tabIdx = tonumber(tabIndex)

          table.insert(items, {
            label = displayLabel,
            icon = useIcon,
            action = function()
              -- Switch to the specific tab (JXA is fine for single calls)
              local switchScript = string.format([[
                (function() {
                  const chrome = Application('%s');
                  if (!chrome.running()) return;
                  const window = chrome.windows[%d];
                  window.activeTabIndex = %d + 1;
                  window.index = 1;
                  chrome.activate();
                })();
              ]], appName:gsub("'", "\\'"), winIdx, tabIdx)

              hs.osascript.javascript(switchScript)
            end
          })
        end
      end
    end
  end

  return items
end
