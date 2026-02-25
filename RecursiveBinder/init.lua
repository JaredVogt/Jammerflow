--- === RecursiveBinder ===
---
--- A spoon that let you bind sequential bindings.
--- It also (optionally) shows a bar about current keys bindings.
---
--- [Click to download](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RecursiveBinder.spoon.zip)

local obj={}
obj.__index = obj


-- Metadata
obj.name = "RecursiveBinder"
obj.version = "0.7"
obj.author = "Yuan Fu <casouri@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"


--- RecursiveBinder.escapeKey
--- Variable
--- key to abort, default to {keyNone, 'escape'}
obj.escapeKey = {keyNone, 'escape'}

--- RecursiveBinder.helperEntryEachLine
--- Variable
--- Number of entries each line of helper. Default to 5.
obj.helperEntryEachLine = 5

--- RecursiveBinder.helperEntryLengthInChar
--- Variable
--- Length of each entry in char. Default to 80.
obj.helperEntryLengthInChar = 80

--- RecursiveBinder.helperFormat
--- Variable
--- format of helper, the helper is just a hs.alert
--- default to {atScreenEdge=2,
---             strokeColor={ white = 0, alpha = 2 },
---             textFont='SF Mono'
---             textSize=20}
obj.helperFormat = {atScreenEdge=2,
                    strokeColor={ white = 0, alpha = 2 },
                    textFont='Courier',
                    textSize=20}

--- RecursiveBinder.showBindHelper()
--- Variable
--- whether to show helper, can be true of false
obj.showBindHelper = true

--- RecursiveBinder.displayMode
--- Variable
--- Display mode for the helper: "webview", "text", or "tiles"
--- Default to "webview"
obj.displayMode = "webview"

--- RecursiveBinder.tileColumns
--- Variable
--- Number of columns for tile display mode
--- Default to 3
obj.tileColumns = 3

--- RecursiveBinder.helperModifierMapping()
--- Variable
--- The mapping used to display modifiers on helper.
--- Default to {
---  command = '⌘',
---  control = '⌃',
---  option = '⌥',
---  shift = '⇧',
--- }
obj.helperModifierMapping = {
   command = '⌘',
   control = '⌃',
   option = '⌥',
   shift = '⇧',
}

-- used by next model to close previous helper
local previousHelperID = nil

-- track if modal is currently active for toggle functionality
local modalActive = false

-- webview for grid display
local gridWebview = nil

-- eventtap for tile mode keyboard handling (since we skip modal in tile mode)
local tileEventtap = nil

-- Chord prefix state for numeric prefix sequences (e.g., 2h = left-half, 4hk = top-left)
local chordState = {
    prefix = "",           -- numeric prefix ("2", "3", "4", "")
    partialDirection = "", -- for quarters: first direction key ("h", "l", "")
    timer = nil,           -- timeout timer
    enabled = false,       -- whether chord mode is active for current menu
    timeout = 4.0          -- timeout in seconds
}

-- Clear chord state
local function clearChordState()
    chordState.prefix = ""
    chordState.partialDirection = ""
    if chordState.timer then
        chordState.timer:stop()
        chordState.timer = nil
    end
end

-- Start/reset timeout timer
local function resetChordTimer()
    if chordState.timer then chordState.timer:stop() end
    chordState.timer = hs.timer.doAfter(chordState.timeout, function()
        clearChordState()
        -- Timer expired, prefix cleared silently
    end)
end

-- Get current chord state for action handlers
function obj.getChordState()
    return {
        prefix = chordState.prefix,
        partialDirection = chordState.partialDirection
    }
end

-- Check if a key is a direction key for smartwindow (used for nudge persistence)
local function isSmartWindowDirectionKey(keyChar)
    local directionKeys = {h = true, j = true, k = true, l = true, t = true, b = true}
    return directionKeys[keyChar] == true
end

-- this function is used by helper to display 
-- appropriate 'shift + key' bindings
-- it turns a lower key to the corresponding
-- upper key on keyboard
local function keyboardUpper(key)
   local upperTable = {
    a='A', 
    b='B', 
    c='C', 
    d='D', 
    e='E', 
    f='F', 
    g='G', 
    h='H', 
    i='I', 
    j='J', 
    k='K', 
    l='L', 
    m='M', 
    n='N', 
    o='O', 
    p='P', 
    q='Q', 
    r='R', 
    s='S', 
    t='T', 
    u='U', 
    v='V', 
    w='W', 
    x='X', 
    y='Y', 
    z='Z', 
    ['`']='~',
    ['1']='!',
    ['2']='@',
    ['3']='#',
    ['4']='$',
    ['5']='%',
    ['6']='^',
    ['7']='&',
    ['8']='*',
    ['9']='(',
    ['0']=')',
    ['-']='_',
    ['=']='+',
    ['[']='}',
    [']']='}',
    ['\\']='|',
    [';']=':',
    ['\'']='"',
    [',']='<',
    ['.']='>',
    ['/']='?'
   }
   uppperKey = upperTable[key]
   if uppperKey then
      return uppperKey
   else
      return key
   end
end

--- RecursiveBinder.singleKey(key, name)
--- Method
--- this function simply return a table with empty modifiers also it translates capital letters to normal letter with shift modifer
---
--- Parameters:
---  * key - a letter
---  * name - the description to pass to the keys binding function
---
--- Returns:
---  * a table of modifiers and keys and names, ready to be used in keymap
---    to pass to RecursiveBinder.recursiveBind()
function obj.singleKey(key, name)
   local mod = {}
   if key == keyboardUpper(key) and string.len(key) == 1 then
      mod = {'shift'}
      key = string.lower(key)
   end

   if name then
      return {mod, key, name}
   else
      return {mod, key, 'no name'}
   end
end


