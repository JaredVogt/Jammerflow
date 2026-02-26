---@diagnostic disable: undefined-global

local obj = {}
obj.__index = obj

-- URL event handler for reload
hs.urlevent.bind("reload", function(eventName, params)
    hs.reload()
end)

-- Config editor URL event handlers
-- Install config from Downloads folder
hs.urlevent.bind("hammerflow_install", function(eventName, params)
    if params.file then
        local downloads = os.getenv("HOME") .. "/Downloads/"
        local source = downloads .. params.file
        local dest = hs.configdir .. "/Hammerflow/config.toml"

        -- Check if source file exists
        if not file_exists(source) then
            hs.alert("❌ Config file not found in Downloads", 3)
            log.error('config.install', {error = "Source file not found", file = params.file})
            return
        end

        -- Validate TOML first
        local success, message = validateTomlStructure(source)
        if not success then
            hs.alert("❌ Invalid TOML: " .. message, 5)
            log.error('config.install', {error = "TOML validation failed", message = message})
            return
        end

        -- Create backup with timestamp
        local timestamp = os.date("%Y%m%d-%H%M%S")
        local backupPath = dest .. ".backup-" .. timestamp
        os.execute(string.format("cp '%s' '%s'", dest, backupPath))
        log.info('config.backup', {backup = backupPath})

        -- Move new config into place
        local success = os.execute(string.format("mv '%s' '%s'", source, dest))

        if success then
            -- Reload Hammerflow configuration
            obj.loadFirstValidTomlFile({"config.toml"})
            hs.alert("✅ Config updated successfully!", 2)
            log.info('config.install', {source = params.file, backup = backupPath})
        else
            hs.alert("❌ Failed to install config", 3)
            log.error('config.install', {error = "File move failed"})
        end
    else
        hs.alert("❌ No config file specified", 3)
        log.error('config.install', {error = "No file parameter"})
    end
end)

-- Create manual backup
hs.urlevent.bind("hammerflow_backup", function(eventName, params)
    local source = hs.configdir .. "/Hammerflow/config.toml"
    local timestamp = os.date("%Y%m%d-%H%M%S")
    local backupPath = source .. ".backup-" .. timestamp

    local success = os.execute(string.format("cp '%s' '%s'", source, backupPath))
    if success then
        hs.alert("✅ Backup created: " .. timestamp, 2)
        log.info('config.backup', {backup = backupPath})
    else
        hs.alert("❌ Backup failed", 3)
        log.error('config.backup', {error = "Copy failed"})
    end
end)

-- Validate TOML without installing
hs.urlevent.bind("hammerflow_validate", function(eventName, params)
    if params.file then
        local downloads = os.getenv("HOME") .. "/Downloads/"
        local source = downloads .. params.file

        if not file_exists(source) then
            hs.alert("❌ Config file not found in Downloads", 3)
            return
        end

        local valid, message = validateTomlStructure(source)
        if valid then
            hs.alert("✅ TOML is valid", 2)
            log.info('config.validate', {file = params.file, result = "valid"})
        else
            hs.alert("❌ TOML invalid: " .. message, 5)
            log.info('config.validate', {file = params.file, result = "invalid", message = message})
        end
    else
        hs.alert("❌ No config file specified", 3)
    end
end)

-- External action trigger via URL scheme
-- Forward declaration - initialized after config parsing
local urlHandler = nil

hs.urlevent.bind("hammerflow", function(eventName, params)
    if urlHandler then
        urlHandler:handleUrlEvent(eventName, params)
    else
        hs.alert("Hammerflow URL handler not ready - config still loading", 3)
    end
end)

-- Setup logging
local ok, logx = pcall(require, 'logx')
local log
if ok then
    log = logx.new('hammerflow', 'info')
else
    -- Fallback wrapper if logx not available
    local logger = hs.logger.new('Hammerflow', 'info')
    log = {
        debug = function(event, ctx, msg) logger.d(event .. ': ' .. (msg or '')) end,
        info = function(event, ctx, msg) logger.i(event .. ': ' .. (msg or '')) end,
        warn = function(event, ctx, msg) logger.w(event .. ': ' .. (msg or '')) end,
        error = function(event, ctx, msg) logger.e(event .. ': ' .. (msg or '')) end,
    }
end

