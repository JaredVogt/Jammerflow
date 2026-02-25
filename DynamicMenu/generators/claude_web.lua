-- Claude Web tab switcher generator
-- Returns Claude tabs from Chrome with a fixed "New Chat" option
-- Item 'a' always opens https://claude.ai/new
-- Other items list existing Claude conversations

return function(args)
  local items = {}

  -- Fixed item: New Claude chat (always key 'a')
  -- Opens next to existing Claude tab to inherit tab group
  items["a"] = {
    label = "New Chat",
    icon = "claude.png",
    action = function()
      -- Combined script: find Claude tab, bring window to front, create new tab next to it
      -- Uses AppleScript for more reliable tab positioning
      local openScript = [[
        (function() {
          const chrome = Application('Google Chrome');
          if (!chrome.running()) return { success: false, reason: 'not running' };

          // Find first Claude tab
          const windows = chrome.windows();
          for (let w = 0; w < windows.length; w++) {
            const tabs = windows[w].tabs();
            for (let t = 0; t < tabs.length; t++) {
              if (tabs[t].title().endsWith(' - Claude')) {
                // Return the indices for AppleScript to handle
                return {
                  success: true,
                  windowIndex: w,
                  tabIndex: t,
                  tabCount: tabs.length
                };
              }
            }
          }
          return { success: false, reason: 'no claude tab' };
        })();
      ]]

      local ok, result = hs.osascript.javascript(openScript)

      if ok and result and result.success then
        -- Use AppleScript for reliable tab positioning (1-indexed)
        local windowNum = result.windowIndex + 1
        local tabNum = result.tabIndex + 1

        -- AppleScript to: bring window to front, create tab after the Claude tab, activate it
        local appleScript = string.format([[
          tell application "Google Chrome"
            set targetWindow to window %d
            set index of targetWindow to 1
            activate

            -- Create new tab after the Claude tab (position tabNum + 1)
            make new tab at after tab %d of targetWindow with properties {URL:"https://claude.ai/new"}

            -- Activate the newly created tab
            set active tab index of targetWindow to %d
          end tell
        ]], windowNum, tabNum, tabNum + 1)

        hs.osascript.applescript(appleScript)
      else
        -- No Claude tabs found or script failed, just open normally
        hs.urlevent.openURL("https://claude.ai/new")
      end
    end
  }

  -- JXA script to find Chrome tabs with " - Claude" in title
  local script = [[
    (function() {
      const appName = 'Google Chrome';

      try {
        const chrome = Application(appName);
        if (!chrome.running()) {
          return [];
        }

        chrome.includeStandardAdditions = true;
        const results = [];
        const windows = chrome.windows();

        for (let windowIndex = 0; windowIndex < windows.length; windowIndex++) {
          const window = windows[windowIndex];
          const tabs = window.tabs();

          for (let tabIndex = 0; tabIndex < tabs.length; tabIndex++) {
            const tab = tabs[tabIndex];
            const title = tab.title();
            const url = tab.url();

            // Match tabs ending with " - Claude"
            if (title.endsWith(' - Claude')) {
              results.push({
                title: title,
                url: url,
                windowIndex: windowIndex,
                tabIndex: tabIndex
              });
            }
          }
        }

        return results;
      } catch(e) {
        return [];
      }
    })();
  ]]

  -- Execute JXA script
  local ok, result = hs.osascript.javascript(script)

  if ok and result then
    -- Start assigning keys from 'b' (since 'a' is reserved for New Chat)
    local keyIndex = 2  -- 'b' is ASCII 98, so start at index 2 for b, c, d...

    for _, tab in ipairs(result) do
      -- Strip " - Claude" suffix from title for display
      local displayLabel = tab.title:gsub(" %- Claude$", "")

      -- Generate key: b, c, d, e, ... (skip 'a')
      local key = string.char(96 + keyIndex)  -- 97='a', 98='b', etc.
      keyIndex = keyIndex + 1

      -- Skip if we've exhausted single letters
      if keyIndex > 26 then break end

      -- Capture URL for stable identification (indices change with window z-order)
      local tabUrl = tab.url

      items[key] = {
        label = displayLabel,
        icon = "claude.png",
        action = function()
          -- Search for tab by URL at switch time (indices may be stale)
          local switchScript = string.format([[
            (function() {
              const chrome = Application('Google Chrome');
              if (!chrome.running()) return;

              const targetUrl = '%s';
              const windows = chrome.windows();

              for (let w = 0; w < windows.length; w++) {
                const tabs = windows[w].tabs();
                for (let t = 0; t < tabs.length; t++) {
                  if (tabs[t].url() === targetUrl) {
                    windows[w].activeTabIndex = t + 1;  // 1-indexed in JXA
                    windows[w].index = 1;  // Bring window to front
                    chrome.activate();
                    return;
                  }
                }
              }
            })();
          ]], tabUrl:gsub("'", "\\'"))

          hs.osascript.javascript(switchScript)
        end
      }
    end
  end

  return items
end
