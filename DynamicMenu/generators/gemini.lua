-- Gemini conversation tab switcher generator
-- Returns Gemini tabs from Chrome/Canary with conversation titles extracted from DOM
-- Item '1' always opens New Chat, Item '2' opens Search
-- Items 'a'-'z' list existing Gemini conversations
-- Args: "browser,account" where:
--   browser = "chrome" or "canary" (default: canary)
--   account = email for Google account (optional)
-- Examples:
--   dynamic:gemini|canary,user@example.com
--   dynamic:gemini|,user@example.com  (default browser with account)

return function(args)
  local items = {}

  -- Parse args: "browser,account"
  args = args or ""
  local browser = "canary"
  local account = nil

  if args ~= "" then
    local parts = {}
    for part in args:gmatch("[^,]+") do
      table.insert(parts, part)
    end
    browser = (parts[1] and parts[1] ~= "") and parts[1] or "canary"
    account = parts[2]
  end

  local appName = browser == "chrome" and "Google Chrome" or "Google Chrome Canary"

  -- Build base URL based on account
  local baseUrl = account
    and ("https://gemini.google.com/u/" .. account)
    or "https://gemini.google.com"

  -- JXA script to find all Gemini tabs AND first window (for new tab actions)
  local script = string.format([[
    (function() {
      const appName = '%s';

      try {
        const chrome = Application(appName);
        if (!chrome.running()) return { tabs: [], firstWindow: null };

        chrome.includeStandardAdditions = true;
        const tabs = [];
        let firstWindow = null;

        const windows = chrome.windows();
        for (let windowIndex = 0; windowIndex < windows.length; windowIndex++) {
          const window = windows[windowIndex];
          const windowTabs = window.tabs();

          for (let tabIndex = 0; tabIndex < windowTabs.length; tabIndex++) {
            const tab = windowTabs[tabIndex];
            const url = tab.url();

            if (!url.includes('gemini.google.com')) continue;

            // Capture first Gemini window for new tab actions
            if (!firstWindow) {
              firstWindow = { windowIndex: windowIndex, tabIndex: tabIndex };
            }

            const tabTitle = tab.title();
            let displayTitle = tabTitle;

            if (displayTitle.startsWith('Gemini - ')) {
              displayTitle = displayTitle.substring(9);
            } else if (displayTitle === 'Gemini' || displayTitle === 'Google Gemini') {
              const match = url.match(/\/app\/([a-f0-9]+)/);
              displayTitle = match ? 'Chat ' + match[1].substring(0, 8) + '...' : 'Gemini Chat';
            }

            if (displayTitle.length > 60) {
              displayTitle = displayTitle.substring(0, 57) + '...';
            }

            tabs.push({
              title: displayTitle,
              url: url,
              windowIndex: windowIndex,
              tabIndex: tabIndex
            });
          }
        }
        return { tabs: tabs, firstWindow: firstWindow };
      } catch(e) {
        return { tabs: [], firstWindow: null };
      }
    })();
  ]], appName:gsub("'", "\\'"))

  local ok, result = hs.osascript.javascript(script)
  local geminiTabs = (ok and result and result.tabs) or {}
  local firstWindow = (ok and result and result.firstWindow) or nil

  -- Helper: Open URL in existing Gemini window (uses cached firstWindow)
  -- Uses AppleScript for reliable tab positioning within tab groups
  local function openGeminiUrl(url)
    if firstWindow then
      -- Use AppleScript for reliable tab positioning (1-indexed)
      local windowNum = firstWindow.windowIndex + 1
      local tabNum = firstWindow.tabIndex + 1

      local appleScript = string.format([[
        tell application "%s"
          set targetWindow to window %d
          set index of targetWindow to 1
          activate

          -- Create new tab after the Gemini tab
          make new tab at after tab %d of targetWindow with properties {URL:"%s"}

          -- Activate the new tab
          set active tab index of targetWindow to %d
        end tell
      ]], appName, windowNum, tabNum, url, tabNum + 1)

      hs.osascript.applescript(appleScript)
    else
      hs.urlevent.openURL(url)
    end
  end

  -- Fixed items (use cached firstWindow data)
  items["1"] = {
    label = "New Chat",
    icon = "gemini.png",
    action = function() openGeminiUrl(baseUrl .. "/app") end
  }

  items["2"] = {
    label = "Search",
    icon = "gemini.png",
    action = function() openGeminiUrl(baseUrl .. "/search") end
  }

  -- Check if extension is working (tabs have real titles, not fallback IDs)
  local extensionWorking = false
  for _, tab in ipairs(geminiTabs) do
    -- If any tab has a real title (not "Chat xxxxx..." or "Gemini Chat"), extension is working
    if not tab.title:match("^Chat %x+") and tab.title ~= "Gemini Chat" then
      extensionWorking = true
      break
    end
  end

  -- Show warning if there are tabs but extension isn't working
  if #geminiTabs > 0 and not extensionWorking then
    items["0"] = {
      label = "⚠ Install extension for titles",
      icon = "generic.png",
      action = function()
        -- Open extensions folder in Finder
        hs.execute("open '" .. hs.configdir .. "/Spoons/Hammerflow.spoon/extensions/gemini-tab-titles'")
      end
    }
  end

  -- Dynamic tab items (a, b, c, ...)
  for i, tab in ipairs(geminiTabs) do
    if i > 26 then break end
    local key = string.char(96 + i)  -- 97='a', 98='b', etc.

    items[key] = {
      label = tab.title,
      icon = "gemini.png",
      action = function()
        local switchScript = string.format([[
          (function() {
            const chrome = Application('%s');
            if (!chrome.running()) return;
            const window = chrome.windows[%d];
            window.activeTabIndex = %d + 1;
            window.index = 1;
            chrome.activate();
          })();
        ]], appName:gsub("'", "\\'"), tab.windowIndex, tab.tabIndex)

        hs.osascript.javascript(switchScript)
      end
    }
  end

  return items
end
