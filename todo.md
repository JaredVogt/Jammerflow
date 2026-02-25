# Hammerflow Enhancement Ideas

## Enhancement #1: Automatic Shortcut Key Highlighting

### Problem
Currently, to highlight a shortcut key in a menu label (like the 'G' in "Google Meet"), users must manually add HTML span tags:
```toml
g = ["km:Google_meet", "<span style='font-weight: bold; color: red'>G</span>oogle Meet", "google_meet.png"]
```

This creates:
- Code duplication (the 'g' appears both as the key and in the label)
- Manual HTML maintenance burden
- Inconsistent formatting across entries

### Solution
Automatically detect when the shortcut key appears in the label text and highlight the first occurrence in red.

### Implementation Strategy

**Phase 1: Core Logic**
- Create a `highlightShortcutInLabel(key, label)` function
- Check if `key` appears in `label` (case-insensitive)
- If found, wrap first occurrence with `<span style='font-weight: bold; color: red'>` tags
- Handle edge cases:
  - Multiple occurrences (only highlight first)
  - Already formatted labels (detect existing span tags)
  - Special characters in keys

**Phase 2: Integration**
- Modify `RecursiveBinder/init.lua` around line 628-634
- Apply highlighting before inserting `item.label` into HTML
- Ensure it works with existing manual formatting

**Phase 3: Configuration**
- Add `auto_highlight_shortcuts = true` config option
- Make highlight color configurable: `shortcut_highlight_color = "#ff0000"`
- Allow disabling per-item via special prefix

### Code Locations
- **Primary:** `RecursiveBinder/init.lua:632` where `item.label` is inserted into HTML
- **Config:** `init.lua` where config options are parsed (around line 687)

### Example Transformation
**Before:**
```toml
g = ["km:Google_meet", "<span style='font-weight: bold; color: red'>G</span>oogle Meet", "google_meet.png"]
c = ["Calendar", "Calendar", "calendar.webp"]
p = ["Claude", "Claude", "claude.png"]
```

**After:**
```toml
g = ["km:Google_meet", "Google Meet", "google_meet.png"]  # 'G' auto-highlighted
c = ["Calendar", "Calendar", "calendar.webp"]             # 'C' auto-highlighted  
p = ["Claude", "Claude", "claude.png"]                    # 'C' auto-highlighted
```

### Technical Considerations
1. **Performance:** Minimal impact - string operations only during menu display
2. **Compatibility:** Backward compatible - existing manual formatting should still work
3. **Case Sensitivity:** Use case-insensitive matching but preserve original case in display
4. **HTML Escaping:** Ensure proper escaping when injecting HTML spans

### Algorithm Pseudocode
```lua
function highlightShortcutInLabel(key, label)
    -- Skip if auto-highlighting disabled
    if not config.auto_highlight_shortcuts then
        return label
    end
    
    -- Skip if label already contains HTML formatting
    if label:find("<span") then
        return label
    end
    
    -- Find first occurrence of key (case-insensitive)
    local lowerLabel = label:lower()
    local lowerKey = key:lower()
    local pos = lowerLabel:find(lowerKey, 1, true) -- plain text search
    
    if pos then
        local before = label:sub(1, pos-1)
        local match = label:sub(pos, pos + #key - 1)
        local after = label:sub(pos + #key)
        
        return before .. 
               "<span style='font-weight: bold; color: " .. 
               (config.shortcut_highlight_color or "#ff0000") .. 
               "'>" .. match .. "</span>" .. 
               after
    end
    
    return label
end
```

---

## Enhancement #2: Custom Input Dialog Themes

### Problem
Input dialogs currently have a fixed green terminal theme. Users might want different styling for different types of searches.

### Solution
Allow per-dialog theming through config options or menu-specific styling.

**Implementation Ideas:**
- Theme presets: "terminal", "modern", "minimal"
- Per-input custom CSS injection
- Background image support for dialogs

---

## Enhancement #3: Search History for Input Dialogs ✅ COMPLETED

### Problem
Users often repeat similar searches but have to retype them each time.

### Solution
Implemented search history with autocomplete for input dialogs.

**Implemented Features:**
- Store last 25 searches per input type (in `/tmp/hammerflow_history/`)
- Arrow keys to navigate history dropdown
- Last search pre-filled in input field
- Per-action history (each URL template has separate history)

**Not Implemented:**
- Fuzzy matching on previous searches
- Clear history option (can manually delete files in `/tmp/hammerflow_history/`)

---

## Enhancement #4: Fuzzy Search in Dynamic Menus

### Problem
Dynamic menus (like file browsing or window switching) require exact navigation.

### Solution
Add fuzzy search capability to filter dynamic menu items in real-time.

