# Case Study: Dynamic Cursor Window Switcher

This case study demonstrates how to create a dynamic menu in Jammerflow that integrates with external applications and automation tools. We'll build a window switcher for the Cursor editor that passes selected window names to Keyboard Maestro.

## The Challenge

Cursor (the AI-powered code editor) can have multiple project windows open simultaneously. Switching between them requires clicking through the Window menu or using macOS's window management. We want a faster keyboard-driven solution that:

1. Shows all open Cursor windows in a dynamic menu
2. Assigns automatic keyboard shortcuts (a, b, c, etc.)
3. Triggers a Keyboard Maestro macro with the selected window name

## The Solution

### Step 1: Create the Dynamic Menu Generator

We created a new generator file `DynamicMenu/generators/cursor.lua`:

```lua
-- DynamicMenu/generators/cursor.lua
return function(args)
  local items = {}
  
  -- Use AppleScript to get window names from System Events
  local ok, result = hs.osascript.applescript([[
    tell application "System Events"
      set cursorWindows to name of windows of application process "Cursor"
    end tell
  ]])
  
  if ok and result then
    for _, windowName in ipairs(result) do
      table.insert(items, {
        label = windowName,
        icon = "cursor.png",
        action = {
          type = "km",
          macro = "CursorWindows",
          variables = {
            CursorWindowName = windowName
          }
        end
      })
    end
  end
  
  return items
end)
```

### Step 2: Configure in TOML

Add to your `config.toml`:

```toml
"3" = "dynamic:cursor"  # Press 3 to show Cursor windows
```

### Step 3: Create the Keyboard Maestro Macro

Create a macro named "CursorWindows" in Keyboard Maestro that:
1. Reads the `CursorWindowName` variable
2. Performs actions based on the window name

Example KM macro actions:
- Display text: `Switching to: %Variable%CursorWindowName%`
- Activate Cursor
- Use AppleScript to focus the specific window

## How It Works

1. **Modular Architecture**: The generator lives in `DynamicMenu/generators/cursor.lua`
2. **Data Collection**: AppleScript queries System Events for Cursor's window titles
3. **Dynamic Menu Generation**: Jammerflow creates menu items with auto-assigned shortcuts
4. **Rich Action Format**: Uses the new `{type: "km", macro: "...", variables: {...}}` format
5. **Selection Handling**: When selected, Jammerflow automatically sets KM variables and triggers the macro
6. **No Caching**: The cursor generator always fetches fresh data for real-time accuracy

## Key Techniques

### Escaping Special Characters
The code escapes quotes in window names to prevent AppleScript errors:
```lua
windowName:gsub('"', '\\"')
```

### Keyboard Maestro Integration
Two-way communication with KM:
- **Set Variable**: `setvariable "CursorWindowName" to "value"`
- **Trigger Macro**: `do script "MacroName"`

### Using Variables in KM
- In text fields: `%Variable%CursorWindowName%`
- In shell scripts: `$KMVAR_CursorWindowName`
- In AppleScript: `getvariable "CursorWindowName"`

## Extending the Concept

This pattern can be adapted for:

1. **VS Code Projects**: List recent workspaces
2. **Browser Tabs**: Show open tabs across windows
3. **Git Branches**: Quick branch switching
4. **Docker Containers**: List and manage containers
5. **Database Connections**: Quick connect to saved databases

### Example: VS Code Workspace Switcher

```lua
obj:registerGenerator("vscodeWorkspaces", function()
  -- Read recent workspaces from VS Code's storage
  local storageFile = os.getenv("HOME") .. 
    "/Library/Application Support/Code/storage.json"
  -- Parse and return workspace list
end)
```

## Benefits

1. **Speed**: Keyboard-driven switching is faster than mouse navigation
2. **Integration**: Combines Hammerspoon's UI with KM's automation power
3. **Flexibility**: Easy to extend for other applications
4. **Context**: Can add additional info (file paths, git status, etc.)

## Troubleshooting

**Windows not showing up?**
- Ensure Cursor is running
- Check System Events permissions in System Preferences > Privacy

**Keyboard Maestro not triggering?**
- Verify macro name matches exactly
- Check KM Engine is running
- Test variable passing with a simple display text action

**Special characters in window names?**
- The gsub pattern handles quotes
- Add more escaping for other special characters if needed

## Conclusion

This case study shows how Jammerflow's dynamic menus can bridge different automation tools, creating powerful workflows that adapt to your current context. The combination of Hammerspoon's UI capabilities, AppleScript's system access, and Keyboard Maestro's automation features creates a flexible and extensible system.