--- === UrlHandler ===
---
--- External URL scheme handler for Jammerflow
--- Enables triggering actions via hammerspoon://hammerflow URLs
---
--- Usage:
---   hammerspoon://hammerflow?action=Safari
---   hammerspoon://hammerflow?action=chrome:https://google.com
---   hammerspoon://hammerflow?key=l.g
---   hammerspoon://hammerflow?label=Calendar
---   hammerspoon://hammerflow?action=chrome:https://google.com/search%3Fq%3D{input}&query=test

local UrlHandler = {}
UrlHandler.__index = UrlHandler

-- URL decode helper (handles %XX encoding and + for spaces)
local function urlDecode(str)
    if not str then return nil end
    -- Replace + with space first
    str = str:gsub("+", " ")
    -- Then decode %XX sequences
    str = str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return str
end

-- Lookup indices built from config
UrlHandler._keyPathIndex = {}  -- "l.g" -> action function
UrlHandler._labelIndex = {}    -- "google search" -> action function
UrlHandler._getActionAndLabel = nil  -- Reference to main action parser

-- Setup logging
local ok, logx = pcall(require, 'logx')
local log
if ok then
    log = logx.new('hammerflow.url', 'info')
else
    local logger = hs.logger.new('HF-URL', 'info')
    log = {
        debug = function(event, ctx) logger.d(event) end,
        info = function(event, ctx) logger.i(event) end,
        warn = function(event, ctx) logger.w(event) end,
        error = function(event, ctx) logger.e(event) end,
    }
end

--- UrlHandler:init(getActionAndLabel)
--- Initialize with reference to the action parser function
function UrlHandler:init(getActionAndLabel)
    local instance = setmetatable({}, UrlHandler)
    instance._getActionAndLabel = getActionAndLabel
    instance._keyPathIndex = {}
    instance._labelIndex = {}
    return instance
end

--- UrlHandler:buildIndex(keymap, path)
--- Recursively build lookup indices from parsed keymap
function UrlHandler:buildIndex(keymap, path)
    path = path or ""

    for key, binding in pairs(keymap) do
        -- key is {modifiers, keyChar, label} from singleKey()
        local keyChar = key[2]
        local label = key[3]
        local newPath = path == "" and keyChar or (path .. "." .. keyChar)

        -- Normalize label for lookup
        local normalizedLabel = nil
        if label and type(label) == "string" then
            -- Remove brackets from submenu labels like "[linear]"
            normalizedLabel = label:lower():gsub("^%[", ""):gsub("%]$", "")
        end

        if type(binding) == "table" then
            if binding.action then
                -- Leaf node with action
                self._keyPathIndex[newPath] = binding.action
                if normalizedLabel then
                    self._labelIndex[normalizedLabel] = binding.action
                end
            end
            if binding.keyMap then
                -- Nested submenu - recurse
                self:buildIndex(binding.keyMap, newPath)
            end
        elseif type(binding) == "function" then
            -- Direct function binding
            self._keyPathIndex[newPath] = binding
            if normalizedLabel then
                self._labelIndex[normalizedLabel] = binding
            end
        end
    end

    -- Only log at root level
    if path == "" then
        local keyCount, labelCount = 0, 0
        for _ in pairs(self._keyPathIndex) do keyCount = keyCount + 1 end
        for _ in pairs(self._labelIndex) do labelCount = labelCount + 1 end
        log.info('url.index', {keyPaths = keyCount, labels = labelCount})
    end
end

--- UrlHandler:lookupByKeyPath(keyPath)
--- Find action by dot-separated key path (e.g., "l.g")
function UrlHandler:lookupByKeyPath(keyPath)
    if not keyPath then return nil, "No key path provided" end

    local action = self._keyPathIndex[keyPath]
    if action then
        return action, keyPath
    end

    return nil, "Key path not found: " .. keyPath
end

--- UrlHandler:lookupByLabel(searchLabel)
--- Find action by label (case-insensitive, supports partial match)
function UrlHandler:lookupByLabel(searchLabel)
    if not searchLabel then return nil, "No label provided" end

    local normalized = searchLabel:lower()

    -- Exact match first
    if self._labelIndex[normalized] then
        return self._labelIndex[normalized], normalized
    end

    -- Partial match fallback
    for label, action in pairs(self._labelIndex) do
        if label:find(normalized, 1, true) then
            return action, label
        end
    end

    return nil, "Label not found: " .. searchLabel
end

--- UrlHandler:executeRawAction(actionString, query)
--- Execute a raw action string with optional query substitution
function UrlHandler:executeRawAction(actionString, query)
    if not actionString then return nil, "No action string provided" end

    -- Decode URL-encoded characters
    actionString = urlDecode(actionString) or actionString

    -- Substitute {input} placeholder if query provided
    if query then
        query = urlDecode(query) or query
        actionString = actionString:gsub("{input}", query)
    end

    -- Use the main action processor
    if self._getActionAndLabel then
        local action, label = self._getActionAndLabel(actionString)
        if action then
            return action, label or actionString
        end
    end

    return nil, "Failed to parse action: " .. actionString
end

--- UrlHandler:handleUrlEvent(eventName, params)
--- Main URL event dispatcher
function UrlHandler:handleUrlEvent(eventName, params)
    local silent = params.silent == "true"
    local query = params.query

    local function reportError(message)
        log.error('url.error', {message = message, params = params})
        if not silent then
            hs.alert("Jammerflow: " .. message, 3)
        end
    end

    local function reportSuccess(label)
        log.info('url.success', {label = label})
    end

    -- Dispatch based on parameter type
    local action, label, err

    if params.key then
        -- Key path lookup: "l.g"
        local decodedKey = urlDecode(params.key) or params.key
        action, label = self:lookupByKeyPath(decodedKey)
        if not action then
            return reportError("Key path not found: " .. params.key)
        end

    elseif params.label then
        -- Label lookup: "Google Search"
        local decodedLabel = urlDecode(params.label) or params.label
        action, label = self:lookupByLabel(decodedLabel)
        if not action then
            return reportError("Label not found: " .. params.label)
        end

    elseif params.action then
        -- Raw action string
        action, label = self:executeRawAction(params.action, query)
        if not action then
            return reportError("Invalid action: " .. params.action)
        end

    else
        return reportError("No action, key, or label parameter provided")
    end

    -- Execute the action
    local success, execErr = pcall(action)
    if success then
        reportSuccess(label)
    else
        reportError("Execution failed: " .. tostring(execErr))
    end
end

return UrlHandler