**Implementation:**
- Type-to-filter functionality
- Highlight matching characters
- Reset filter with Escape

---

## Enhancement #5: Multi-Select Support

### Problem
Some operations (like batch file operations) would benefit from selecting multiple items.

### Solution
Add multi-select mode with Ctrl/Cmd modifier support.

**Features:**
- Visual selection indicators
- Batch action confirmation
- Select all/none shortcuts

---

## Enhancement #6: Menu Performance Optimizations

### Problem
Large dynamic menus might have performance issues.

### Solution
Implement virtualization and lazy loading for better performance.

**Features:**
- Virtual scrolling for large lists
- Lazy icon loading
- Debounced filtering

---

## Enhancement #7: Submenu Visual Distinction

### Problem
Submenus are currently displayed with brackets (e.g., "[hammerflow]", "[searches]") which adds visual noise and looks less polished. The brackets are functional in the TOML config but could be replaced with cleaner visual indicators in the UI.

### Solution
Keep brackets in TOML for semantic clarity but offer configurable display options:
- Strip brackets and use color to indicate submenus
- Support custom prefixes/symbols
- Allow combining multiple visual cues for accessibility

### Implementation Strategy

**Phase 1: Configuration Options**
Add new settings at the top level of config.toml:
- `submenu_style` - Enum: "brackets" (default), "colored", "both", "prefix"
- `submenu_color` - Hex color for text (default: "#9B59B6" light purple)
- `submenu_prefix` - Custom prefix string (default: "" or "▸ ")
- `submenu_bold` - Boolean for bold text (default: false)

**Phase 2: Display Processing**
Modify label rendering to:
1. Detect submenu labels (those with brackets)
2. Strip brackets based on `submenu_style`
3. Apply color/formatting
4. Add prefix if configured

**Phase 3: Mode-Specific Implementation**
- **Webview mode:** Inject CSS/HTML for colored text
- **Text mode:** Use ANSI color codes or fallback to prefix symbols

### Configuration Examples

```toml
# Option 1: Colored text without brackets
submenu_style = "colored"
submenu_color = "#9B59B6"  # Light purple

# Option 2: Custom prefix with color
submenu_style = "prefix"
submenu_prefix = "▸ "
submenu_color = "#9B59B6"

# Option 3: Both brackets and color (accessibility)
submenu_style = "both"
submenu_color = "#9B59B6"
submenu_bold = true
```

### Visual Examples
- **Current:** `[hammerflow]` `[searches]` `[apps]`
- **Colored:** `hammerflow` `searches` `apps` (in light purple)
- **Prefix:** `▸ hammerflow` `▸ searches` `▸ apps`
- **Both:** `[hammerflow]` `[searches]` `[apps]` (in light purple)

### Technical Considerations
1. **Backwards Compatibility:** Default to "brackets" to maintain current behavior
2. **Accessibility:** "both" option ensures color-blind users can distinguish submenus
3. **Performance:** String processing only during menu rendering
4. **Nested Submenus:** Apply same formatting at all levels

### Code Locations
- **Primary:** `RecursiveBinder/init.lua` where submenu labels are processed for display
- **Config:** `init.lua` where config options are parsed and stored

### Algorithm Pseudocode
```lua
function formatSubmenuLabel(label)
    -- Check if this is a submenu label
    if not label:match("^%[.+%]$") then
        return label
    end
    
    local cleanLabel = label:gsub("^%[(.+)%]$", "%1")  -- Strip brackets
    
    if config.submenu_style == "brackets" then
        return label  -- Keep original
    elseif config.submenu_style == "colored" then
        return applyColor(cleanLabel, config.submenu_color)
    elseif config.submenu_style == "prefix" then
        return config.submenu_prefix .. applyColor(cleanLabel, config.submenu_color)
    elseif config.submenu_style == "both" then
        return applyColor(label, config.submenu_color)
    end
end

function applyColor(text, color)
    -- For webview mode
    return "<span style='color: " .. color .. 
           (config.submenu_bold and "; font-weight: bold" or "") .. 
           "'>" .. text .. "</span>"
end
```

---

## Configuration Examples

```toml
# New configuration options for enhancements
auto_highlight_shortcuts = true
shortcut_highlight_color = "#ff0000"
input_dialog_theme = "terminal"  # "terminal", "modern", "minimal"
search_history_size = 10
enable_fuzzy_search = true

# Submenu visual distinction options
submenu_style = "colored"    # "brackets", "colored", "both", "prefix"
submenu_color = "#9B59B6"    # Light purple
submenu_prefix = "▸ "        # Optional custom prefix
submenu_bold = false         # Bold text for submenus
```