function obj:setupHTTPEndpoints()
  if not (spoon and spoon.HTTPRouter) then
    log.warn('http.setup', { error = 'HTTPRouter not available' })
    return
  end

  local router = spoon.HTTPRouter
  router:unregisterRoute('GET', '/hammerflow/config')
  router:unregisterRoute('GET', '/hammerflow/backups')
  router:unregisterRoute('POST', '/hammerflow/validate')
  router:unregisterRoute('GET', '/config-editor.html')
  router:unregisterRoute('GET', '/vendor/toml-loader.mjs')
  router:unregisterRoute('GET', '/vendor/smol-toml.mjs')

  local hammerflowDir = hs.configdir .. '/Hammerflow/'
  local configPath = hammerflowDir .. 'config.toml'
  local configEditorPath = hammerflowDir .. 'configurator/config-editor.html'
  local vendorDir = hammerflowDir .. 'vendor/'
  local vendorFiles = {
    ['vendor/toml-loader.mjs'] = {
      path = vendorDir .. 'toml-loader.mjs',
      contentType = 'application/javascript; charset=utf-8'
    },
    ['vendor/smol-toml.mjs'] = {
      path = vendorDir .. 'smol-toml.mjs',
      contentType = 'application/javascript; charset=utf-8'
    }
  }

  if not hs.fs.attributes(vendorDir) then
    hs.fs.mkdir(vendorDir)
  end

  router:registerRoute('GET', '/hammerflow/config', function(method, path, headers, body)
    if not hs.fs.attributes(configPath) then
      return hs.json.encode({ error = 'Config file not found' }), 404, {
        ['Content-Type'] = 'application/json'
      }
    end

    local file = io.open(configPath, 'r')
    if not file then
      return hs.json.encode({ error = 'Failed to read config' }), 500, {
        ['Content-Type'] = 'application/json'
      }
    end

    local content = file:read('*a')
    file:close()
    log.info('http.config', { action = 'read', size = #content })
    return content, 200, { ['Content-Type'] = 'text/plain; charset=utf-8' }
  end)

  router:registerRoute('GET', '/hammerflow/backups', function()
    local configDir = hs.configdir .. '/Hammerflow/'
    local backups = {}

    local iter, dirObject = hs.fs.dir(configDir)
    if not iter then
      log.warn('http.backups', { error = dirObject, dir = configDir })
      return hs.json.encode({ backups = backups }), 200, { ['Content-Type'] = 'application/json' }
    end

    for name in iter, dirObject do
      if name and name ~= '.' and name ~= '..' then
        if name:match('^config%.toml%.backup%-') then
          local fullPath = configDir .. name
          local stat = hs.fs.attributes(fullPath)
          local modified = 'unknown'
          if stat and stat.modification then
            modified = os.date('%Y-%m-%d %H:%M:%S', stat.modification)
          end

          table.insert(backups, {
            filename = name,
            timestamp = name:match('backup%-(.+)$'),
            size = stat and stat.size or 0,
            modified = modified
          })
        end
      end
    end

    if dirObject and dirObject.close then
      dirObject:close()
    end

    table.sort(backups, function(a, b)
      return (a.timestamp or '') > (b.timestamp or '')
    end)

    return hs.json.encode({ backups = backups }), 200, { ['Content-Type'] = 'application/json' }
  end)

  router:registerRoute('POST', '/hammerflow/validate', function(method, path, headers, body)
    if not body or body == '' then
      return hs.json.encode({ valid = false, error = 'No TOML content provided' }), 400, {
        ['Content-Type'] = 'application/json'
      }
    end

    local tempDir = hs.fs.temporaryDirectory() or '/tmp'
    if tempDir:sub(-1) ~= '/' then
      tempDir = tempDir .. '/'
    end
    local tempPath = string.format('%shammerflow-validate-%d.toml', tempDir, math.floor(hs.timer.secondsSinceEpoch()))
    local tempFile, err = io.open(tempPath, 'w')
    if not tempFile then
      return hs.json.encode({ valid = false, error = 'Failed to create temp file: ' .. tostring(err) }), 500, {
        ['Content-Type'] = 'application/json'
      }
    end

    tempFile:write(body)
    tempFile:close()

    local structureValid, structureMessage = validateTomlStructure(tempPath)
    local parseValid, parseResult = pcall(function() return toml.parse(tempPath) end)

    os.remove(tempPath)

    local errors = {}
    if not structureValid or (structureMessage and structureMessage:lower():find('error')) then
      table.insert(errors, structureMessage or 'Validation failed')
    end
    if not parseValid then
      table.insert(errors, tostring(parseResult))
    end

    local valid = #errors == 0
    local errorMessage = nil
    if not valid then
      errorMessage = table.concat(errors, '; ')
    end

    log.info('http.validate', { valid = valid, error = errorMessage })

    return hs.json.encode({
      valid = valid,
      error = errorMessage
    }), valid and 200 or 400, { ['Content-Type'] = 'application/json' }
  end)

  router:registerRoute('GET', '/config-editor.html', function()
    local file = io.open(configEditorPath, 'r')
    if not file then
      log.error('http.config_editor', { error = 'File not found', path = configEditorPath })
      return hs.json.encode({ error = 'Config editor not found' }), 404, { ['Content-Type'] = 'application/json' }
    end
    local content = file:read('*a')
    file:close()
    return content, 200, { ['Content-Type'] = 'text/html; charset=utf-8' }
  end)

  for route, fileInfo in pairs(vendorFiles) do
    router:registerRoute('GET', '/' .. route, function()
      local file = io.open(fileInfo.path, 'rb')
      if not file then
        log.error('http.static', { error = 'File not found', path = fileInfo.path })
        return hs.json.encode({ error = 'File not found' }), 404, { ['Content-Type'] = 'application/json' }
      end
      local content = file:read('*a')
      file:close()
      return content, 200, { ['Content-Type'] = fileInfo.contentType }
    end)
  end

  log.info('http.endpoints', { registered = {'/hammerflow/config', '/hammerflow/backups', '/hammerflow/validate', '/config-editor.html', '/vendor/toml-loader.mjs', '/vendor/smol-toml.mjs'} })
end

-- Metadata
obj.name = "Hammerflow"
obj.version = "1.0"
obj.author = "Sam Lewis <sam@saml.dev>"
obj.homepage = "https://github.com/saml-dev/Hammerflow.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- State
obj.auto_reload = false
obj._userFunctions = {}
obj._apps = {}
obj._inputWebview = nil
obj._inputModal = nil

-- lets us package RecursiveBinder with Hammerflow to include
-- sorting and a bug fix that hasn't been merged upstream yet
-- https://github.com/Hammerspoon/Spoons/pull/333
package.path = package.path .. ";" .. hs.configdir .. "/Spoons/Hammerflow.spoon/Spoons/?.spoon/init.lua"
hs.loadSpoon("RecursiveBinder")
log.info('load.extension', {name = 'RecursiveBinder'})

local function full_path(rel_path)
  local current_file = debug.getinfo(2, "S").source:sub(2) -- Get the current file's path
  local current_dir = current_file:match("(.*/)") or "."   -- Extract the directory
  return current_dir .. rel_path
end
local function loadfile_relative(path)
  local full_path = full_path(path)
  local f, err = loadfile(full_path)
  if f then
    return f()
  else
    error("Failed to require relative file: " .. full_path .. " - " .. err)
  end
end
local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local toml = loadfile_relative("lib/tinytoml.lua")
local validateTomlStructure = loadfile_relative("configurator/toml_validator.lua")
local dynamicMenu = loadfile_relative("DynamicMenu/init.lua")
local UrlHandler = loadfile_relative("url_handler.lua")

local function parseKeystroke(keystroke)
  local parts = {}
  for part in keystroke:gmatch("%S+") do
    table.insert(parts, part)
  end
  local key = table.remove(parts) -- Last part is the key
  return parts, key
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Action Helpers
local singleKey = spoon.RecursiveBinder.singleKey
local rect = hs.geometry.rect
local move = function(loc)
  return function()
    local w = hs.window.focusedWindow()
    w:move(loc)
    -- for some reason Firefox, and therefore Zen Browser, both
    -- animate when no other apps do, and only change size *or*
    -- position when moved, so it has to be issued twice. 0.2 is
    -- the shortest delay that works consistently.
    if hs.application.frontmostApplication():bundleID() == "app.zen-browser.zen" or
        hs.application.frontmostApplication():bundleID() == "org.mozilla.firefox" then
      os.execute("sleep 0.2")
      w:move(loc)
    end
  end
end
local open = function(link)
  return function() os.execute(string.format("open \"%s\"", link)) end
end
local raycast = function(link)
  -- raycast needs -g to keep current app as "active" for
  -- pasting from emoji picker and window management
  return function() os.execute(string.format("open -g %s", link)) end
end
local text = function(s)
  return function() hs.eventtap.keyStrokes(s) end
end
local keystroke = function(keystroke)
  local mods, key = parseKeystroke(keystroke)
  return function() hs.eventtap.keyStroke(mods, key) end
end
local cmd = function(cmd)
  return function() os.execute(cmd .. " &") end
end
local code = function(arg) return cmd("open -a 'Visual Studio Code' " .. arg) end
local launch = function(app)
  return function() hs.application.launchOrFocus(app) end
end
local hs_run = function(lua)
  return function() load(lua)() end
end
local userFunc = function(funcKey)
  local args = nil
  -- if funcKey has | in it, split on it. first is function name, rest are args for that function
  if funcKey:find("|") then
    local sp = split(funcKey, "|")
    funcKey = table.remove(sp, 1)
    args = sp
  end
  return function()
    if obj._userFunctions[funcKey] then
      obj._userFunctions[funcKey](table.unpack(args or {}))
    else
      hs.alert("Unknown function " .. funcKey, 3)
    end
  end
end
local function isApp(app)
  return function()
    local frontApp = hs.application.frontmostApplication()
    local title = frontApp:title():lower()
    local bundleID = frontApp:bundleID():lower()
    app = app:lower()
    return title == app or bundleID == app
  end
end

-- window management presets
local windowLocations = {
  ["left-half"] = move(hs.layout.left50),
  ["center-half"] = move(rect(.25, 0, .5, 1)),
  ["right-half"] = move(hs.layout.right50),
  ["first-quarter"] = move(hs.layout.left25),
  ["second-quarter"] = move(rect(.25, 0, .25, 1)),
  ["third-quarter"] = move(rect(.5, 0, .25, 1)),
  ["fourth-quarter"] = move(hs.layout.right25),
  ["left-third"] = move(rect(0, 0, 1 / 3, 1)),
  ["center-third"] = move(rect(1 / 3, 0, 1 / 3, 1)),
  ["right-third"] = move(rect(2 / 3, 0, 1 / 3, 1)),
  ["top-half"] = move(rect(0, 0, 1, .5)),
  ["bottom-half"] = move(rect(0, .5, 1, .5)),
  ["top-left"] = move(rect(0, 0, .5, .5)),
  ["top-right"] = move(rect(.5, 0, .5, .5)),
  ["bottom-left"] = move(rect(0, .5, .5, .5)),
  ["bottom-right"] = move(rect(.5, .5, .5, .5)),
  ["maximized"] = move(hs.layout.maximized),
  ["fullscreen"] = function() hs.window.focusedWindow():toggleFullScreen() end
}

-- Nudge function: move window by a fraction of screen size
local function nudge(direction, amount)
  amount = amount or 0.125  -- 1/8 screen default
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local screen = win:screen():frame()
    local frame = win:frame()

    local dx, dy = 0, 0
    if direction == "left" then dx = -screen.w * amount
    elseif direction == "right" then dx = screen.w * amount
    elseif direction == "up" then dy = -screen.h * amount
    elseif direction == "down" then dy = screen.h * amount
    end

    -- Calculate new position with edge clamping (stop at screen edges)
    local newX = math.max(screen.x, math.min(frame.x + dx, screen.x + screen.w - frame.w))
    local newY = math.max(screen.y, math.min(frame.y + dy, screen.y + screen.h - frame.h))

    frame.x = newX
    frame.y = newY
    win:setFrame(frame)
  end
end

-- Maps prefix + direction(s) to window positions for chord system
local chordWindowMap = {
  -- Halves (prefix "2")
  ["2h"] = "left-half",
  ["2l"] = "right-half",
  ["2j"] = "center-half",
  ["2t"] = "top-half",
  ["2b"] = "bottom-half",

  -- Thirds (prefix "3")
  ["3h"] = "left-third",
  ["3l"] = "right-third",
  ["3j"] = "center-third",

  -- Horizontal quarters (prefix "4" + single key)
  ["4h"] = "first-quarter",
  ["4j"] = "second-quarter",
  ["4k"] = "third-quarter",
  ["4l"] = "fourth-quarter",
}

-- Map keys to nudge directions
local nudgeDirections = {
  h = "left",
  l = "right",
  j = "down",
  k = "up",
  t = "up",    -- t and k both nudge up
  b = "down",  -- b and j both nudge down
}

-- Smart window handler: uses chord state to determine action
-- No prefix = nudge, with prefix = snap to position
local function smartWindow(key)
  return function(chordState)
    local prefix = chordState and chordState.prefix or ""
    local partial = chordState and chordState.partialDirection or ""

    -- Build the full chord key
    local chordKey = prefix .. partial .. key

    if prefix == "" then
      -- No prefix = nudge mode
      local dir = nudgeDirections[key]
      if dir then nudge(dir)() end
    else
      -- Look up window position
      local position = chordWindowMap[chordKey]
      if position and windowLocations[position] then
        windowLocations[position]()
      end
    end
  end
end

-- helper functions
local function startswith(s, prefix)
  return s:sub(1, #prefix) == prefix
end

local function postfix(s)
  --  return the string after the colon
  return s:sub(s:find(":") + 1)
end

-- History utility functions for input dialogs
local function getHistoryKey(urlTemplate)
  -- Generate a stable key from URL template for history storage
  return hs.hash.MD5(urlTemplate):sub(1, 8)
end

local function getHistoryPath(urlTemplate)
  local historyDir = "/tmp/hammerflow_history"
  os.execute("mkdir -p " .. historyDir)
  return historyDir .. "/" .. getHistoryKey(urlTemplate) .. ".json"
end

local function loadHistory(urlTemplate)
  if not urlTemplate then return {} end
  local path = getHistoryPath(urlTemplate)
  local file = io.open(path, "r")
  if not file then return {} end
  local content = file:read("*all")
  file:close()
  local success, history = pcall(hs.json.decode, content)
  return success and history or {}
end

local function saveToHistory(urlTemplate, searchTerm)
  if not urlTemplate or not searchTerm or searchTerm == "" then return end
  local history = loadHistory(urlTemplate)
  -- Remove duplicates
  for i = #history, 1, -1 do
    if history[i] == searchTerm then
      table.remove(history, i)
    end
  end
  -- Prepend new search
  table.insert(history, 1, searchTerm)
  -- Trim to 25
  while #history > 25 do
    table.remove(history)
  end
  -- Save
  local path = getHistoryPath(urlTemplate)
  local file = io.open(path, "w")
  if file then
    file:write(hs.json.encode(history))
    file:close()
  end
end

-- Custom input dialog with aggressive focus handling and history support
local function showCustomInputDialog(prompt, callback, urlTemplate)
  -- Close existing input dialog if present and clean up ALL handlers
  if obj._inputWebview then
    if obj._inputModal then
      obj._inputModal:exit()
      obj._inputModal = nil
    end
    obj._inputWebview:delete()
    obj._inputWebview = nil
  end

  -- Load history for this action
  local history = loadHistory(urlTemplate)
  local historyJson = hs.json.encode(history) or "[]"
  local lastSearch = history[1] or ""

  local html = [[
  <!DOCTYPE html>
  <html>
  <head>
      <style>
          html, body {
              background: transparent !important;
              margin: 0;
              padding: 0;
              height: 100vh;
              width: 100vw;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: hidden;
          }
          .input-container {
              background-color: rgba(0, 0, 0, 0.9);
              border: 3px solid #00ff00;
              border-radius: 12px;
              padding: 25px;
              text-align: center;
              font-family: 'Menlo', monospace;
              color: white;
              min-width: 400px;
              max-width: 450px;
              box-shadow: 0 0 20px rgba(0, 255, 0, 0.5);
              box-sizing: border-box;
          }
          .prompt-text {
              font-size: 18px;
              margin-bottom: 20px;
              color: #00ff00;
              text-shadow: 0 0 5px #00ff00;
          }
          .input-wrapper {
              position: relative;
              width: 100%;
              margin-bottom: 20px;
          }
          .input-field {
              width: 100%;
              padding: 12px;
              font-size: 16px;
              font-family: 'Menlo', monospace;
              background-color: rgba(255, 255, 255, 0.1);
              border: 2px solid #00ff00;
              border-radius: 6px;
              color: white;
              outline: none;
              box-sizing: border-box;
          }
          .input-field:focus {
              border-color: #00ff00;
              box-shadow: 0 0 10px rgba(0, 255, 0, 0.5);
          }
          .history-dropdown {
              display: none;
              position: absolute;
              top: 100%;
              left: 0;
              right: 0;
              max-height: 200px;
              overflow-y: auto;
              background-color: rgba(0, 0, 0, 0.95);
              border: 2px solid #00ff00;
              border-top: none;
              border-radius: 0 0 6px 6px;
              z-index: 100;
          }
          .history-item {
              padding: 8px 12px;
              text-align: left;
              color: #aaa;
              cursor: pointer;
              white-space: nowrap;
              overflow: hidden;
              text-overflow: ellipsis;
          }
          .history-item:hover, .history-item.selected {
              background-color: rgba(0, 255, 0, 0.2);
              color: #00ff00;
          }
          .button-container {
              display: flex;
              gap: 15px;
              justify-content: center;
          }
          .btn {
              padding: 10px 20px;
              font-size: 14px;
              font-family: 'Menlo', monospace;
              border: 2px solid #00ff00;
              border-radius: 6px;
              background-color: rgba(0, 255, 0, 0.1);
              color: #00ff00;
              cursor: pointer;
              transition: all 0.2s ease;
              min-width: 80px;
          }
          .btn:hover {
              background-color: rgba(0, 255, 0, 0.2);
              transform: scale(1.05);
          }
          .btn-primary {
              background-color: rgba(0, 255, 0, 0.2);
          }
      </style>
  </head>
  <body>
      <div class="input-container">
          <div class="prompt-text">]] .. (prompt or "Enter text:") .. [[</div>
          <div class="input-wrapper">
              <input type="text" class="input-field" id="userInput" placeholder="Click here and type..." value="]] .. lastSearch:gsub('"', '&quot;'):gsub('\n', ' ') .. [[">
              <div class="history-dropdown" id="historyDropdown"></div>
          </div>
          <div class="button-container">
              <button class="btn btn-primary" onclick="submit()">Submit</button>
              <button class="btn" onclick="cancel()">Cancel</button>
          </div>
      </div>
      <script>
          const history = ]] .. historyJson .. [[;
          let selectedIndex = -1;
          let dropdownVisible = false;

          function submit() {
              const input = document.getElementById('userInput').value;
              window.location.href = 'hammerflow://input/submit/' + encodeURIComponent(input);
          }

          function cancel() {
              window.location.href = 'hammerflow://input/cancel';
          }

          function renderDropdown() {
              const dropdown = document.getElementById('historyDropdown');
              dropdown.innerHTML = '';
              if (history.length === 0) return;

              history.forEach((item, index) => {
                  const div = document.createElement('div');
                  div.className = 'history-item' + (index === selectedIndex ? ' selected' : '');
                  div.textContent = item;
                  div.onclick = () => selectItem(index);
                  dropdown.appendChild(div);
              });
          }

          function showDropdown() {
              if (history.length === 0) return;
              const dropdown = document.getElementById('historyDropdown');
              dropdown.style.display = 'block';
              dropdownVisible = true;
              renderDropdown();
          }

          function hideDropdown() {
              const dropdown = document.getElementById('historyDropdown');
              dropdown.style.display = 'none';
              dropdownVisible = false;
              selectedIndex = -1;
          }

          function selectItem(index) {
              if (index >= 0 && index < history.length) {
                  document.getElementById('userInput').value = history[index];
                  hideDropdown();
                  document.getElementById('userInput').focus();
              }
          }

          // Input field event handlers
          document.getElementById('userInput').addEventListener('keydown', function(e) {
              if (e.key === 'ArrowDown' || e.keyCode === 40) {
                  e.preventDefault();
                  if (!dropdownVisible && history.length > 0) {
                      showDropdown();
                      // Start at second item (index 1) since first is pre-populated
                      selectedIndex = history.length > 1 ? 1 : 0;
                  } else if (dropdownVisible) {
                      selectedIndex = Math.min(selectedIndex + 1, history.length - 1);
                  }
                  renderDropdown();
                  return false;
              }
              if (e.key === 'ArrowUp' || e.keyCode === 38) {
                  e.preventDefault();
                  if (!dropdownVisible && history.length > 0) {
                      showDropdown();
                      selectedIndex = history.length - 1;
                  } else if (dropdownVisible) {
                      selectedIndex = Math.max(selectedIndex - 1, 0);
                  }
                  renderDropdown();
                  return false;
              }
              if (e.key === 'Enter' || e.keyCode === 13) {
                  e.preventDefault();
                  e.stopPropagation();
                  if (dropdownVisible && selectedIndex >= 0) {
                      selectItem(selectedIndex);
                  } else {
                      submit();
                  }
                  return false;
              }
              if (e.key === 'Escape' || e.keyCode === 27) {
                  if (dropdownVisible) {
                      e.preventDefault();
                      e.stopPropagation();
                      hideDropdown();
                      return false;
                  }
                  // Let escape bubble up to cancel dialog
              }
          });

          // Hide dropdown on typing
          document.getElementById('userInput').addEventListener('input', function() {
              hideDropdown();
          });
          
          // Global keyboard handlers (only for clicks outside input)
          document.addEventListener('keydown', function(e) {
              // Don't handle if input already handled it
              if (e.target.id === 'userInput') return;

              if (e.key === 'Enter' || e.keyCode === 13) {
                  e.preventDefault();
                  e.stopPropagation();
                  submit();
                  return false;
              } else if (e.key === 'Escape' || e.keyCode === 27) {
                  if (!dropdownVisible) {
                      e.preventDefault();
                      e.stopPropagation();
                      cancel();
                      return false;
                  }
              }
          });

          // Focus input field when clicking anywhere
          document.addEventListener('click', function(e) {
              if (e.target.className !== 'history-item') {
                  document.getElementById('userInput').focus();
              }
          });

          // Auto-focus on load and select text
          window.addEventListener('load', function() {
              const input = document.getElementById('userInput');
              input.focus();
              input.select();
          });
      </script>
  </body>
  </html>
  ]]
  
  -- Create webview
  local screen = hs.screen.mainScreen()
  local screenFrame = screen:frame()
  
  local dialogWidth = 500
  local dialogHeight = 400  -- Increased to accommodate history dropdown
  local webviewFrame = {
    x = screenFrame.x + (screenFrame.w - dialogWidth) / 2,
    y = screenFrame.y + (screenFrame.h - dialogHeight) / 2,
    w = dialogWidth,
    h = dialogHeight
  }
  
  obj._inputWebview = hs.webview.new(webviewFrame)
    :windowStyle({})
    :allowTextEntry(true)
    :level(hs.drawing.windowLevels.modalPanel)
    :transparent(true)
    :html(html)
    :show()
    :bringToFront(true)

  -- Give webview OS-level focus without clicking (preserves text selection)
  hs.timer.doAfter(0.1, function()
    if obj._inputWebview then
      local win = obj._inputWebview:hswindow()
      if win then win:focus() end
    end
  end)

  -- Set up navigation callback
  obj._inputWebview:navigationCallback(function(action, webview, navID, url)
    if action == "didStartProvisionalNavigation" and url then
      if url:match("hammerflow://input/submit/(.*)") then
        local userInput = url:match("hammerflow://input/submit/(.*)")
        userInput = hs.http.urlDecode(userInput) or ""
        -- Clean up ALL handlers
        if obj._inputModal then
          obj._inputModal:exit()
          obj._inputModal = nil
        end
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(userInput)
        return false
      elseif url:match("hammerflow://input/cancel") then
        -- Clean up ALL handlers
        if obj._inputWebview.escapeHandler then
          obj._inputWebview.escapeHandler:delete()
        end
        if obj._inputWebview.enterHandler then
          obj._inputWebview.enterHandler:delete()
        end
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(nil)
        return false
      end
    end
    return true
  end)
  
  -- Create a modal that captures keys only when dialog is active
  local modal = hs.hotkey.modal.new()
  
  -- Enter key handler
  modal:bind({}, "return", function()
    print("[debug] return key captured by modal")
    -- Immediately exit modal to release keys
    modal:exit()

    if obj._inputWebview then
      -- Get the input value using JavaScript
      obj._inputWebview:evaluateJavaScript("document.getElementById('userInput').value", function(result)
        local userInput = result or ""
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(userInput)
      end)
    end
  end)

  -- Escape key handler
  modal:bind({}, "escape", function()
    print("[debug] escape key captured by modal")
    -- Immediately exit modal to release keys
    modal:exit()

    if obj._inputWebview then
      obj._inputWebview:delete()
      obj._inputWebview = nil
      callback(nil)
    end
  end)

  -- Enter the modal
  modal:enter()
  print("[debug] input modal entered, return key bound for prompt: " .. (prompt or "nil"))
  obj._inputModal = modal
  
  -- Focus on the webview
  hs.timer.doAfter(0.3, function()
    if obj._inputWebview then
      obj._inputWebview:evaluateJavaScript([[
        document.getElementById('userInput').focus();
        document.getElementById('userInput').select();
      ]])
    end
  end)
end


-- Custom textarea dialog for multi-line input
local function showCustomTextAreaDialog(prompt, callback)
  -- Close existing input dialog if present and clean up ALL handlers
  if obj._inputWebview then
    if obj._inputModal then
      obj._inputModal:exit()
      obj._inputModal = nil
    end
    obj._inputWebview:delete()
    obj._inputWebview = nil
  end
  
  local html = [[
  <!DOCTYPE html>
  <html>
  <head>
      <style>
          html, body {
              background: transparent !important;
              margin: 0;
              padding: 0;
              height: 100vh;
              width: 100vw;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: hidden;
          }
          .input-container {
              background-color: rgba(0, 0, 0, 0.9);
              border: 3px solid #00ff00;
              border-radius: 12px;
              padding: 25px;
              text-align: center;
              font-family: 'Menlo', monospace;
              color: white;
              min-width: 550px;
              max-width: 600px;
              box-shadow: 0 0 20px rgba(0, 255, 0, 0.5);
              box-sizing: border-box;
          }
          .prompt-text {
              font-size: 18px;
              margin-bottom: 20px;
              color: #00ff00;
              text-shadow: 0 0 5px #00ff00;
          }
          .textarea-field {
              width: 100%;
              padding: 12px;
              font-size: 14px;
              font-family: 'Menlo', monospace;
              background-color: rgba(255, 255, 255, 0.1);
              border: 2px solid #00ff00;
              border-radius: 6px;
              color: white;
              outline: none;
              margin-bottom: 20px;
              box-sizing: border-box;
              resize: vertical;
              min-height: 120px;
              overflow-y: auto;
              line-height: 1.4;
          }
          .textarea-field:focus {
              border-color: #00ff00;
              box-shadow: 0 0 10px rgba(0, 255, 0, 0.5);
          }
          .textarea-field::placeholder {
              color: rgba(255, 255, 255, 0.5);
              font-style: italic;
          }
          .button-container {
              display: flex;
              gap: 15px;
              justify-content: center;
              align-items: center;
          }
          .btn {
              padding: 10px 20px;
              font-size: 14px;
              font-family: 'Menlo', monospace;
              border: 2px solid #00ff00;
              border-radius: 6px;
              background-color: rgba(0, 255, 0, 0.1);
              color: #00ff00;
              cursor: pointer;
              transition: all 0.2s ease;
              min-width: 80px;
          }
          .btn:hover {
              background-color: rgba(0, 255, 0, 0.2);
              transform: scale(1.05);
          }
          .btn-primary {
              background-color: rgba(0, 255, 0, 0.2);
          }
          .shortcut-hint {
              font-size: 12px;
              color: rgba(0, 255, 0, 0.7);
              margin-left: 10px;
              font-style: italic;
          }
      </style>
  </head>
  <body>
      <div class="input-container">
          <div class="prompt-text">]] .. (prompt or "Enter text:") .. [[</div>
          <textarea class="textarea-field" id="userTextArea" rows="8" placeholder="Type your multi-line text here...&#10;&#10;Tip: Use Cmd+Enter to submit quickly"></textarea>
          <div class="button-container">
              <button class="btn btn-primary" onclick="submit()">Submit</button>
              <span class="shortcut-hint">Cmd+Enter</span>
              <button class="btn" onclick="cancel()">Cancel</button>
              <span class="shortcut-hint">Escape</span>
          </div>
      </div>
      <script>
          function submit() {
              const input = document.getElementById('userTextArea').value;
              window.location.href = 'hammerflow://textarea/submit/' + encodeURIComponent(input);
          }
          
          function cancel() {
              window.location.href = 'hammerflow://textarea/cancel';
          }
          
          // Submit on Cmd+Enter or Ctrl+Enter
          document.getElementById('userTextArea').addEventListener('keydown', function(e) {
              console.log('[debug] TextArea keydown:', e.key, e.keyCode, 'metaKey:', e.metaKey, 'ctrlKey:', e.ctrlKey);
              if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                  console.log('[debug] Cmd/Ctrl+Enter detected - submitting');
                  e.preventDefault();
                  e.stopPropagation();
                  submit();
                  return false;
              }
          });
          
          // Global keyboard handlers
          document.addEventListener('keydown', function(e) {
              console.log('[debug] Document keydown:', e.key, e.keyCode);
              if (e.key === 'Escape' || e.keyCode === 27) {
                  console.log('[debug] Escape detected - cancelling');
                  e.preventDefault();
                  e.stopPropagation();
                  cancel();
                  return false;
              }
          });
          
          // Focus textarea field when clicking anywhere
          document.addEventListener('click', function(e) {
              if (e.target.tagName !== 'BUTTON') {
                  document.getElementById('userTextArea').focus();
              }
          });
          
          // Auto-focus on load
          window.addEventListener('load', function() {
              document.getElementById('userTextArea').focus();
          });
      </script>
  </body>
  </html>
  ]]
  
  -- Create webview with larger size for textarea
  local screen = hs.screen.mainScreen()
  local screenFrame = screen:frame()
  
  local dialogWidth = 650
  local dialogHeight = 400
  local webviewFrame = {
    x = screenFrame.x + (screenFrame.w - dialogWidth) / 2,
    y = screenFrame.y + (screenFrame.h - dialogHeight) / 2,
    w = dialogWidth,
    h = dialogHeight
  }
  
  obj._inputWebview = hs.webview.new(webviewFrame)
    :windowStyle({})
    :allowTextEntry(true)
    :level(hs.drawing.windowLevels.modalPanel)
    :transparent(true)
    :html(html)
    :show()
    :bringToFront(true)

  -- Give webview OS-level focus without clicking (preserves text selection)
  hs.timer.doAfter(0.1, function()
    if obj._inputWebview then
      local win = obj._inputWebview:hswindow()
      if win then win:focus() end
    end
  end)

  -- Set up navigation callback
  obj._inputWebview:navigationCallback(function(action, webview, navID, url)
    if action == "didStartProvisionalNavigation" and url then
      if url:match("hammerflow://textarea/submit/(.*)") then
        local userInput = url:match("hammerflow://textarea/submit/(.*)")
        userInput = hs.http.urlDecode(userInput) or ""
        -- Clean up ALL handlers
        if obj._inputModal then
          obj._inputModal:exit()
          obj._inputModal = nil
        end
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(userInput)
        return false
      elseif url:match("hammerflow://textarea/cancel") then
        -- Clean up ALL handlers
        if obj._inputWebview.escapeHandler then
          obj._inputWebview.escapeHandler:delete()
        end
        if obj._inputWebview.enterHandler then
          obj._inputWebview.enterHandler:delete()
        end
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(nil)
        return false
      end
    end
    return true
  end)
  
  -- Create a modal that captures keys only when dialog is active
  local modal = hs.hotkey.modal.new()
  
  -- Cmd+Enter or Ctrl+Enter handler
  modal:bind({"cmd"}, "return", function()
    -- Immediately exit modal to release keys
    modal:exit()
    
    if obj._inputWebview then
      -- Get the textarea value using JavaScript
      obj._inputWebview:evaluateJavaScript("document.getElementById('userTextArea').value", function(result)
        local userInput = result or ""
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(userInput)
      end)
    end
  end)
  
  modal:bind({"ctrl"}, "return", function()
    -- Immediately exit modal to release keys
    modal:exit()
    
    if obj._inputWebview then
      -- Get the textarea value using JavaScript
      obj._inputWebview:evaluateJavaScript("document.getElementById('userTextArea').value", function(result)
        local userInput = result or ""
        obj._inputWebview:delete()
        obj._inputWebview = nil
        callback(userInput)
      end)
    end
  end)
  
  -- Escape key handler
  modal:bind({}, "escape", function()
    -- Immediately exit modal to release keys
    modal:exit()
    
    if obj._inputWebview then
      obj._inputWebview:delete()
      obj._inputWebview = nil
      callback(nil)
    end
  end)
  
  -- Enter the modal
  modal:enter()
  obj._inputModal = modal
  
  -- Focus on the webview
  hs.timer.doAfter(0.3, function()
    if obj._inputWebview then
      obj._inputWebview:evaluateJavaScript([[
        document.getElementById('userTextArea').focus();
        document.getElementById('userTextArea').select();
      ]])
    end
  end)
end

-- Helper function to open URL in specific browser
local function openInBrowser(url, browser)
  return function() os.execute(string.format("open -a '%s' \"%s\"", browser, url)) end
end

-- Opens URL in a browser window that contains a tab matching urlPattern
-- If no matching window found, returns false (caller should fall back to normal open)
local function openInBrowserWindowWithMatch(browser, url, urlPattern)
  local script = string.format([[
    (function() {
      const app = Application('%s');
      if (!app.running()) {
        return false;
      }

      const windows = app.windows();
      for (let w = 0; w < windows.length; w++) {
        const tabs = windows[w].tabs();
        for (let t = 0; t < tabs.length; t++) {
          if (tabs[t].url().includes('%s')) {
            // Found matching window - open new tab here
            windows[w].index = 1;  // Bring to front
            app.activate();
            const newTab = app.Tab({ url: '%s' });
            windows[w].tabs.push(newTab);
            return true;
          }
        }
      }
      return false;
    })();
  ]], browser, urlPattern:gsub("'", "\\'"), url:gsub("'", "\\'"))

  local ok, result = hs.osascript.javascript(script)
  return ok and result == true
end

-- Searches a single browser for tabs matching pattern (title or URL)
-- Returns a table of matches: {w, t, title, url}
-- Uses bulk property access (2 Apple Events per window instead of 2 per tab)
local function searchBrowserTabs(browser, pattern)
  local script = string.format([[
    (function() {
      const app = Application('%s');
      if (!app.running()) { return JSON.stringify([]); }
      const windows = app.windows();
      const matches = [];
      const pat = '%s'.toLowerCase();
      for (let w = 0; w < windows.length; w++) {
        const urls = windows[w].tabs.url();
        const titles = windows[w].tabs.title();
        for (let t = 0; t < urls.length; t++) {
          if (urls[t].toLowerCase().includes(pat) || titles[t].toLowerCase().includes(pat)) {
            matches.push({w: w, t: t, title: titles[t], url: urls[t]});
          }
        }
      }
      return JSON.stringify(matches);
    })();
  ]], browser, pattern:gsub("'", "\\'"))

  local ok, rawResult = hs.osascript.javascript(script)
  if not ok then return {} end
  return hs.json.decode(rawResult) or {}
end

-- Switches to an existing browser tab matching urlPattern
-- Returns "switched" (1 match), "chooser" (2+ matches), or "none" (0 matches)
local function switchToBrowserTab(browser, urlPattern)
  local script = string.format([[
    (function() {
      const app = Application('%s');
      if (!app.running()) { return JSON.stringify([]); }
      const windows = app.windows();
      const matches = [];
      const pat = '%s'.toLowerCase();
      for (let w = 0; w < windows.length; w++) {
        const urls = windows[w].tabs.url();
        const titles = windows[w].tabs.title();
        for (let t = 0; t < urls.length; t++) {
          if (urls[t].toLowerCase().includes(pat) || titles[t].toLowerCase().includes(pat)) {
            matches.push({w: w, t: t, title: titles[t], url: urls[t]});
          }
        }
      }
      if (matches.length === 1) {
        windows[matches[0].w].activeTabIndex = matches[0].t + 1;
        windows[matches[0].w].index = 1;
        app.activate();
        return JSON.stringify({switched: true});
      }
      return JSON.stringify(matches);
    })();
  ]], browser, urlPattern:gsub("'", "\\'"))

  local ok, rawResult = hs.osascript.javascript(script)
  if not ok then return "none" end

  local result = hs.json.decode(rawResult)
  if result.switched then return "switched" end
  if #result == 0 then return "none" end

  -- Multiple matches — show themed chooser
  local choices = {}
  for _, m in ipairs(result) do
    table.insert(choices, {
      text = m.title,
      subText = m.url,
      windowIndex = m.w,
      tabIndex = m.t,
    })
  end

  local keyMap = {}
  local shortcuts = dynamicMenu:generateShortcuts(#choices)
  for i, choice in ipairs(choices) do
    local key = shortcuts[i]
    if key then
      local wIdx, tIdx = choice.windowIndex, choice.tabIndex
      keyMap[singleKey(key, choice.text)] = {
        action = function()
          hs.osascript.javascript(string.format([[
            (function() {
              const app = Application('%s');
              const win = app.windows()[%d];
              win.activeTabIndex = %d + 1;
              win.index = 1;
              app.activate();
            })();
          ]], browser, wIdx, tIdx))
        end
      }
    end
  end
  spoon.RecursiveBinder.recursiveBind(keyMap, nil, {layout_mode = "vertical"})()
  return "chooser"
end

local function getActionAndLabel(s)
  -- Check for tab: prefix (switch to existing tab, or open if not found)
  if startswith(s, "tab:") then
    local remaining = postfix(s)
    local browserMap = {
      ["canary:"] = "Google Chrome Canary",
      ["chrome:"] = "Google Chrome",
      ["edge:"] = "Microsoft Edge",
    }
    local browser, url
    for prefix, appName in pairs(browserMap) do
      if startswith(remaining, prefix) then
        browser = appName
        url = remaining:sub(#prefix + 1)
        break
      end
    end
    if browser then
      local label = url:find("://") and url:sub(url:find("://") + 3) or url
      local pattern = url:match("://([^/]+)")
      return function()
        local result = switchToBrowserTab(browser, pattern)
        if result == "none" then
          os.execute(string.format("open -a '%s' \"%s\"", browser, url))
        end
        -- "switched" and "chooser" cases handled internally
      end, label, nil
    end
  end

  -- Check for match: prefix first (window-matching behavior)
  if startswith(s, "match:") then
    local remaining = postfix(s)  -- e.g., "canary:https://gemini.google.com/..."

    -- Map browser prefixes to app names
    local browserMap = {
      ["canary:"] = "Google Chrome Canary",
      ["chrome:"] = "Google Chrome",
      ["edge:"] = "Microsoft Edge",
      -- Safari/Firefox have different APIs, skip for now
    }

    -- Find which browser prefix is used
    local browser, url
    for prefix, appName in pairs(browserMap) do
      if startswith(remaining, prefix) then
        browser = appName
        url = remaining:sub(#prefix + 1)
        break
      end
    end

    if browser then
      local label = url:find("://") and url:sub(url:find("://") + 3) or url
      local pattern = url:match("://([^/]+)")  -- Extract domain

      return function()
        if not openInBrowserWindowWithMatch(browser, url, pattern) then
          os.execute(string.format("open -a '%s' \"%s\"", browser, url))
        end
      end, label, nil
    end
    -- If browser not found, fall through to normal handling
  end

  -- Check for browser-specific prefixes
  if startswith(s, "chrome:") then
    local url = postfix(s)
    local label = url:find("://") and url:sub(url:find("://") + 3) or url
    return openInBrowser(url, "Google Chrome"), label, nil
  elseif startswith(s, "canary:") then
    local url = postfix(s)
    local label = url:find("://") and url:sub(url:find("://") + 3) or url
    return openInBrowser(url, "Google Chrome Canary"), label, nil
  elseif startswith(s, "safari:") then
    local url = postfix(s)
    local label = url:find("://") and url:sub(url:find("://") + 3) or url
    return openInBrowser(url, "Safari"), label, nil
  elseif startswith(s, "firefox:") then
    local url = postfix(s)
    local label = url:find("://") and url:sub(url:find("://") + 3) or url
    return openInBrowser(url, "Firefox"), label, nil
  elseif startswith(s, "edge:") then
    local url = postfix(s)
    local label = url:find("://") and url:sub(url:find("://") + 3) or url
    return openInBrowser(url, "Microsoft Edge"), label, nil
  elseif s:find("^http[s]?://") then
    return open(s), s:sub(5, 5) == "s" and s:sub(9) or s:sub(8), nil
  elseif s == "reload" then
    return function()
      hs.reload()
      hs.console.clearConsole()
    end, s, nil
  elseif startswith(s, "raycast://") then
    return raycast(s), s, nil
  elseif startswith(s, "obsidian://") then
    return open(s), s, nil
  elseif startswith(s, "linear://") then
    return open(s), s, nil
  elseif startswith(s, "hs:") then
    return hs_run(postfix(s)), s, nil
  elseif startswith(s, "cmd:") then
    local arg = postfix(s)
    return cmd(arg), arg, nil
  elseif startswith(s, "input:") then
    local remaining = postfix(s)
    local _, label = getActionAndLabel(remaining)
    return function()
      -- user input takes focus and doesn't return it
      local focusedWindow = hs.window.focusedWindow()

      showCustomInputDialog(label or "Enter text:", function(userInput)
        -- restore focus
        focusedWindow:focus()

        if userInput == nil then return end -- User cancelled

        -- Save to history before executing
        saveToHistory(remaining, userInput)

        -- replace text and execute remaining action
        local replaced = string.gsub(remaining, "{input}", userInput)
        local action, _ = getActionAndLabel(replaced)
        action()
      end, remaining)  -- Pass urlTemplate for history
    end, label, nil
  elseif startswith(s, "textarea:") then
    local remaining = postfix(s)
    local _, label = getActionAndLabel(remaining)
    return function()
      -- user input takes focus and doesn't return it
      local focusedWindow = hs.window.focusedWindow()
      
      showCustomTextAreaDialog(label or "Enter multi-line text:", function(userInput)
        -- restore focus
        focusedWindow:focus()
        
        if userInput == nil then return end -- User cancelled
        
        -- replace text and execute remaining action
        local replaced = string.gsub(remaining, "{input}", userInput)
        local action, _ = getActionAndLabel(replaced)
        action()
      end)
    end, label, nil
  elseif startswith(s, "tabsearch:") then
    local pattern = postfix(s)
    return function()
      print("[debug] tabsearch handler running with pattern: " .. pattern)
      local browsers = {
        { name = "Google Chrome", short = "Chrome", bundleID = "com.google.Chrome" },
        { name = "Google Chrome Canary", short = "Canary", bundleID = "com.google.Chrome.canary" },
      }
      local allMatches = {}
      for _, b in ipairs(browsers) do
        if hs.application.get(b.bundleID) then
          print("[debug] searching " .. b.name .. " for: " .. pattern)
          local matches = searchBrowserTabs(b.name, pattern)
          print("[debug] " .. b.name .. " returned " .. #matches .. " matches")
          for _, m in ipairs(matches) do
            table.insert(allMatches, {
              text = m.title,
              subText = string.format("[%s] %s", b.short, m.url),
              browser = b.name,
              windowIndex = m.w,
              tabIndex = m.t,
            })
          end
        else
          print("[debug] skipping " .. b.name .. " (not running)")
        end
      end

      -- Sort by title so matches from both browsers are interleaved
      table.sort(allMatches, function(a, b) return a.text:lower() < b.text:lower() end)

      print("[debug] total matches: " .. #allMatches)
      if #allMatches == 0 then
        hs.alert.show("No tabs found for: " .. pattern)
        return
      end

      if #allMatches == 1 then
        local match = allMatches[1]
        hs.osascript.javascript(string.format([[
          (function() {
            const app = Application('%s');
            const win = app.windows()[%d];
            win.activeTabIndex = %d + 1;
            win.index = 1;
            app.activate();
          })();
        ]], match.browser, match.windowIndex, match.tabIndex))
        return
      end

      print("[debug] creating chooser with " .. #allMatches .. " choices")
      for i, m in ipairs(allMatches) do
        print("[debug]   " .. i .. ": " .. m.text .. " [" .. m.browser .. "]")
      end
      -- Brief delay to let UI settle after input webview teardown
      hs.timer.doAfter(0.1, function()
        local keyMap = {}
        local shortcuts = dynamicMenu:generateShortcuts(#allMatches)
        for i, match in ipairs(allMatches) do
          local key = shortcuts[i]
          if key then
            local bName, wIdx, tIdx = match.browser, match.windowIndex, match.tabIndex
            keyMap[singleKey(key, match.text)] = {
              action = function()
                hs.osascript.javascript(string.format([[
                  (function() {
                    const app = Application('%s');
                    const win = app.windows()[%d];
                    win.activeTabIndex = %d + 1;
                    win.index = 1;
                    app.activate();
                  })();
                ]], bName, wIdx, tIdx))
              end
            }
          end
        end
        spoon.RecursiveBinder.recursiveBind(keyMap, nil, {layout_mode = "vertical"})()
      end)
    end, "Tab Search", nil
  elseif startswith(s, "shortcut:") then
    local arg = postfix(s)
    return keystroke(arg), arg, nil
  elseif startswith(s, "function:") then
    local funcKey = postfix(s)
    return userFunc(funcKey), funcKey .. "()", nil
  elseif startswith(s, "km:") then
    local rest = postfix(s)
    -- Support optional variable passing via query-style syntax:
    -- km:MacroName?var1=value1&var2=value2
    local macroName, query = rest:match("^([^%?]+)%??(.*)$")
    macroName = macroName or rest

    local function runKm()
      if query and #query > 0 then
        -- Build AppleScript to set variables then trigger macro
        local script = 'tell application "Keyboard Maestro Engine"\n'
        -- Support separators '&', ',' or '|' between pairs for convenience
        for pair in string.gmatch(query, "[^&|,]+") do
          local k, v = pair:match("^([^=]+)=(.*)$")
          if k and v then
            -- Escape quotes for AppleScript string literal
            v = tostring(v):gsub('"', '\\"')
            script = script .. string.format('  setvariable "%s" to "%s"\n', k, v)
          end
        end
        script = script .. string.format('  do script "%s"\n', macroName)
        script = script .. 'end tell'
        hs.osascript.applescript(script)
      else
        local kmCmd = string.format('osascript -e \'tell application "Keyboard Maestro Engine" to do script "%s"\'', macroName)
        os.execute(kmCmd .. " &")
      end
    end

    return runKm, "km: " .. macroName, nil
  elseif startswith(s, "code:") then
    local arg = postfix(s)
    return code(arg), "code " .. arg, nil
  elseif startswith(s, "text:") then
    local arg = postfix(s)
    return text(arg), arg, nil
  elseif startswith(s, "dynamic:") then
    local arg = postfix(s)
    -- Parse generator name and optional arguments
    local generatorName, args = arg:match("^([^|]+)|?(.*)$")
    if not generatorName then
      generatorName = arg
      args = nil
    end
    
    -- Create a closure that captures layout options
    local function createDynamicMenu(capturedLayoutOptions)
      return function()
      local generatorCall = args and (generatorName .. "(" .. args .. ")") or generatorName
      local items, err = dynamicMenu:generate(generatorCall)
      if not items or (type(items) == "table" and next(items) == nil) then
        hs.alert("No items found", nil, nil, 2)
        return
      end
      
      -- Convert items to Hammerflow keymap format
      local keyMap = {}
      for k, v in pairs(items) do
        if type(v) == "string" then
          -- Simple string -> launch app
          local action, label, icon = getActionAndLabel(v)
          keyMap[singleKey(k, label)] = {action = action, icon = icon}
        elseif type(v) == "table" then
          if v.action then
            -- Item with custom action
            local action, label, icon
            if type(v.action) == "function" then
              action = v.action
              label = v.label or "Action"
            elseif type(v.action) == "table" and v.action.type == "km" then
              -- Keyboard Maestro action with variables
              action = function()
                -- Build AppleScript to set multiple variables and trigger macro
                local script = 'tell application "Keyboard Maestro Engine"\n'
                if v.action.variables then
                  for varName, varValue in pairs(v.action.variables) do
                    script = script .. string.format('  setvariable "%s" to "%s"\n',
                      varName, tostring(varValue):gsub('"', '\\"'))
                  end
                end
                script = script .. string.format('  do script "%s"\n', v.action.macro)
                script = script .. 'end tell'
                hs.osascript.applescript(script)
              end
              label = v.label or v.action.macro
            else
              action, label, icon = getActionAndLabel(v.action)
              -- If action is a dynamic menu factory, call it to get the actual function
              if type(action) == "function" and type(v.action) == "string" and v.action:find("^dynamic:") then
                action = action(capturedLayoutOptions)
              end
            end
            -- Include sortKey for proper ordering in RecursiveBinder
            keyMap[singleKey(k, v.label or label)] = {action = action, icon = v.icon or icon, sortKey = v.sortKey}
          else
            -- Nested submenu
            keyMap[singleKey(k, v.label or k)] = v
          end
        end
      end
      
        -- Show the dynamic menu with layout options
        spoon.RecursiveBinder.recursiveBind(keyMap, nil, capturedLayoutOptions)()
      end
    end
    return createDynamicMenu, "→ " .. generatorName, nil
  elseif startswith(s, "smartwindow:") then
    -- Smart window action: uses chord prefix for halves/thirds/quarters, or nudge without prefix
    local key = postfix(s)
    return smartWindow(key), s, nil
  elseif startswith(s, "window:") then
    local loc = postfix(s)
    if windowLocations[loc] then
      return windowLocations[loc], s, nil
    else
      -- Parse values, now supporting negative numbers for pixels
      local x, y, w, h = loc:match("^([%-%.%d]+),%s*([%-%.%d]+),%s*([%-%.%d]+),%s*([%-%.%d]+)$")
      if not x then
        hs.alert('Invalid window location: "' .. loc .. '"', nil, nil, 5)
        return
      end
      
      -- Convert string values to numbers
      x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
      
      -- Function to convert pixel values to percentages
      local function convertValue(value, dimension, isPosition)
        -- Values between -1 and 1 are percentages
        if value >= -1 and value <= 1 then
          return value
        end
        
        -- Get screen dimensions
        local screen = hs.screen.mainScreen()
        local screenFrame = screen:frame()
        local screenSize = dimension == "width" and screenFrame.w or screenFrame.h
        
        -- Convert pixels to percentage
        if value < 0 then
          -- Negative pixels: position from right/bottom edge
          if isPosition then
            return 1 + (value / screenSize)  -- e.g., -1000px from right = 1 + (-1000/2560)
          else
            -- For width/height, negative doesn't make sense, treat as positive
            return math.abs(value) / screenSize
          end
        else
          -- Positive pixels: position from left/top edge
          return value / screenSize
        end
      end
      
      -- Convert each value
      x = convertValue(x, "width", true)
      y = convertValue(y, "height", true)
      w = convertValue(w, "width", false)
      h = convertValue(h, "height", false)
      
      return move(rect(x, y, w, h)), s, nil
    end
    return
  else
    return launch(s), s, nil
  end
end

function obj.loadFirstValidTomlFile(paths)
  -- parse TOML file
  local configFile = nil
  local configFileName = ""
  local searchedPaths = {}
  for _, path in ipairs(paths) do
    if not startswith(path, "/") then
      path = hs.configdir .. "/" .. path
    end
    table.insert(searchedPaths, path)
    if file_exists(path) then
      -- Validate TOML structure before parsing
      local success, message = validateTomlStructure(path)
      if not success then
        log.error('config.validate', {file = path, error = message})
      end
      
      local success, result = pcall(function() return toml.parse(path) end)
      if success then
        configFile = result
        configFileName = path
        break
      else
        log.error('config.parse', {file = path, error = tostring(result)})
        hs.notify.show("Hammerflow", "Parse error", path .. "\n" .. tostring(result))
      end
    end
  end
  if not configFile then
    log.error('config.missing', {searched = table.concat(searchedPaths, ', ')})
    hs.alert("No toml config found! Searched for: " .. table.concat(searchedPaths, ', '), 5)
    obj.auto_reload = true
    return
  end
  if obj.setupHTTPEndpoints then
    obj:setupHTTPEndpoints()
  end

  if configFile.leader_key == nil or configFile.leader_key == "" then
    hs.alert("You must set leader_key at the top of " .. configFileName .. ". Exiting.", 5)
    return
  end

  -- settings
  local leader_key = configFile.leader_key or "f18"
  local leader_key_mods = configFile.leader_key_mods or ""
  if configFile.auto_reload == nil or configFile.auto_reload then
    obj.auto_reload = true
  end
  if configFile.toast_on_reload == true then
    hs.alert('🔁 Reloaded config')
  end
  if configFile.show_ui == false then
    spoon.RecursiveBinder.showBindHelper = false
  end
  
  -- Set display mode (default to webview)
  local display_mode = configFile.display_mode or "webview"
  spoon.RecursiveBinder.displayMode = display_mode

  -- Tile layout configuration
  local tileColumns = configFile.tile_columns or 3
  spoon.RecursiveBinder.tileColumns = tileColumns

  spoon.RecursiveBinder.helperFormat = {
    atScreenEdge = 0,
    strokeColor = { white = 0, alpha = 0.8 },
    fillColor = { white = 0, alpha = 0.8 },
    textColor = { red = 0, green = 1, blue = 0, alpha = 1 },
    textFont = 'Menlo',
    textSize = 48,
    radius = 8,
    padding = 16
  }

  -- Grid layout configuration
  local maxCols = configFile.max_grid_columns or 5
  local gridSpacing = configFile.grid_spacing or " | "
  local gridSeparator = configFile.grid_separator or " : "
  local layoutMode = configFile.layout_mode or "horizontal"
  local maxColumnHeight = configFile.max_column_height or 15

  -- Background configuration
  local backgroundConfig = configFile.background or {}
  local backgroundImage = backgroundConfig.image or nil
  local backgroundOpacity = backgroundConfig.opacity or 0.6
  local backgroundPosition = backgroundConfig.position or "center center"
  local backgroundSize = backgroundConfig.size or "cover"
  local backgroundType = backgroundConfig.type or nil
  local backgroundTemplate = backgroundConfig.template or nil

  -- Pass to RecursiveBinder
  spoon.RecursiveBinder.maxColumns = maxCols
  spoon.RecursiveBinder.gridSpacing = gridSpacing
  spoon.RecursiveBinder.gridSeparator = gridSeparator
  spoon.RecursiveBinder.layoutMode = layoutMode
  spoon.RecursiveBinder.maxColumnHeight = maxColumnHeight
  spoon.RecursiveBinder.backgroundImage = backgroundImage
  spoon.RecursiveBinder.backgroundOpacity = backgroundOpacity
  spoon.RecursiveBinder.backgroundPosition = backgroundPosition
  spoon.RecursiveBinder.backgroundSize = backgroundSize
  spoon.RecursiveBinder.backgroundType = backgroundType
  spoon.RecursiveBinder.backgroundTemplate = backgroundTemplate

  -- clear settings from table so we don't have to account
  -- for them in the recursive processing function
  configFile.leader_key = nil
  configFile.leader_key_mods = nil
  configFile.auto_reload = nil
  configFile.toast_on_reload = nil
  configFile.show_ui = nil
  configFile.display_mode = nil
  configFile.tile_columns = nil
  configFile.max_grid_columns = nil
  configFile.grid_spacing = nil
  configFile.grid_separator = nil
  configFile.layout_mode = nil
  configFile.max_column_height = nil
  configFile.background = nil

  local function parseKeyMap(config)
    local keyMap = {}
    local conditionalActions = nil
    
    for k, v in pairs(config) do
      if k == "label" then
        -- continue
      elseif k == "icon" then
        -- continue
      elseif k == "layout_mode" or k == "max_column_height" or
             k == "max_grid_columns" or k == "entry_length" or
             k == "display_mode" or k == "tile_columns" or
             k == "background_image" or k == "background_opacity" or
             k == "background_position" or k == "background_size" then
        -- skip layout, display, and background configuration properties
      elseif k == "apps" then
        for shortName, app in pairs(v) do
          obj._apps[shortName] = app
        end
      elseif string.find(k, "_") then
        -- Check if this is a sort key (prefix + single char) or conditional
        local prefix, suffix = k:match("^(.+)_(.+)$")
        if prefix and suffix and #suffix == 1 then
          -- This is a sort key like "01_w" or "z_k"
          local displayKey = suffix  -- "w" or "k"
          local sortKey = k          -- "01_w" or "z_k"
          
          -- Process the value same as regular keys
          if type(v) == "string" then
            local action, label, icon = getActionAndLabel(v)
            keyMap[singleKey(displayKey, label)] = {action = action, icon = icon, sortKey = sortKey}
          elseif type(v) == "table" and v[1] then
            local action, defaultLabel, icon = getActionAndLabel(v[1])
            local customIcon = v[3] or icon
            local layoutOptions = v[4] or {}
            -- If action is a dynamic menu factory, call it with layout options
            if type(action) == "function" and v[1]:find("^dynamic:") then
              action = action(layoutOptions)
            end
            keyMap[singleKey(displayKey, v[2] or defaultLabel)] = {action = action, icon = customIcon, sortKey = sortKey, layoutOptions = layoutOptions}
          else
            -- Nested submenu with prefix (like "z_." or "y_/")
            local layoutOptions = {}

            -- Extract layout properties from flat TOML structure
            if v.layout_mode then layoutOptions.layout_mode = v.layout_mode end
            if v.max_column_height then layoutOptions.max_column_height = v.max_column_height end
            if v.max_grid_columns then layoutOptions.max_grid_columns = v.max_grid_columns end
            if v.entry_length then layoutOptions.entry_length = v.entry_length end
            if v.display_mode then layoutOptions.display_mode = v.display_mode end
            if v.tile_columns then layoutOptions.tile_columns = v.tile_columns end

            -- Chord prefix system properties
            if v.chord_enabled then layoutOptions.chord_enabled = v.chord_enabled end
            if v.chord_timeout then layoutOptions.chord_timeout = v.chord_timeout end
            if v.chord_prefix_keys then layoutOptions.chord_prefix_keys = v.chord_prefix_keys end

            -- Handle background properties
            if v.background_image or v.background_opacity or v.background_position or v.background_size then
              layoutOptions.background = {}
              if v.background_image then layoutOptions.background.image = v.background_image end
              if v.background_opacity then layoutOptions.background.opacity = v.background_opacity end
              if v.background_position then layoutOptions.background.position = v.background_position end
              if v.background_size then layoutOptions.background.size = v.background_size end
            end

            keyMap[singleKey(displayKey, v.label or displayKey)] = {keyMap = parseKeyMap(v), icon = v.icon, sortKey = k, layoutOptions = layoutOptions}
          end
        else
          -- This is a conditional like "w_chrome"
          local key = k:sub(1, 1)
          local cond = k:sub(3)
          if conditionalActions == nil then conditionalActions = {} end
          local actionString = v
          if type(v) == "table" then
            actionString = v[1]
          end
          -- Only process if actionString is valid (not nil and not a table)
          if actionString and type(actionString) ~= "table" then
            if conditionalActions[key] then
              conditionalActions[key][cond] = getActionAndLabel(tostring(actionString))
            else
              conditionalActions[key] = { [cond] = getActionAndLabel(tostring(actionString)) }
            end
          end
        end
      elseif type(v) == "string" then
        local action, label, icon = getActionAndLabel(v)
        keyMap[singleKey(k, label)] = {action = action, icon = icon, sortKey = k}
      elseif type(v) == "table" and v[1] then
        local action, defaultLabel, icon = getActionAndLabel(v[1])
        local customIcon = v[3] or icon
        local layoutOptions = v[4] or {}
        -- If action is a dynamic menu factory, call it with layout options
        if type(action) == "function" and v[1]:find("^dynamic:") then
          action = action(layoutOptions)
        end
        -- Special handling for input: actions to use custom label in dialog
        if type(action) == "function" and v[1]:find("^input:") and v[2] then
          local customLabel = v[2]
          local urlTemplate = postfix(v[1])  -- Extract URL template once for history
          local originalAction = action
          action = function()
            print("[debug] input override action triggered for: " .. customLabel)
            -- user input takes focus and doesn't return it
            local focusedWindow = hs.window.focusedWindow()

            showCustomInputDialog(customLabel, function(userInput)
              -- restore focus
              if focusedWindow then focusedWindow:focus() end

              if userInput == nil then return end -- User cancelled

              -- Save to history before executing
              saveToHistory(urlTemplate, userInput)

              -- replace text and execute remaining action
              local replaced = string.gsub(urlTemplate, "{input}", userInput)
              print("[debug] input callback: replaced = " .. replaced)
              local action, _ = getActionAndLabel(replaced)
              print("[debug] input callback: action type = " .. type(action))
              action()
            end, urlTemplate)  -- Pass urlTemplate for history loading
          end
        end
        -- Special handling for textarea: actions to use custom label in dialog
        if type(action) == "function" and v[1]:find("^textarea:") and v[2] then
          local customLabel = v[2]
          local originalAction = action
          action = function()
            -- user input takes focus and doesn't return it
            local focusedWindow = hs.window.focusedWindow()
            
            showCustomTextAreaDialog(customLabel, function(userInput)
              -- restore focus
              focusedWindow:focus()
              
              if userInput == nil then return end -- User cancelled
              
              -- replace text and execute remaining action
              local remaining = postfix(v[1])
              local replaced = string.gsub(remaining, "{input}", userInput)
              local action, _ = getActionAndLabel(replaced)
              action()
            end)
          end
        end
        keyMap[singleKey(k, v[2] or defaultLabel)] = {action = action, icon = customIcon, sortKey = k, layoutOptions = layoutOptions}
      else
        -- Check if this is a section-based dynamic menu (has 'action' property)
        if v.action then
          local action, defaultLabel, icon = getActionAndLabel(tostring(v.action))
          local customIcon = v.icon or icon
          local layoutOptions = {}

          -- Extract layout properties from flat TOML structure
          if v.layout_mode then layoutOptions.layout_mode = v.layout_mode end
          if v.max_column_height then layoutOptions.max_column_height = v.max_column_height end
          if v.max_grid_columns then layoutOptions.max_grid_columns = v.max_grid_columns end
          if v.entry_length then layoutOptions.entry_length = v.entry_length end
          if v.display_mode then layoutOptions.display_mode = v.display_mode end
          if v.tile_columns then layoutOptions.tile_columns = v.tile_columns end

          -- Chord prefix system properties
          if v.chord_enabled then layoutOptions.chord_enabled = v.chord_enabled end
          if v.chord_timeout then layoutOptions.chord_timeout = v.chord_timeout end
          if v.chord_prefix_keys then layoutOptions.chord_prefix_keys = v.chord_prefix_keys end

          -- Handle background properties
          if v.background_image or v.background_opacity or v.background_position or v.background_size then
            layoutOptions.background = {}
            if v.background_image then layoutOptions.background.image = v.background_image end
            if v.background_opacity then layoutOptions.background.opacity = v.background_opacity end
            if v.background_position then layoutOptions.background.position = v.background_position end
            if v.background_size then layoutOptions.background.size = v.background_size end
          end

          -- If action is a dynamic menu factory, call it with layout options
          if type(action) == "function" and tostring(v.action):find("^dynamic:") then
            action = action(layoutOptions)
          end

          keyMap[singleKey(k, v.label or defaultLabel)] = {action = action, icon = customIcon, sortKey = k, layoutOptions = layoutOptions}
        else
          -- Regular submenu processing
          local nestedKeyMap = parseKeyMap(v)
          local layoutOptions = {}
          local groupLabel = v.label

          -- Extract layout properties from flat TOML structure
          if v.layout_mode then layoutOptions.layout_mode = v.layout_mode end
          if v.max_column_height then layoutOptions.max_column_height = v.max_column_height end
          if v.max_grid_columns then layoutOptions.max_grid_columns = v.max_grid_columns end
          if v.entry_length then layoutOptions.entry_length = v.entry_length end
          if v.display_mode then layoutOptions.display_mode = v.display_mode end
          if v.tile_columns then layoutOptions.tile_columns = v.tile_columns end

          -- Chord prefix system properties
          if v.chord_enabled then layoutOptions.chord_enabled = v.chord_enabled end
          if v.chord_timeout then layoutOptions.chord_timeout = v.chord_timeout end
          if v.chord_prefix_keys then layoutOptions.chord_prefix_keys = v.chord_prefix_keys end

          -- Handle background properties
          if v.background_image or v.background_opacity or v.background_position or v.background_size then
            layoutOptions.background = {}
            if v.background_image then layoutOptions.background.image = v.background_image end
            if v.background_opacity then layoutOptions.background.opacity = v.background_opacity end
            if v.background_position then layoutOptions.background.position = v.background_position end
            if v.background_size then layoutOptions.background.size = v.background_size end
          end

          -- Check if group label is in array format with layout options (backward compatibility)
          if type(v.label) == "table" and v.label[1] then
            groupLabel = v.label[1]  -- Extract the actual label
            local arrayLayoutOptions = v.label[4] or {}
            -- Merge array layout options with flat ones (flat takes precedence)
            for key, value in pairs(arrayLayoutOptions) do
              if layoutOptions[key] == nil then
                layoutOptions[key] = value
              end
            end
          end
          
          keyMap[singleKey(k, groupLabel or k)] = {keyMap = nestedKeyMap, icon = v.icon, sortKey = k, layoutOptions = layoutOptions}
        end
      end
    end

    -- parse labels and default action for conditional actions
    local conditionalLabels = {}
    if conditionalActions ~= nil then
      -- get the default action if it exists
      for key_, value_ in pairs(keyMap) do
        if conditionalActions[key_[2]] then
          conditionalActions[key_[2]]["_"] = value_
          keyMap[key_] = nil
          conditionalLabels[key_[2]] = key_[3]
        end
      end
      -- add conditionalActions to keyMap
      for key_, value_ in pairs(conditionalActions) do
        keyMap[singleKey(key_, conditionalLabels[key_] or "conditional")] = {
          action = function()
            local fallback = true
            for cond, fn in pairs(value_) do
              if (obj._userFunctions[cond] and obj._userFunctions[cond]())
                  or (obj._userFunctions[cond] == nil and isApp(cond)())
              then
                fn()
                fallback = false
                break
              end
            end
            if fallback and value_["_"] then
              value_["_"]()
            end
          end,
          icon = nil
        }
      end
    end

    -- add apps to userFunctions if there isn't a function with the same name
    for k, v in pairs(obj._apps) do
      if obj._userFunctions[k] == nil then
        obj._userFunctions[k] = isApp(v)
      end
    end

    return keyMap
  end

  -- Note: TOML parsing validation cannot be done on the parsed table since
  -- Lua tables don't preserve order. The TOML parser will already ignore
  -- keys defined after table sections, so we rely on the documentation
  -- to guide users on proper TOML structure.

  local keys = parseKeyMap(configFile)
  hs.hotkey.bind(leader_key_mods, leader_key, spoon.RecursiveBinder.recursiveBind(keys, nil, nil))

  -- Initialize URL handler with the parsed keymap
  urlHandler = UrlHandler:init(getActionAndLabel)
  urlHandler:buildIndex(keys, "")
  obj._urlHandler = urlHandler
  log.info('url.ready', {message = 'URL handler initialized'})
end

function obj.registerFunctions(...)
  for _, funcs in pairs({ ... }) do
    for k, v in pairs(funcs) do
      obj._userFunctions[k] = v
    end
  end
end

-- Expose DynamicMenu for custom generators
obj.dynamicMenu = dynamicMenu

return obj