-- generate a string representation of a key spec
-- {{'shift', 'command'}, 'a} -> 'shift+command+a'
local function createKeyName(key)
   -- key is in the form {{modifers}, key, (optional) name}
   -- create proper key name for helper
   local modifierTable = key[1]
   local keyString = key[2]
   -- add a little mapping for space
   if keyString == 'space' then keyString = 'SPC' end
   -- If it's a single letter with only shift modifier, show as uppercase
   if #modifierTable == 1 and modifierTable[1] == 'shift' and string.len(keyString) == 1 then
      -- shift + key map to Uppercase key
      -- shift + d --> D
      return keyboardUpper(keyString)
   else
      -- append each modifiers together
      local keyName = ''
      if #modifierTable >= 1 then
         for count = 1, #modifierTable do
            local modifier = modifierTable[count]
            if count == 1 then
               keyName = obj.helperModifierMapping[modifier]..' + '
            else 
               keyName = keyName..obj.helperModifierMapping[modifier]..' + '
            end
         end
      end
      -- finally append key, e.g. 'f', after modifers
      return keyName..keyString
   end
end

-- Function to compare two letters
-- It sorts according to the ASCII code, and for letters, it will be alphabetical
-- However, for capital letters (65-90), I'm adding 32.5 (this came from 97 - 65 + 0.5, where 97 is a and 65 is A) to the ASCII code before comparing
-- This way, each capital letter comes after the corresponding simple letter but before letters that come after it in the alphabetical order
local function compareLetters(a, b)
   local asciiA = string.byte(a)
   local asciiB = string.byte(b)
   if asciiA >= 65 and asciiA <= 90 then
       asciiA = asciiA + 32.5
   end
   if asciiB >= 65 and asciiB <= 90 then
       asciiB = asciiB + 32.5
   end
   return asciiA < asciiB
end

-- format bindings as grid layout
local function formatBindingsAsGrid(keymap)
  local MAX_COLS = obj.maxColumns or 7
  local KEY_LABEL_SEP = obj.gridSeparator or " : "
  local COL_SPACING = obj.gridSpacing or "   "
  local items = {}
  
  -- Collect and sort items
  for key, binding in pairs(keymap) do
    -- Based on Hammerflow's singleKey structure: key = {mode, keyChar, label}
    local keyChar = key[2] or "?"
    -- Check if this is an uppercase key (shift modifier with single lowercase letter)
    if #key[1] == 1 and key[1][1] == 'shift' and string.len(keyChar) == 1 then
       keyChar = string.upper(keyChar)
    end
    local label = key[3] or keyChar
    -- Handle array format labels like ["[searches]", "", "", {layout_mode = "vertical"}]
    if type(label) == "table" and label[1] then
      label = label[1]  -- Extract the actual label from array format
    end
    local icon = nil
    if type(binding) == "table" and binding.icon then
      icon = binding.icon
    end
    table.insert(items, {key = keyChar, label = label, icon = icon})
  end
  
  -- Sort alphabetically by key
  table.sort(items, function(a, b) return a.key < b.key end)
  
  if #items == 0 then return "" end
  
  -- Calculate grid dimensions
  local numCols = math.min(#items, MAX_COLS)
  local numRows = math.ceil(#items / numCols)
  
  -- Create grid structure and calculate column widths
  local grid = {}
  local colWidths = {}
  
  -- Initialize column widths
  for col = 1, numCols do
    colWidths[col] = 0
  end
  
  -- Fill grid and find max width per column
  for row = 1, numRows do
    grid[row] = {}
    for col = 1, numCols do
      local itemIndex = (row - 1) * numCols + col
      if itemIndex <= #items then
        local item = items[itemIndex]
        local cellContent = item.key .. KEY_LABEL_SEP .. item.label
        grid[row][col] = cellContent
        
        -- Update column width if this entry is wider
        colWidths[col] = math.max(colWidths[col], string.len(cellContent))
      else
        grid[row][col] = nil -- Empty cell
      end
    end
  end
  
  -- Build final formatted rows
  local rows = {}
  for row = 1, numRows do
    local rowItems = {}
    for col = 1, numCols do
      if grid[row][col] then
        -- Left-align and pad to column width
        local padded = grid[row][col] .. string.rep(" ", colWidths[col] - string.len(grid[row][col]))
        table.insert(rowItems, padded)
      else
        -- Empty cell - maintain alignment
        table.insert(rowItems, string.rep(" ", colWidths[col]))
      end
    end
    table.insert(rows, table.concat(rowItems, COL_SPACING))
  end
  
  return table.concat(rows, "\n")
end

-- show helper of available keys of current layer
local function showHelper(keyFuncNameTable, keyFuncSortTable, layoutOptions)
   -- keyFuncNameTable is a table that key is key name and value is description
   -- keyFuncSortTable is a table that maps key names to sort keys
   -- layoutOptions contains display configuration including entry_length
   layoutOptions = layoutOptions or {}
   local entryLength = layoutOptions.entry_length or obj.helperEntryLengthInChar
   local helper = ''
   local separator = '' -- first loop doesn't need to add a separator, because it is in the very front. 
   local lastLine = ''
   local count = 0

   local sortedKeyFuncNameTable = {}
   for keyName, funcName in pairs(keyFuncNameTable) do
       local sortKey = keyFuncSortTable and keyFuncSortTable[keyName] or keyName
       table.insert(sortedKeyFuncNameTable, {keyName = keyName, funcName = funcName, sortKey = sortKey})
   end
   
   -- Sort by sortKey if available, otherwise use compareLetters for backward compatibility
   if keyFuncSortTable then
      table.sort(sortedKeyFuncNameTable, function(a, b) return a.sortKey < b.sortKey end)
   else
      table.sort(sortedKeyFuncNameTable, function(a, b) return compareLetters(a.keyName, b.keyName) end)
   end

   for _, value in ipairs(sortedKeyFuncNameTable) do
      local keyName = value.keyName
      local funcName = value.funcName
      count = count + 1
      local newEntry = keyName..' → '..funcName
      -- make sure each entry is of the same length
      if string.len(newEntry) > entryLength then
         newEntry = string.sub(newEntry, 1, entryLength - 2)..'..'
      elseif string.len(newEntry) < entryLength then
         newEntry = newEntry..string.rep(' ', entryLength - string.len(newEntry))
      end
      -- create new line for every helperEntryEachLine entries
      if count % (obj.helperEntryEachLine + 1) == 0 then
         separator = '\n '
      elseif count == 1 then
         separator = ' '
      else
         separator = '  '
      end
      helper = helper..separator..newEntry
   end
   helper = string.match(helper, '[^\n].+$')
   previousHelperID = hs.alert.show(helper, obj.helperFormat, true)
end

local function killHelper()
   hs.alert.closeSpecific(previousHelperID)
   if gridWebview then
      gridWebview:delete()
      gridWebview = nil
   end
   -- Also stop tile eventtap if active
   if tileEventtap then
      tileEventtap:stop()
      tileEventtap = nil
   end
end

-- Auto-assign hotkeys alphabetically (for tile mode)
local function autoAssignHotkeys(items)
    -- Sort alphabetically by label (case-insensitive)
    table.sort(items, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    local usedKeys = {}
    for _, item in ipairs(items) do
        local letters = item.label:lower():gsub("[^a-z]", "")
        local assignedKey = nil

        -- Try first letter, then subsequent letters from the name
        for i = 1, #letters do
            local char = letters:sub(i, i)
            if not usedKeys[char] then
                assignedKey = char
                usedKeys[char] = true
                break
            end
        end

        -- Fallback to any available a-z
        if not assignedKey then
            for i = 97, 122 do
                local char = string.char(i)
                if not usedKeys[char] then
                    assignedKey = char
                    usedKeys[char] = true
                    break
                end
            end
        end

        item.key = assignedKey or "?"
    end
    return items
end

-- Load image as base64 data URL
local function loadImageAsBase64(imagePath)
    local fullPath = imagePath

    -- If not absolute path, look in Hammerflow images directory
    if not imagePath:match("^/") then
        fullPath = hs.configdir .. "/Spoons/Hammerflow.spoon/images/" .. imagePath
    end

    local file = io.open(fullPath, "rb")
    if not file then return nil end

    local imageData = file:read("*all")
    file:close()

    if not imageData or #imageData == 0 then return nil end

    local base64 = hs.base64.encode(imageData)
    local extension = imagePath:match("%.(%w+)$")
    if extension then
        extension = extension:lower()
        local mimeType = "image/jpeg"
        if extension == "png" then
            mimeType = "image/png"
        elseif extension == "gif" then
            mimeType = "image/gif"
        elseif extension == "webp" then
            mimeType = "image/webp"
        elseif extension == "svg" then
            mimeType = "image/svg+xml"
        end
        return "data:" .. mimeType .. ";base64," .. base64
    end
    return nil
end

-- Find tile background image for an item
local function findTileBackground(itemLabel, configBackground)
    -- Use explicit config first
    if configBackground then
        return loadImageAsBase64(configBackground)
    end

    -- Search project directory for images
    local home = os.getenv("HOME")
    local normalizedName = itemLabel:lower():gsub("%s+", "-"):gsub("[^a-z0-9%-]", "")
    local projectPath = home .. "/projects/" .. normalizedName

    -- Check if project directory exists
    local attr = hs.fs.attributes(projectPath)
    if not attr or attr.mode ~= "directory" then
        return nil
    end

    -- Look for any .png file in project root
    for file in hs.fs.dir(projectPath) do
        if file:match("%.png$") then
            return loadImageAsBase64(projectPath .. "/" .. file)
        end
    end

    return nil
end

-- Highlight the hotkey letter within the name
local function highlightHotkeyInName(name, hotkey)
    local lowerName = name:lower()
    local lowerKey = hotkey:lower()
    local index = lowerName:find(lowerKey, 1, true)

    if not index then
        return name  -- Key not found in name
    end

    -- Build HTML with highlighted letter
    local before = name:sub(1, index - 1)
    local letter = name:sub(index, index)
    local after = name:sub(index + 1)

    return before .. '<span class="highlight">' .. letter .. '</span>' .. after
end

-- create webview grid display
local function showWebviewGrid(keymap, layoutOptions)
   -- Close existing webview if present
   if gridWebview then
      gridWebview:delete()
   end
   
   -- Use passed layout options or fall back to global settings
   layoutOptions = layoutOptions or {}
   local MAX_COLS = layoutOptions.max_grid_columns or obj.maxColumns or 7
   local LAYOUT_MODE = layoutOptions.layout_mode or obj.layoutMode or "horizontal"
   local MAX_COL_HEIGHT = layoutOptions.max_column_height or obj.maxColumnHeight or 15
   local ENTRY_LENGTH = layoutOptions.entry_length or obj.helperEntryLengthInChar or 80
   local items = {}
   
   -- Collect and sort items
   for key, binding in pairs(keymap) do
      local keyChar = key[2] or "?"
      -- Check if this is an uppercase key (shift modifier with single lowercase letter)
      if #key[1] == 1 and key[1][1] == 'shift' and string.len(keyChar) == 1 then
         keyChar = string.upper(keyChar)
      end
      local label = key[3] or keyChar
      -- Handle array format labels like ["[searches]", "", "", {layout_mode = "vertical"}]
      if type(label) == "table" and label[1] then
        label = label[1]  -- Extract the actual label from array format
      end
      local icon = nil
      local sortKey = keyChar  -- default to the display key
      
      if type(binding) == "table" then
        if binding.icon then
          icon = binding.icon
        end
        if binding.sortKey then
          sortKey = binding.sortKey  -- use explicit sort key if provided
        end
      end
      
      table.insert(items, {
        key = keyChar, 
        label = label, 
        icon = icon,
        sortKey = sortKey  -- add sort key to item
      })
   end
   
   -- Sort by sortKey instead of key (case-insensitive, lowercase before uppercase)
   table.sort(items, function(a, b)
      local aLower = a.sortKey:lower()
      local bLower = b.sortKey:lower()
      if aLower == bLower then
         return a.sortKey > b.sortKey  -- same letter: lowercase before uppercase
      end
      return aLower < bLower
   end)
   
   if #items == 0 then return end
   
   -- Find the longest label and check for icons to calculate dynamic width
   local maxLabelLength = 0
   local hasIcons = false
   for _, item in ipairs(items) do
      local fullText = item.key .. " : " .. item.label
      -- Truncate label if the full text exceeds entry length limit
      if string.len(fullText) > ENTRY_LENGTH then
         local maxLabelLen = ENTRY_LENGTH - string.len(item.key .. " : ") - 2
         if maxLabelLen > 0 then
            item.label = string.sub(item.label, 1, maxLabelLen) .. ".."
         else
            item.label = ".."  -- fallback for very long keys
         end
         fullText = item.key .. " : " .. item.label
      end
      maxLabelLength = math.max(maxLabelLength, string.len(fullText))
      if item.icon then
         hasIcons = true
      end
   end
   
   -- Calculate grid dimensions
   local numCols, numRows
   if LAYOUT_MODE == "vertical" then
      -- For vertical layout, rows are limited and columns expand
      numRows = math.min(#items, MAX_COL_HEIGHT)
      numCols = math.ceil(#items / numRows)
   else
      -- For horizontal layout (default), columns are limited and rows expand
      numCols = math.min(#items, MAX_COLS)
      numRows = math.ceil(#items / numCols)
   end
   
   -- Generate HTML
   local html = [[
   <!DOCTYPE html>
   <html>
   <head>
       <style>
           html, body {
               background: transparent !important;
               background-color: transparent !important;
           }
           body {
               font-family: 'Menlo', monospace;
               font-size: 48px;
               margin: 0;
               padding: 20px;
               color: white;
               overflow: hidden;
           }
           .grid-container {
               display: grid;
               ]] .. (LAYOUT_MODE == "vertical" and 
                  "grid-auto-flow: column;\n               grid-template-rows: repeat(" .. numRows .. ", 1fr);" or
                  "grid-template-columns: repeat(" .. numCols .. ", 1fr);") .. [[
               gap: ]] .. (LAYOUT_MODE == "vertical" and "20px 40px" or "30px 60px") .. [[;
               justify-items: start;
               align-items: center;
               background-color: rgba(0, 0, 0, 0.6);
               border-radius: 12px;
               padding: 20px;
               border: 5px solid #00ff00;
               box-sizing: border-box;
               position: relative;
               overflow: hidden;
           }
           .grid-container::before {
               content: '';
               position: absolute;
               top: 0;
               left: 0;
               right: 0;
               bottom: 0;
               background-image: url('BACKGROUND_IMAGE_URL');
               background-position: BACKGROUND_POSITION;
               background-size: BACKGROUND_SIZE;
               background-repeat: no-repeat;
               opacity: BACKGROUND_OPACITY;
               z-index: -1;
               border-radius: 12px;
           }
           .grid-cell {
               display: flex;
               align-items: center;
               white-space: nowrap;
               cursor: pointer;
               padding: 8px 12px;
               border-radius: 8px;
               transition: all 0.2s ease;
               background: transparent;
           }
           .icon {
               width: 48px;
               height: 48px;
               margin-right: 12px;
               object-fit: contain;
           }
           .grid-cell:hover {
               background: rgba(255, 255, 255, 0.1);
               transform: scale(1.05);
           }
           .key {
               color: #00ff00;
               font-weight: bold;
               text-shadow: 0 0 10px #00ff00;
           }
           .separator {
               color: #888;
               margin: 0 8px;
           }
           .label {
               color: #ffffff;
           }
       </style>
   </head>
   <body>
       <div class="grid-container">
   ]]
   
   -- Load background image using config settings
   local backgroundImageData = "none"
   local inyoBackground = ""
   -- Use per-menu background settings if available, otherwise fall back to global settings
   local backgroundConfig = layoutOptions and layoutOptions.background or {}
   local backgroundOpacity = backgroundConfig.opacity or obj.backgroundOpacity or 0.6
   local backgroundPosition = backgroundConfig.position or obj.backgroundPosition or "center center"
   local backgroundSize = backgroundConfig.size or obj.backgroundSize or "cover"
   -- Determine what type of background this menu wants (explicit decision tree)
   local hasLocalType = backgroundConfig.type ~= nil
   local hasLocalImage = backgroundConfig.image ~= nil

   local useInyo = false
   local backgroundImage = backgroundConfig.image or obj.backgroundImage
   local backgroundType, backgroundTemplate

   if hasLocalType then
      -- Menu explicitly sets type - use that
      useInyo = (backgroundConfig.type == "inyo")
      backgroundType = backgroundConfig.type
      backgroundTemplate = backgroundConfig.template
   elseif hasLocalImage then
      -- Menu has image but no type - use image mode
      useInyo = false
      backgroundType = nil
      backgroundTemplate = nil
   else
      -- Menu has neither - inherit global settings
      useInyo = (obj.backgroundType == "inyo")
      backgroundType = obj.backgroundType
      backgroundTemplate = obj.backgroundTemplate
   end

   -- Only load Inyo if we're actually going to use it (performance fix)
   if useInyo and backgroundTemplate then
      local home = os.getenv("HOME")
      local inyoTemplatePath = home .. "/.hammerspoon/Spoons/Inyo.spoon/templates/" .. backgroundTemplate .. ".html"
      local inyoFile = io.open(inyoTemplatePath, "r")
      if inyoFile then
         local inyoContent = inyoFile:read("*all")
         inyoFile:close()

         -- Extract the p5.js script and styles from jellyfish template
         local inyoStyles = inyoContent:match("<style>(.-)</style>")
         local inyoScript = inyoContent:match("<script>(.-)</script>")

         if inyoStyles and inyoScript then
            -- Modify styles to work as background layer
            inyoStyles = inyoStyles:gsub("html, body", "#inyo-background")
            inyoStyles = inyoStyles:gsub("body", "#inyo-background")

            -- Keep the original script but apply opacity via CSS instead

            inyoBackground = string.format([[
               <div id="inyo-background" style="position: absolute; top: 0; left: 0; width: 100%%; height: 100%%; z-index: -2; border-radius: 12px; overflow: hidden;">
                  <div id="p5-container" style="position: absolute; top: 0; left: 0; width: 100%%; height: 100%%; z-index: 1;"></div>
               </div>
               <style>
                  #inyo-background {
                     pointer-events: none;
                     background: transparent;
                  }
                  #p5-container {
                     opacity: %s;
                  }
                  #p5-container canvas {
                     width: 100%% !important;
                     height: 100%% !important;
                     border-radius: 12px;
                  }
                  %s
               </style>
               <script src="https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.7.0/p5.min.js"></script>
               <script>
                  %s
               </script>
            ]], tostring(backgroundOpacity),
                inyoStyles or "",
                inyoScript or "")
         end
      end
   end

   -- Only load image background if not using Inyo (performance + logic fix)
   if not useInyo and backgroundImage then
         -- Use cached base64 data for performance
         if not obj.backgroundCache then
            obj.backgroundCache = {}
         end

         if obj.backgroundCache[backgroundImage] then
            backgroundImageData = obj.backgroundCache[backgroundImage]
         else
            local backgroundPath = hs.configdir .. "/Spoons/Hammerflow.spoon/images/" .. backgroundImage
            local bgFile = io.open(backgroundPath, "rb")
            if bgFile then
               local imageData = bgFile:read("*all")
               bgFile:close()
               local base64 = hs.base64.encode(imageData)

               -- Get proper MIME type
               local extension = backgroundImage:match("%.(%w+)$"):lower()
               local mimeType = "image/jpeg" -- default
               if extension == "png" then
                  mimeType = "image/png"
               elseif extension == "gif" then
                  mimeType = "image/gif"
               elseif extension == "webp" then
                  mimeType = "image/webp"
               end

               backgroundImageData = "data:" .. mimeType .. ";base64," .. base64
               obj.backgroundCache[backgroundImage] = backgroundImageData
            end
         end
   elseif not useInyo then
      -- No specific image configured and not using Inyo - try default filenames
      if not obj.backgroundCache then
         obj.backgroundCache = {}
      end

      local backgroundFormats = {"background.gif", "background.png", "background.jpg", "background.jpeg", "background.webp"}

      for _, filename in ipairs(backgroundFormats) do
         if obj.backgroundCache[filename] then
            backgroundImageData = obj.backgroundCache[filename]
            break
         else
            local backgroundPath = hs.configdir .. "/Spoons/Hammerflow.spoon/images/" .. filename
            local bgFile = io.open(backgroundPath, "rb")
            if bgFile then
               local imageData = bgFile:read("*all")
               bgFile:close()
               local base64 = hs.base64.encode(imageData)

               -- Get proper MIME type
               local extension = filename:match("%.(%w+)$"):lower()
               local mimeType = "image/jpeg" -- default
               if extension == "png" then
                  mimeType = "image/png"
               elseif extension == "gif" then
                  mimeType = "image/gif"
               elseif extension == "webp" then
                  mimeType = "image/webp"
               end

               backgroundImageData = "data:" .. mimeType .. ";base64," .. base64
               obj.backgroundCache[filename] = backgroundImageData
               break -- Use the first one found
            end
         end
      end
   end
   
   -- Replace placeholders with actual background settings
   html = html:gsub("BACKGROUND_IMAGE_URL", backgroundImageData)
   html = html:gsub("BACKGROUND_POSITION", backgroundPosition)
   html = html:gsub("BACKGROUND_SIZE", backgroundSize)
   html = html:gsub("BACKGROUND_OPACITY", tostring(backgroundOpacity))

   -- Add Inyo background inside grid-container if available
   if inyoBackground and inyoBackground ~= "" then
      html = html .. inyoBackground
   end

   -- Add grid items
   for i, item in ipairs(items) do
      local iconHtml = ""
      local iconToUse = item.icon or "generic.png"  -- Fallback to generic.png for consistent alignment
      local iconFilePath = hs.configdir .. "/Spoons/Hammerflow.spoon/images/" .. iconToUse
         
         -- Try to read and encode image as base64
         local file = io.open(iconFilePath, "rb")
         if file then
            local imageData = file:read("*all")
            file:close()
            if imageData and #imageData > 0 then
               local base64 = hs.base64.encode(imageData)
               local extension = iconToUse:match("%.(%w+)$")
               if extension then
                  extension = extension:lower()
                  local mimeType = "image/jpeg" -- default
                  if extension == "png" then
                     mimeType = "image/png"
                  elseif extension == "gif" then
                     mimeType = "image/gif"
                  elseif extension == "webp" then
                     mimeType = "image/webp"
                  elseif extension == "svg" then
                     mimeType = "image/svg+xml"
                  end
                  iconHtml = string.format('<img src="data:%s;base64,%s" class="icon">', mimeType, base64)
               end
            else
               print("Could not read image file: " .. iconFilePath)
            end
         else
            print("Could not open image file: " .. iconFilePath)
         end
      html = html .. string.format([[
           <div class="grid-cell" onclick="executeAction('%s')">
               %s<span class="key">%s</span>
               <span class="separator">:</span>
               <span class="label">%s</span>
           </div>
      ]], item.key, iconHtml, item.key, item.label)
   end
   
   html = html .. [[
       </div>
       <script>
           function executeAction(key) {
               window.location.href = 'hammerflow://key/' + key;
           }

           // Close on escape key
           document.addEventListener('keydown', function(e) {
               if (e.key === 'Escape') {
                   window.close();
               } else {
                   executeAction(e.key);
               }
           });

           // Auto-focus for keyboard events
           window.focus();
       </script>
   </body>
   </html>
   ]]
   
   -- Create webview
   local screen = hs.screen.mainScreen()
   local screenFrame = screen:frame()
   
   -- Calculate size based on content - ensure it fits everything
   local baseCharWidth = 29  -- Character width for Menlo 48px font (approx 0.6 * font size)
   local iconWidth = hasIcons and 60 or 0  -- 48px icon + 12px margin if icons present
   local cssHorizontalPadding = 40  -- 20px padding on each side of grid-cell
   local cellWidth = math.max(300, maxLabelLength * baseCharWidth + cssHorizontalPadding + iconWidth + 40)  -- Extra buffer for safety
   local cellHeight = LAYOUT_MODE == "vertical" and 80 or 100  -- Slightly smaller cells for vertical layout
   local padding = 60     -- Padding around content
   local gapWidth = LAYOUT_MODE == "vertical" and 50 or 80    -- Smaller gap between columns in vertical mode
   local gapHeight = LAYOUT_MODE == "vertical" and 20 or 40   -- Smaller gap between rows in vertical mode
   
   local webviewWidth = (numCols * cellWidth) + ((numCols - 1) * gapWidth) + (padding * 2)
   local webviewHeight = (numRows * cellHeight) + ((numRows - 1) * gapHeight) + (padding * 2)
   
   -- Ensure it doesn't exceed screen bounds, but allow wider windows for longer entries
   webviewWidth = math.min(webviewWidth, screenFrame.w * 0.98)  -- Increased from 0.95 to 0.98
   webviewHeight = math.min(webviewHeight, screenFrame.h * 0.9)
   
   local webviewFrame = {
      x = screenFrame.x + (screenFrame.w - webviewWidth) / 2,
      y = screenFrame.y + (screenFrame.h - webviewHeight) / 2,
      w = webviewWidth,
      h = webviewHeight
   }
   
   gridWebview = hs.webview.new(webviewFrame)
      :windowStyle({"borderless"})
      :allowTextEntry(true)
      :level(hs.drawing.windowLevels.overlay)
      :transparent(true)
      :html(html)
      :show()
      :bringToFront(true)
   
   -- Set up keyboard event handler using windowCallback
   gridWebview:windowCallback(function(action, webview, ...)
      if action == "closing" then
         modalActive = false
      end
   end)
   
   -- Set up navigation to handle key presses via URL changes
   gridWebview:navigationCallback(function(action, webview, navID, url)
      if action == "didReceiveServerRedirect" or action == "didCommit" then
         local keyPressed = url:match("hammerflow://key/(.)")
         if keyPressed then
            gridWebview:delete()
            gridWebview = nil
            modalActive = false
            
            -- Find and execute the corresponding action
            for key, binding in pairs(keymap) do
               if key[2] == keyPressed then
                  local modal = hs.hotkey.modal.new()
                  local actionBinding = binding
                  local childLayoutOptions = nil
                  if type(binding) == "table" then
                     if binding.action then
                        actionBinding = binding.action
                     end
                     if binding.layoutOptions then
                        childLayoutOptions = binding.layoutOptions
                     end
                  end
                  local func = obj.recursiveBind(actionBinding, {modal}, childLayoutOptions)
                  func()
                  break
               end
            end
            return false  -- Don't actually navigate
         end
      end
      return true
   end)
end

-- create tile-based webview display
local function showTileWebview(keymap, layoutOptions)
   -- Close existing webview if present
   if gridWebview then
      gridWebview:delete()
   end

   -- Set modalActive so toggle behavior works (leader key closes menu)
   modalActive = true

   layoutOptions = layoutOptions or {}
   local TILE_COLUMNS = layoutOptions.tile_columns or obj.tileColumns or 3
   local items = {}

   -- Collect items from keymap
   for key, binding in pairs(keymap) do
      local keyChar = key[2] or "?"
      if #key[1] == 1 and key[1][1] == 'shift' and string.len(keyChar) == 1 then
         keyChar = string.upper(keyChar)
      end
      local label = key[3] or keyChar
      if type(label) == "table" and label[1] then
         label = label[1]
      end

      local tileImage = nil
      local originalKey = keyChar  -- preserve original for action lookup
      if type(binding) == "table" then
         if binding.tile_image then
            tileImage = binding.tile_image
         end
      end

      table.insert(items, {
         label = label,
         tileImage = tileImage,
         originalKey = originalKey,
         binding = binding
      })
   end

   if #items == 0 then return end

   -- Auto-assign hotkeys alphabetically
   items = autoAssignHotkeys(items)

   -- Calculate grid dimensions (column-first flow)
   local numCols = math.min(#items, TILE_COLUMNS)
   local numRows = math.ceil(#items / numCols)

   -- Generate HTML
   local html = [[
   <!DOCTYPE html>
   <html>
   <head>
       <style>
           html, body {
               background: transparent !important;
               margin: 0;
               padding: 0;
           }
           body {
               font-family: 'SF Pro Display', 'Helvetica Neue', sans-serif;
               padding: 20px;
               overflow: hidden;
           }
           .grid-container {
               display: grid;
               grid-template-rows: repeat(]] .. numRows .. [[, 1fr);
               grid-auto-flow: column;
               grid-auto-columns: minmax(280px, 1fr);
               gap: 16px;
               background-color: rgba(0, 0, 0, 0.85);
               border-radius: 16px;
               padding: 24px;
               border: 2px solid #374151;
           }
           .tile {
               display: flex;
               height: 120px;
               border-radius: 12px;
               overflow: hidden;
               border: 1px solid #374151;
               background: #111827;
               position: relative;
               cursor: pointer;
               transition: all 0.2s ease;
           }
           .tile:hover {
               transform: scale(1.03);
               border-color: #f87171;
               box-shadow: 0 10px 40px rgba(239, 68, 68, 0.3);
           }
           .hotkey-section {
               width: 15%;
               min-width: 50px;
               display: flex;
               align-items: center;
               justify-content: center;
               font-family: 'SF Mono', 'Menlo', monospace;
               font-size: 2.5rem;
               font-weight: bold;
               color: #ef4444;
               background: rgba(0, 0, 0, 0.4);
               border-right: 1px solid #374151;
               text-shadow: 0 0 20px rgba(239, 68, 68, 0.5);
           }
           .name-section {
               flex: 1;
               display: block;
               line-height: 120px;
               font-size: 1.4rem;
               font-weight: 600;
               color: #4ade80;
               padding: 0 20px;
               text-align: center;
               z-index: 1;
               overflow: hidden;
               text-overflow: ellipsis;
               white-space: nowrap;
           }
           .name-section .highlight {
               color: #ef4444;
               text-shadow: 0 0 10px rgba(239, 68, 68, 0.5);
           }
           .tile-background {
               position: absolute;
               top: 0;
               left: 15%;
               right: 0;
               bottom: 0;
               z-index: 0;
               opacity: 0.15;
               background-size: cover;
               background-position: center;
               pointer-events: none;
           }
           .tile:hover .name-section {
               color: #86efac;
           }
           .tile:hover .hotkey-section {
               color: #fca5a5;
               background: rgba(239, 68, 68, 0.2);
           }
       </style>
   </head>
   <body>
       <div class="grid-container">
   ]]

   -- Add tiles
   for _, item in ipairs(items) do
      local backgroundImage = findTileBackground(item.label, item.tileImage)
      local backgroundStyle = ""
      if backgroundImage then
         backgroundStyle = string.format("background-image: url('%s');", backgroundImage)
      end

      local highlightedName = highlightHotkeyInName(item.label, item.key)

      html = html .. string.format([[
           <div class="tile" onclick="executeAction('%s')">
               <div class="hotkey-section">%s</div>
               <div class="name-section">%s</div>
               <div class="tile-background" style="%s"></div>
           </div>
      ]], item.key, item.key, highlightedName, backgroundStyle)
   end

   html = html .. [[
       </div>
       <script>
           function executeAction(key) {
               window.location.href = 'hammerflow://key/' + key;
           }
           // Note: Keyboard events are handled by hs.eventtap in Lua
           // since hs.webview doesn't reliably receive keyboard focus
       </script>
   </body>
   </html>
   ]]

   -- Create webview
   local screen = hs.screen.mainScreen()
   local screenFrame = screen:frame()

   local tileWidth = 300
   local tileHeight = 120
   local gap = 16
   local padding = 120  -- body(40) + grid-container(48) + border(4) + buffer

   local webviewWidth = (numCols * tileWidth) + ((numCols - 1) * gap) + padding
   local webviewHeight = (numRows * tileHeight) + ((numRows - 1) * gap) + padding

   webviewWidth = math.min(webviewWidth, screenFrame.w * 0.95)
   webviewHeight = math.min(webviewHeight, screenFrame.h * 0.9)

   local webviewFrame = {
      x = screenFrame.x + (screenFrame.w - webviewWidth) / 2,
      y = screenFrame.y + (screenFrame.h - webviewHeight) / 2,
      w = webviewWidth,
      h = webviewHeight
   }

   gridWebview = hs.webview.new(webviewFrame)
      :windowStyle({"borderless"})
      :allowTextEntry(true)
      :level(hs.drawing.windowLevels.overlay)
      :transparent(true)
      :html(html)
      :show()
      :bringToFront(true)

   -- Build lookup table for auto-assigned keys to original bindings
   local keyToItem = {}
   for _, item in ipairs(items) do
      keyToItem[item.key] = item
   end

   -- Helper function to close tile view and clean up
   local function closeTileView()
      if tileEventtap then
         tileEventtap:stop()
         tileEventtap = nil
      end
      if gridWebview then
         gridWebview:delete()
         gridWebview = nil
      end
      modalActive = false
   end

   -- Handle window closing (e.g., clicking outside)
   gridWebview:windowCallback(function(action, webview, ...)
      if action == "closing" then
         closeTileView()
      end
   end)

   -- Handle click actions via navigation callback
   gridWebview:navigationCallback(function(action, webview, navID, url)
      if action == "didReceiveServerRedirect" or action == "didCommit" then
         local keyPressed = url:match("hammerflow://key/(.)")
         if keyPressed then
            closeTileView()

            -- Find the item by auto-assigned key
            local item = keyToItem[keyPressed]
            if item then
               -- Handle direct function binding (from dynamic menus)
               if type(item.binding) == "function" then
                  item.binding()
               elseif type(item.binding) == "table" then
                  if type(item.binding.action) == "function" then
                     -- Direct action function
                     item.binding.action()
                  elseif item.binding.keyMap then
                     -- Nested submenu
                     local modal = hs.hotkey.modal.new()
                     local func = obj.recursiveBind(item.binding.keyMap, {modal}, item.binding.layoutOptions)
                     func()
                  else
                     -- Fallback to recursiveBind
                     local modal = hs.hotkey.modal.new()
                     local func = obj.recursiveBind(item.binding, {modal}, item.binding.layoutOptions)
                     func()
                  end
               end
            end
            return false
         end
      end
      return true
   end)

   -- Use eventtap for keyboard handling since webview doesn't reliably receive focus
   tileEventtap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
      local keyPressed = event:getCharacters()

      -- Handle escape to close
      if event:getKeyCode() == hs.keycodes.map["escape"] then
         closeTileView()
         return true  -- consume the event
      end

      -- Find the item by auto-assigned key
      local item = keyToItem[keyPressed]
      if item then
         closeTileView()

         -- Handle direct function binding (from dynamic menus)
         if type(item.binding) == "function" then
            item.binding()
         elseif type(item.binding) == "table" then
            if type(item.binding.action) == "function" then
               -- Direct action function
               item.binding.action()
            elseif item.binding.keyMap then
               -- Nested submenu
               local modal = hs.hotkey.modal.new()
               local func = obj.recursiveBind(item.binding.keyMap, {modal}, item.binding.layoutOptions)
               func()
            else
               -- Fallback to recursiveBind
               local modal = hs.hotkey.modal.new()
               local func = obj.recursiveBind(item.binding, {modal}, item.binding.layoutOptions)
               func()
            end
         end
         return true  -- consume the event
      end

      return false  -- let other keys pass through
   end)
   tileEventtap:start()
end

--- RecursiveBinder.recursiveBind(keymap)
--- Method
--- Bind sequential keys by a nested keymap.
---
--- Parameters:
---  * keymap - A table that specifies the mapping.
---
--- Returns:
---  * A function to start. Bind it to a initial key binding.
---
--- Note:
--- Spec of keymap:
--- Every key is of format {{modifers}, key, (optional) description}
--- The first two element is what you usually pass into a hs.hotkey.bind() function.
--- 
--- Each value of key can be in two form:
--- 1. A function. Then pressing the key invokes the function
--- 2. A table. Then pressing the key bring to another layer of keybindings.
---    And the table have the same format of top table: keys to keys, value to table or function

-- the actual binding function
function obj.recursiveBind(keymap, modals, layoutOptions)
   if not modals then modals = {} end
   if type(keymap) == 'function' then
      -- in this case "keymap" is actuall a function
      return keymap
   end
   local modal = hs.hotkey.modal.new()
   table.insert(modals, modal)
   local keyFuncNameTable = {}
   local keyFuncSortTable = {}  -- For sorting in text mode

   -- Check if chord mode is enabled for this menu
   local chordEnabled = layoutOptions and layoutOptions.chord_enabled or false
   local chordTimeout = layoutOptions and layoutOptions.chord_timeout or 4.0

   -- Bind escape key once for this modal (also clears chord state)
   modal:bind(obj.escapeKey[1], obj.escapeKey[2], function()
      clearChordState()
      modal:exit()
      killHelper()
      modalActive = false
   end)

   -- If chord mode is enabled, bind prefix keys as collectors
   -- Default to numbers 0-9, but can be customized via chord_prefix_keys
   if chordEnabled then
      local prefixKeys = layoutOptions and layoutOptions.chord_prefix_keys or {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
      for _, prefixKey in ipairs(prefixKeys) do
         modal:bind({}, prefixKey, function()
            chordState.enabled = true
            chordState.timeout = chordTimeout
            chordState.prefix = chordState.prefix .. prefixKey
            resetChordTimer()
            -- Don't exit modal, don't call action - just collect the prefix
         end)
      end
   end

   for key, map in pairs(keymap) do
      local actualMap = map
      local sortKey = nil
      local childLayoutOptions = nil
      local isChordAware = false  -- Track if this action expects chord state
      if type(map) == "table" then
         if map.action then
            actualMap = map.action
         elseif map.keyMap then
            actualMap = map.keyMap
         end
         if map.sortKey then
            sortKey = map.sortKey
         end
         if map.layoutOptions then
            childLayoutOptions = map.layoutOptions
         end
         if map.chordAware then
            isChordAware = true
         end
      end
      local func = obj.recursiveBind(actualMap, modals, childLayoutOptions)
      -- key[1] is modifiers, i.e. {'shift'}, key[2] is key, i.e. 'f'

      if chordEnabled then
         -- Chord-enabled modal: special handling for direction keys and prefixes
         modal:bind(key[1], key[2], function()
            local state = obj.getChordState()
            local keyChar = key[2]

            -- Note: Quadrant sequences (4hk, 4lj, etc.) removed in favor of horizontal quarters (4h, 4j, 4k, 4l)

            -- Check if this is a nudge (no prefix) on a direction key - stay in modal
            if state.prefix == "" and isSmartWindowDirectionKey(keyChar) then
               -- Execute nudge but stay in modal for repeated nudges
               func(state)
               resetChordTimer()
               return  -- Don't exit modal
            end

            -- Normal execution with chord state
            modal:exit()
            killHelper()
            modalActive = false
            func(state)
            clearChordState()
         end)
      else
         -- Standard modal: original behavior
         modal:bind(key[1], key[2], function() modal:exit() killHelper() modalActive = false func() end)
      end

      if #key >= 3 then
         local keyName = createKeyName(key)
         keyFuncNameTable[keyName] = key[3]
         keyFuncSortTable[keyName] = sortKey or keyName  -- Use sortKey if available, otherwise keyName
      end
   end
   return function()
      -- Toggle behavior: if modal is active, close it; if inactive, open it
      if modalActive then
         -- Close the modal
         modal:exit()
         killHelper()
         modalActive = false
      else
         -- Check per-menu display_mode override first, then fall back to global
         local displayMode = (layoutOptions and layoutOptions.display_mode) or obj.displayMode

         -- exit all modals, accounts for pressing the leader key while in a modal
         for _, m in ipairs(modals) do
            m:exit()
         end

         if displayMode == "tiles" then
            -- Tile mode: skip modal bindings, webview handles all keyboard input
            -- The tile view auto-assigns keys that differ from the original keymap,
            -- so modal hotkeys would trigger wrong actions. Let webview handle it.
            killHelper()
            showTileWebview(keymap, layoutOptions)
         else
            -- Normal modes: use modal for keyboard handling
            modal:enter()
            modalActive = true
            killHelper()
            if obj.showBindHelper then
               if displayMode == "text" then
                  showHelper(keyFuncNameTable, keyFuncSortTable, layoutOptions)
               else
                  showWebviewGrid(keymap, layoutOptions)
               end
            end
         end
      end
   end
end


-- function testrecursiveModal(keymap)
--    print(keymap)
--    if type(keymap) == 'number' then
--       return keymap
--    end
--    print('make new modal')
--    for key, map in pairs(keymap) do
--       print('key', key, 'map', testrecursiveModal(map))
--    end
--    return 0
-- end

-- mymap = {f = { r = 1, m = 2}, s = {r = 3, m = 4}, m = 5}
-- testrecursiveModal(mymap)


return obj
