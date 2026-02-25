# Jammerflow

A powerful Hammerspoon configuration framework for creating leader-key driven shortcuts and window management. Jammerflow provides an intuitive way to bind sequential key combinations to various actions including app launching, URL opening, text insertion, window management, and custom functions.

> **Note:** Jammerflow is the public release of the Hammerflow project. The Hammerspoon spoon is still named `Hammerflow.spoon` for compatibility — internal code references to the spoon name are intentional. Users can add their own icons by dropping PNGs into the `images/` directory.

## Overview

Jammerflow consists of three main components:

1. **Main Module** (`init.lua`) - The core framework that parses TOML configuration and sets up keybindings
2. **Configuration** (`config.toml`) - TOML-based configuration defining your key mappings and actions
3. **RecursiveBinder** (`RecursiveBinder/init.lua`) - Enhanced version of the Hammerspoon RecursiveBinder spoon with grid layout and visual improvements

## Features

- **Leader Key System**: Use a dedicated key (like F17/F18) to trigger sequential key combinations
- **Visual Grid Interface**: Modern, translucent grid showing available keys and actions
- **Custom Backgrounds**: Support for animated GIFs and static images with configurable opacity and positioning
- **Icon Support**: Display custom icons alongside menu items for visual identification
- **TOML Configuration**: Human-readable configuration format with support for nested groups
- **Multiple Action Types**: Support for apps, URLs, commands, text input, window management, and more
- **Conditional Actions**: Different actions based on current application context
- **Auto-reload**: Automatically reload configuration when files change
- **Window Management**: Built-in presets and custom positioning
- **Custom Sort Order**: Control display order with prefixed keys while keeping simple hotkeys
- **Display Modes**: Choose between modern webview interface or classic text display
- **Extensible**: Support for custom Lua functions and Hammerspoon commands

## Quick Start

1. Set your leader key in `config.toml`:
   ```toml
   leader_key = "f17"  # or f18, f19, etc.
   ```

2. Add some basic shortcuts:
   ```toml
   k = "Kitty"                    # Launch Kitty terminal (press 'k')
   K = "Keyboard Maestro"         # Launch Keyboard Maestro (press 'Shift+K', displays as 'K')
   g = "https://google.com"       # Open Google
   v = ["Visual Studio Code", "VS Code"]  # Launch VS Code with custom label
   ```

3. Create groups for organization:
   ```toml
   [w]
   label = "[window]"
   icon = "window.png"            # Optional group icon
   h = "window:left-half"         # Move window to left half
   l = "window:right-half"        # Move window to right half
   f = "window:fullscreen"        # Toggle fullscreen
   ```

## Configuration Format

### Basic Settings

```toml
leader_key = "f17"              # Required: The leader key to start sequences
leader_key_mods = ""            # Optional: Modifiers for leader key (cmd, ctrl, alt, shift)
auto_reload = true              # Optional: Auto-reload on file changes (default: true)
toast_on_reload = true          # Optional: Show reload notification (default: false)
show_ui = true                  # Optional: Show visual interface (default: true)
display_mode = "webview"        # Optional: "webview" or "text" (default: "webview")

# Grid layout options (for webview mode)
layout_mode = "horizontal"      # Layout direction: "horizontal" or "vertical" (default: "horizontal")
max_grid_columns = 5            # Maximum columns in grid (horizontal mode, default: 5)
max_column_height = 10          # Maximum items per column (vertical mode, default: 10)
grid_spacing = " | "            # Spacing between columns (default: " | ")
grid_separator = " ▸ "          # Separator between key and label (default: " : ")

# Background configuration (optional — static image, GIF, or animated via Inyo spoon)
[background]
image = "background.gif"        # Image filename in images/ directory
opacity = 0.6                  # Transparency: 0.0 (invisible) to 1.0 (opaque)
position = "center center"     # Position: "center center", "top left", "bottom right", etc.
size = "cover"                 # Size behavior: "cover", "contain", "auto", "100% 100%", "200px", etc.
# type = "inyo"                # Uncomment to use Inyo animated backgrounds (requires Inyo.spoon)
# template = "jellyfish"       # Inyo template name (jellyfish, particles, matrix, etc.)
```

### Key Naming Rules

- **Letters and numbers**: Can be used directly: `a`, `Z`, `1`, `9`
- **Special characters**: Must be quoted in TOML: `"/"`, `"."`, `"?"`, `";"`, `"'"`
- **Uppercase letters**: Automatically include shift modifier and display as uppercase
  - `p = "Application"` displays as `p` and triggers with `p`
  - `P = "Other App"` displays as `P` and triggers with `Shift+P`
- **All printable characters are supported** as shortcut keys

### ⚠️ Important: TOML Key Ordering

**All individual keys must be defined BEFORE any table sections (`[section]`) in your config.toml file.**

```toml
# ✅ CORRECT: Individual keys first
leader_key = "f20"
c = "Cursor"
p = "Claude"
g = "Google"

# Then table sections
[background]
image = "bg.gif"

[l]
label = "[linear]"
```

```toml
# ❌ WRONG: Individual keys after table sections will be ignored
leader_key = "f20"

[background]
image = "bg.gif"

# These keys will NOT work - they're after a table section
c = "Cursor"  # IGNORED
p = "Claude"  # IGNORED
```

If you place individual keys after table sections, Jammerflow will show a warning and those keys will not work.

### Action Types

#### Application Launching
```toml
k = "Kitty"                     # Launch by name (lowercase 'k')
s = "Safari"                    # Launch Safari (lowercase 's')
S = "Slack"                     # Launch Slack (uppercase 'S' - Shift+S)
v = ["Visual Studio Code", "VS Code"]  # With custom label
v = ["Visual Studio Code", "VS Code", "vscode.png"]  # With custom label and icon

# Special characters must be quoted
"/" = "Safari"                  # Forward slash requires quotes
"." = "Finder"                  # Period requires quotes
```

#### URLs and Links
```toml
g = "https://google.com"
b = "https://github.com"
```

#### Commands and Scripts
```toml
z = "cmd:code ~/.zshrc"         # Run terminal command
r = "reload"                    # Special: reload Hammerspoon config
```

#### Text Input
```toml
e = "text:sam@example.com"      # Type text
i = "input:https://google.com/search?q={input}"  # Prompt for input
```

#### Keyboard Shortcuts
```toml
s = "shortcut:cmd shift 4"      # Trigger screenshot shortcut
c = "shortcut:cmd c"            # Copy
```

#### Window Management
```toml
h = "window:left-half"          # Use preset
l = "window:right-half"
c = "window:center-half"
m = "window:maximized"
f = "window:fullscreen"

# Custom positioning with percentages (values between -1 and 1)
s = "window:.4,.3,.2,.4"        # 40% from left, 30% from top, 20% width, 40% height

# Custom positioning with pixels (values > 1 or < -1)
r = "window:-1000,0,1000,.8"    # 1000px from RIGHT edge, top, 1000px wide, 80% height
b = "window:100,100,800,600"    # 100px from left, 100px from top, 800x600 window
c = "window:-400,-300,800,600"  # Center an 800x600 window (negative = from right/bottom)
```

#### Code/File Opening
```toml
h = "code: ~/.hammerspoon"      # Open in VS Code
d = "code: ~/Documents"
```

#### Deep Links and URL Schemes
```toml
# Raycast (built-in support)
c = "raycast://extensions/raycast/raycast/confetti"
e = "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"

# Linear (built-in support)  
l = "linear://myworkspace/view/issue-id-here"

# Other app deep links - requires adding to init.lua
# See "Adding New Deep Link Support" section below
```

**Adding New Deep Link Support**

To support new URL schemes (like `notion://`, `slack://`, etc.), you need to add them to the `getActionAndLabel` function in `init.lua`:

```lua
-- In init.lua, around line 179-182, add new URL schemes:
elseif startswith(s, "notion://") then
  return open(s), s
elseif startswith(s, "slack://") then
  return open(s), s
```

Currently supported URL schemes:
- `http://` and `https://` (web URLs)
- `raycast://` (Raycast deep links)
- `linear://` (Linear app deep links)

### External URL Scheme Triggering

Jammerflow can be triggered externally via URL schemes, enabling integration with shell scripts, Alfred, Raycast, Keyboard Maestro, and other automation tools.

**Base URL:** `hammerspoon://hammerflow?<parameters>`

**Parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `action` | Raw action string (any Jammerflow action) | `action=chrome:https://google.com` |
| `key` | Dot-separated config key path | `key=l.g` (Linear menu → g key) |
| `label` | Search by display label (case-insensitive) | `label=Calendar` |
| `query` | Input for `{input}` placeholder substitution | `query=my+search` |
| `silent` | Suppress error alerts (logs only) | `silent=true` |

**Examples:**

```bash
# Launch an app
open "hammerspoon://hammerflow?action=Safari"

# Open URL in specific browser
open "hammerspoon://hammerflow?action=chrome:https://google.com"

# Trigger by config key path (nested submenu)
open "hammerspoon://hammerflow?key=l.g"

# Trigger by label
open "hammerspoon://hammerflow?label=Calendar"

# Search with query substitution (bypasses input dialog)
open "hammerspoon://hammerflow?action=chrome:https://google.com/search%3Fq%3D{input}&query=test"

# Silent mode (no error alerts)
open "hammerspoon://hammerflow?action=Safari&silent=true"
```

**URL Encoding:** Special characters must be URL-encoded: Space (`%20` or `+`), `:` (`%3A`), `?` (`%3F`), `&` (`%26`), `=` (`%3D`)

#### Custom Hammerspoon Code
```toml
a = "hs:hs.alert('Hello, world!')"  # Run any Hammerspoon Lua code
```

#### Keyboard Maestro Macros
```toml
g = "km:Google_meet"                # Execute Keyboard Maestro macro
m = ["km:My_Macro", "Custom Label"] # With custom label
v = "km:My_Macro?var1=value1&var2=value2" # Pass KM variables
```

You can pass variables to Keyboard Maestro by appending a query string to the macro name. Supported separators between pairs are `&`, `,`, or `|`. Examples:

```toml
# All equivalent
g = "km:MacroName?Project=Alpha&Env=prod"
g = "km:MacroName?Project=Alpha,Env=prod"
g = "km:MacroName?Project=Alpha|Env=prod"
```
In your Keyboard Maestro macro, the variables are available as `%Variable%Project%`, `$KMVAR_Project`, etc.

#### Custom Functions
```toml
f = "function:myFunction"       # Call registered function
g = "function:myFunc|arg1|arg2" # Call with arguments
```

#### Dynamic Menus
Generate menu items dynamically at runtime:
```toml
c = "dynamic:cursor"            # Show Cursor editor windows
f = "dynamic:files(~/Downloads)" # Browse files (with optional path argument)
g = "dynamic:git"               # Git branch switcher
d = "dynamic:docker"            # Docker container management
l = "dynamic:linear"            # Linear issues

# Arguments are passed in parentheses
f = "dynamic:files(~/Projects)" # Browse specific directory

# With custom layout options (4th element)
c = ["dynamic:cursor", "Cursor Windows", "", {layout_mode = "vertical", max_column_height = 8}]
```

### Groups and Nesting

Create organized groups of actions:

```toml
[l]
label = "[links]"               # Optional group label
icon = "links.png"              # Optional group icon
g = "https://github.com"
t = "https://twitter.com"

# Nested groups
[l.m]
label = "[my links]"
icon = "personal.png"           # Icons work on nested groups too
g = ["https://github.com/myuser", "my github"]
t = ["https://twitter.com/myuser", "my twitter"]
```

### Conditional Actions

Execute different actions based on the current application:

```toml
# Define app shortcuts in [apps] section
[apps]
browser = "safari"              # or bundle ID like "com.apple.safari"
editor = "code"

# Use conditional syntax: key_condition
c_browser = "shortcut:cmd l"    # Focus address bar in browser
c_editor = "shortcut:cmd p"     # Quick open in editor
c = "shortcut:cmd c"            # Default copy for other apps
```

The `_` condition is the fallback if no other conditions match.

## Window Management

### Presets

Built-in window positioning presets:

- `left-half`, `right-half`, `center-half`
- `top-half`, `bottom-half`
- `left-third`, `center-third`, `right-third`
- `first-quarter`, `second-quarter`, `third-quarter`, `fourth-quarter`
- `top-left`, `top-right`, `bottom-left`, `bottom-right`
- `maximized`, `fullscreen`

### Custom Positioning

You can define custom window positions using the format: `window:x,y,width,height`

**Smart unit detection:**
- Values between -1 and 1 are treated as **percentages** of screen size
- Values > 1 or < -1 are treated as **pixels**
- You can mix pixels and percentages in the same command

**Negative pixel values:**
- Negative x positions from the **right** edge of screen
- Negative y positions from the **bottom** edge of screen
- Useful for consistent positioning regardless of screen size

**Examples:**
```toml
# Percentage positioning (current behavior)
"window:.5,0,.5,1"              # Right half (50% from left, full height)

# Pixel positioning
"window:100,100,800,600"        # 100px from left/top, 800x600 window
"window:-1000,0,1000,.8"        # 1000px wide on right side, 80% height
"window:-400,-300,800,600"      # Center an 800x600 window

# Mixed units
"window:-1200,100,1200,.5"      # 1200px from right, 100px from top, 50% height
```

## Chord Prefix System

The chord prefix system allows you to create sequential key combinations where the first key(s) modify the behavior of subsequent keys. This is opt-in per menu and highly configurable.

### Overview

Think of chord prefixes like combining modifiers with actions. For example, in the smartwindow system:
- Press `2` then `h` = left-half (2 = halves, h = left)
- Press `3` then `l` = right-third (3 = thirds, l = right)
- Press `h` alone = nudge window left

### Enabling Chords

Enable chord mode for any menu by adding `chord_enabled = true`:

```toml
[9]
label = "[window]"
chord_enabled = true
chord_timeout = 4.0    # Seconds before prefix clears (default: 4.0)
```

### Configuring Prefix Keys

By default, number keys (0-9) are used as prefix collectors. You can customize this:

```toml
# Default: numbers as prefixes
[9]
label = "[window]"
chord_enabled = true
# chord_prefix_keys not specified = defaults to ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

# Custom: letter prefixes
[custom]
label = "[custom]"
chord_enabled = true
chord_prefix_keys = ["a", "b", "c"]
```

### How It Works

1. When you enter a chord-enabled menu, prefix keys don't trigger actions
2. Instead, they accumulate as the "prefix"
3. When you press a non-prefix key, the action receives the full chord state
4. After 4 seconds of inactivity (or pressing Escape), the prefix clears

### Built-in Smart Window Example

Jammerflow includes a `smartwindow:` action type that demonstrates the chord system:

```toml
[9]
label = "[window]"
chord_enabled = true
h = ["smartwindow:h", "←"]       # Left direction
j = ["smartwindow:j", "↓"]       # Down direction
k = ["smartwindow:k", "↑"]       # Up direction
l = ["smartwindow:l", "→"]       # Right direction
t = ["smartwindow:t", "top"]     # Top direction
b = ["smartwindow:b", "bot"]     # Bottom direction
m = ["window:maximized", "max"]
f = ["window:fullscreen", "full"]
```

**How prefix + direction works:**
- No prefix: Nudges window 1/8 screen in that direction (stops at edges)
- `2` + direction: Moves to half (e.g., `2h` = left-half, `2l` = right-half)
- `3` + direction: Moves to third (e.g., `3h` = left-third, `3j` = center-third)
- `4` + two directions: Moves to quarter (e.g., `4hk` = top-left quarter)

**Supported combinations:**
| Chord | Position |
|-------|----------|
| `2h` | left-half |
| `2l` | right-half |
| `2j` | center-half |
| `2t` | top-half |
| `2b` | bottom-half |
| `3h` | left-third |
| `3l` | right-third |
| `3j` | center-third |
| `4hk` | top-left quarter |
| `4lk` | top-right quarter |
| `4hj` | bottom-left quarter |
| `4lj` | bottom-right quarter |

### Creating Custom Chord-Aware Actions

Your custom actions can receive chord state by accepting a `chordState` parameter:

```lua
-- In your custom function
local function myChordAction(key)
  return function(chordState)
    local prefix = chordState and chordState.prefix or ""
    local partial = chordState and chordState.partialDirection or ""

    if prefix == "" then
      -- No prefix: do default behavior
      print("No prefix, key: " .. key)
    else
      -- Prefix provided: modify behavior
      print("Prefix: " .. prefix .. ", key: " .. key)
    end
  end
end

-- Register it
hammerflow.registerFunctions({
  myAction = myChordAction
})
```

Then in config.toml:
```toml
[myMenu]
label = "[custom]"
chord_enabled = true
chord_prefix_keys = ["x", "y", "z"]
a = ["function:myAction|a", "A action"]
b = ["function:myAction|b", "B action"]
```

When the user presses `x` then `a`, your function receives `chordState.prefix = "x"`.

### Chord State Properties

Actions receive a `chordState` table with:
- `prefix` - Accumulated prefix keys as a string (e.g., "2", "4", "xy")
- `partialDirection` - For multi-key sequences like quarters (e.g., "h" for `4hk`)
- `timeout` - The configured timeout value
- `enabled` - Whether chord mode is active

## Custom Functions

Register custom Lua functions for advanced functionality:

```lua
-- In your Hammerspoon init.lua or other file
local hammerflow = require('Hammerflow')  -- spoon name is still Hammerflow

local myFunctions = {
  toggleDarkMode = function()
    hs.osascript.applescript('tell app "System Events" to tell appearance preferences to set dark mode to not dark mode')
  end,
  
  openProject = function(projectName)
    os.execute("code ~/Projects/" .. projectName)
  end
}

hammerflow.registerFunctions(myFunctions)
```

Then use in your config:
```toml
d = "function:toggleDarkMode"
p = "function:openProject|my-project"
```

## Icon Support

Jammerflow supports displaying custom icons alongside menu items for better visual identification.

### Adding Icons

Icons can be added to actions using the array format with a third parameter:

```toml
# Format: [action, label, icon_filename]
k = ["Kitty", "Terminal", "kitty.png"]
g = ["https://github.com", "GitHub", "github.png"]
c = ["code ~/.hammerspoon", "Config", "gear.png"]
```

Icons can also be added to groups using the `icon` property:

```toml
[l]
label = "[linear]"
icon = "linear.png"              # Group icon
b = ["linear://project/view/task-id", "Bryce Task", "bryce.png"]
c = ["linear://project/view/other-task", "Other Task", "task.png"]
```

### Default Icon Fallback

When no icon is specified for a menu item, Jammerflow automatically uses `generic.png` as a fallback. This ensures consistent vertical alignment of all menu items. You can customize the default appearance by replacing the `generic.png` file in the images directory.

### Icon Requirements

- **Location**: Place images in the `images/` directory within your Jammerflow folder
- **Size**: 48x48 pixels recommended (any size works, will be scaled to 48x48)
- **Format**: PNG recommended, JPEG also supported
- **Encoding**: Images are automatically base64-encoded for webview display

### Icon Directory Structure

```
Jammerflow/
├── init.lua
├── config.toml
├── images/              # Icon directory — drop your own PNGs here
│   ├── kitty.png       # Terminal icon
│   ├── github.png      # GitHub icon
│   ├── generic.png     # Default fallback icon
│   └── gear.png        # Settings icon
├── RecursiveBinder/
│   └── init.lua
└── lib/
    └── tinytoml.lua
```

## Label Formatting with HTML

Jammerflow supports HTML formatting in labels when using webview display mode. This allows you to style text with colors, bold, italics, and other HTML formatting.

### Using HTML in Labels

You can include HTML tags directly in your labels, but you must properly escape quotes in TOML:

```toml
# Option 1: Use single quotes for HTML attributes (recommended)
g = ["km:Google_meet", "<span style='font-weight: bold; color: red'>G</span>oogle Meet", "google_meet.png"]

# Option 2: Use TOML triple quotes
p = ["Claude", '''<b>Claude</b> <span style="color: blue">AI</span>''', "claude.png"]

# Option 3: Escape double quotes with backslashes
k = ["Kitty", "<span style=\"text-decoration: underline\">Terminal</span>", "kitty.png"]
```

### Supported HTML Tags

Since labels are rendered in a webview, most HTML tags work:
- `<b>`, `<strong>` - Bold text
- `<i>`, `<em>` - Italic text
- `<u>` - Underlined text
- `<span>` - For custom styling with CSS
- `<sup>`, `<sub>` - Superscript and subscript
- `<del>`, `<s>` - Strikethrough text

### Examples

```toml
# Bold and colored text
m = ["Mail", "<b>Mail</b> <span style='color: #007AFF'>(3 new)</span>", "mail.png"]

# Multiple styles
t = ["Terminal", "<span style='font-family: monospace; background: #333; color: #0f0; padding: 2px'>Terminal</span>", "terminal.png"]

# Combining with groups
[d]
label = ["<span style='color: orange'>[development]</span>", "", "", {layout_mode = "vertical"}]
```

### Important Notes

- HTML formatting only works in `webview` display mode (not in `text` mode)
- Always use proper quote escaping in TOML to avoid parse errors
- Keep formatting simple for best readability in the menu interface
- The base font size and style are controlled by the webview CSS

## File Structure

```
Jammerflow/
├── init.lua              # Main framework
├── config.toml           # Your configuration
├── images/               # Icon directory — add your own icons here
│   ├── app1.png         # 48x48px icons
│   └── app2.png
├── RecursiveBinder/
│   └── init.lua         # Enhanced RecursiveBinder spoon
└── lib/
    └── tinytoml.lua     # TOML parser (referenced in code)
```

## Usage

1. Press your leader key (e.g., F17) to open the grid interface
2. See available keys and their actions in a visual grid
3. Press a key to execute its action or enter a submenu
4. Press Escape to cancel at any time
5. Press the leader key again while the grid is open to close it

## Advanced Features

### Display Modes

Jammerflow supports two display modes for showing available shortcuts:

#### Webview Mode (default)
The modern visual interface with:
- Grid layout with customizable columns
- Visual icons support
- Click-to-execute functionality
- Translucent background with optional custom image
- Configurable spacing and separators
- Choice of horizontal or vertical layout

```toml
display_mode = "webview"  # Modern visual grid

# Background image configuration (optional)
[background]
image = "background.gif"        # Image filename in images/ directory
opacity = 0.6                  # Transparency: 0.0 (invisible) to 1.0 (opaque)
position = "center center"     # Position: "center center", "top left", "bottom right", etc.
size = "cover"                 # Size behavior options:
# "cover"     - Scale to fill container, may crop edges (good for full backgrounds)
# "contain"   - Scale to fit inside container, shows whole image (good for logos)
# "auto"      - Natural size, excess clipped outside container (good for large images)
# "100% 100%" - Stretch to fill exactly (may distort image)
# "200px"     - Fixed width, height scales proportionally
# "200px 150px" - Fixed width and height
```

#### Animated Backgrounds with Inyo

Instead of a static image or GIF, you can use code-rendered animated backgrounds powered by the [Inyo](https://github.com/JaredVogt/Inyo.spoon) spoon. Inyo provides HTML/CSS/JS animation templates that run directly in the webview — no video files needed.

```toml
[background]
type = "inyo"                   # Enable Inyo animated backgrounds
template = "jellyfish"          # Template name (jellyfish, particles, matrix, etc.)
image = "background.gif"        # Fallback image if Inyo isn't available
opacity = 0.6
```

**Setup:** Install `Inyo.spoon` in `~/.hammerspoon/Spoons/Inyo.spoon/`. Templates live in `Inyo.spoon/templates/` as self-contained HTML files. If Inyo isn't installed, Jammerflow falls back to the `image` field.

Per-menu Inyo backgrounds also work — use `background_type` and `background_template` in a menu's table section.

#### Text Mode
The classic lightweight display with:
- Traditional text-based interface
- Fast and minimal resource usage
- Special sorting for mixed case (a, A, b, B, c, C...)
- Works in all environments
- No dependencies on webview

```toml
display_mode = "text"     # Classic text display
```

### Layout Modes (Webview only)

When using webview display mode, you can choose between horizontal and vertical layouts:

#### Horizontal Layout (default)
Items flow from left to right, wrapping to new rows:
```toml
layout_mode = "horizontal"      # Items flow left-to-right
max_grid_columns = 5           # Maximum columns before wrapping to next row
```

#### Vertical Layout
Items flow from top to bottom, wrapping to new columns:
```toml
layout_mode = "vertical"        # Items flow top-to-bottom
max_column_height = 10         # Maximum items per column before wrapping
```

This is particularly useful when you have many shortcuts and prefer to scan them vertically rather than horizontally. The vertical layout creates newspaper-style columns that are easier to read for long lists.

#### Per-Entry Layout Control
You can override layout settings for individual menu items or groups by using the 4th element in array format:

```toml
# Dynamic menu with vertical layout
"3" = ["dynamic:cursor", "Cursor Windows", "", {layout_mode = "vertical", max_column_height = 8}]

# Regular action with custom layout
k = ["Kitty", "Terminal", "kitty.png", {layout_mode = "horizontal", max_grid_columns = 3}]

# Group with custom layout (use array format for label)
[w]
label = ["[window]", "", "", {layout_mode = "vertical", max_column_height = 12}]
```

Note: When using inline tables in TOML, keys must be unquoted (e.g., `layout_mode` not `"layout_mode"`).

### Custom Sort Order

Control the display order of shortcuts using prefixed keys:

```toml
# Numeric prefixes for precise ordering
10_k = "Kitty"           # Displays as 'k', sorts as '10_k'
20_c = "Chrome"          # Displays as 'c', sorts as '20_c'
99_z = "reload"          # Displays as 'z', sorts last

# Alphabetic prefixes for general ordering
a_w = "window:left-half"  # Displays as 'w', sorts as 'a_w'
z_r = "reload"           # Displays as 'r', sorts as 'z_r'

# Regular keys work normally
g = "Google"             # Displays and sorts as 'g'

# Examples from config.toml:
"z_." = "reload"         # Period key, sorted to end
"y_/" = ["input:https://google.com/search?q={input}", "Search"]  # Slash key with prefix
```

This system allows complete control over the order items appear in the menu while keeping the actual hotkey simple. The prefix is stripped from the display but used for sorting. This is especially useful for organizing special characters and controlling which items appear first or last.

### Auto-reload
When `auto_reload = true`, Jammerflow watches for changes to configuration files and automatically reloads, making development and tweaking very fast.

### Multiple Configuration Files
The framework can load from multiple TOML files in priority order. Modify the file loading in your main Hammerspoon config to specify which files to search for.

### Input Prompts
Use `input:` prefix to create actions that prompt for user input. The dialog will display the label from your configuration as the prompt:
```toml
s = ["input:https://google.com/search?q={input}", "Search Google"]  # Dialog shows "Search Google:"
o = ["input:code {input}", "Open in VS Code"]                      # Dialog shows "Open in VS Code:"
```

### Search Menu Example
Create a dedicated search menu with multiple search engines:
```toml
["/"]
label = "[searches]"
g = ["input:https://google.com/search?q={input}", "Google Search"]
# To target specific Google accounts, add &authuser=email%40domain.com
w = ["input:https://drive.google.com/drive/search?q={input}&authuser=work%40company.com", "Work Drive"]
j = ["input:https://drive.google.com/drive/search?q={input}&authuser=user%40example.com", "Personal Drive"]
```

### Search History

Input dialogs automatically remember your previous searches:
- **Last search pre-filled**: The most recent search appears in the input field
- **History dropdown**: Press ↓ (arrow down) to see previous searches
- **Navigate history**: Use ↑/↓ arrows to browse, Enter to select
- **Per-action history**: Each input action maintains its own separate history (up to 25 entries)
- **Escape**: Press Escape to close dropdown without selecting

History is stored in `/tmp/hammerflow_history/` and persists across Hammerspoon reloads.

### Browser-specific Fixes
The framework includes specific handling for Firefox and Zen Browser window management animations.

## Dynamic Menus

Dynamic menus allow you to generate menu items at runtime based on lookups, API calls, or system state. This is perfect for creating menus that change based on context or external data.

### How It Works

1. When you press a key bound to a `dynamic:` action, Jammerflow calls the specified generator
2. The generator returns a list of items (e.g., "dog", "cat", "bird")
3. Jammerflow automatically assigns shortcuts (a, b, c, etc.) to each item
4. The submenu is displayed with the generated items

### Built-in Generators

Jammerflow includes several built-in dynamic menu generators located in `DynamicMenu/generators/`:

- **`cursor`** - Show Cursor editor windows (integrates with Keyboard Maestro)
- **`kitty`** - Show Kitty terminal windows
- **`chrome`** - Chrome/Canary tab switcher with keyword filtering (see Browser Tab Generators below)
- **`claude_web`** - Claude Web tab finder with "New Chat" option (see Browser Tab Generators below)
- **`obsidian`** - Browse Obsidian vault folders with pagination (see Obsidian Generator below)
- **`files`** - Browse files and folders (accepts path argument)
- **`git`** - Git branch switcher for current repository
- **`docker`** - Docker container management
- **`linear`** - Linear issues (example with mock data)

### Obsidian Vault Browser (`obsidian`)

The `obsidian` generator creates dynamic menus for browsing Obsidian vault folders, with support for pagination through large directories.

**Syntax:** `dynamic:obsidian|path,limit,offset`

**Parameters (pipe-separated, then comma-separated):**
- `path` - Folder path within the vault (e.g., `VMs`, `ProPatch Manual/web-manual/docs`)
- `limit` - Maximum files to show per page (optional, shows all if omitted)
- `offset` - Starting position for pagination (optional, defaults to 0)

**Examples:**
```toml
# Browse VMs folder with pagination (15 files per page)
[n.v]
action = ["dynamic:obsidian|VMs,15", "VMs", "obsidian.png", { layout_mode = "vertical" }]

# Browse Youtube folder with pagination
[n.y]
action = ["dynamic:obsidian|Youtube,15", "Youtube Transcriptions", "obsidian.png", { layout_mode = "vertical" }]

# Browse documentation folder (no limit)
[n.p]
action = ["dynamic:obsidian|ProPatch Manual/web-manual/docs", "ProPatch Manual", "obsidian.png", { layout_mode = "vertical" }]
```

**Features:**
- **Recent files first**: Files sorted by modification time (most recent at top)
- **Pagination**: When limit is set, shows "Next" and "Prev" navigation items
  - `down` key: Navigate to next page (appears at top when more files exist)
  - `up` key: Navigate to previous page (appears at bottom when not on first page)
- **Clean labels**: Strips numeric prefixes (e.g., `01a-filename.md` displays as `filename`)
- **Single column layout**: Navigation items reduce file count to maintain column height

**Note:** The vault name is hardcoded in the generator (`SolidBlack`). Modify `DynamicMenu/generators/obsidian.lua` to change the vault.

### Browser Tab Generators

Jammerflow includes specialized generators for managing browser tabs, allowing you to quickly switch between tabs matching specific patterns.

#### Chrome/Canary Tab Switcher (`chrome`)

The `chrome` generator searches for tabs in Google Chrome or Chrome Canary by keyword. It accepts two comma-separated parameters: `keyword` and `browser`.

**Syntax:** `dynamic:chrome|keyword,browser`

- **keyword** - Text to search for in tab titles or URLs (empty string shows all tabs)
- **browser** - Either `chrome` (Google Chrome) or `canary` (Google Chrome Canary, default)

**Examples:**
```toml
# Gmail tabs in Chrome Canary (default browser)
[o]
action = "dynamic:chrome|mail.google,canary"
label = "Gmail Tabs (Canary)"
layout_mode = "vertical"
max_column_height = 15

# Gmail tabs in regular Chrome
[i]
action = "dynamic:chrome|mail.google,chrome"
label = "Gmail Tabs (Chrome)"
layout_mode = "vertical"

# GitHub tabs in Chrome
[g]
action = "dynamic:chrome|github,chrome"
label = "GitHub Tabs"

# ALL tabs in Canary (empty keyword)
[t]
action = "dynamic:chrome|,canary"
label = "All Canary Tabs"
```

**Special Display Formatting:**
- **Gmail tabs** (`mail.google.com`): Displays just the email address extracted from the tab title
  - Example: `user@company.com` instead of `Inbox (3,650) - user@company.com - Company Mail`
- **Other tabs**: Displays `Title — domain.com`

#### Claude Web Tab Finder (`claude_web`)

The `claude_web` generator is purpose-built for managing Claude Web tabs in Google Chrome. It provides:

1. **Fixed "New Chat" option (key `a`)**: Always opens `https://claude.ai/new` in the same window/tab group as existing Claude tabs
2. **Existing Claude tabs (keys `b`, `c`, `d`...)**: Lists all tabs with titles ending in " - Claude"

**Syntax:** `dynamic:claude_web` (no parameters)

**Example:**
```toml
[q]
action = "dynamic:claude_web"
label = "Claude Web"
icon = "claude.png"
layout_mode = "vertical"
max_column_height = 15
```

**Features:**
- **Smart window focus**: When opening a new chat, the generator first brings the window containing an existing Claude tab to the front, then opens the new tab. This ensures new tabs inherit the same tab group as your other Claude tabs.
- **Clean labels**: Tab titles are displayed without the " - Claude" suffix
  - Example: `Shoulder rehabilitation exercises` instead of `Shoulder rehabilitation exercises - Claude`
- **Automatic key assignment**: New Chat is always `a`, existing tabs start from `b`

#### Gemini Conversation Switcher (`gemini`)

The `gemini` generator enables fast switching between Google Gemini conversations with actual conversation titles (not the generic "Google Gemini"). It requires a Chrome extension to extract conversation titles from the DOM.

**Syntax:** `dynamic:gemini|browser,account`

**Arguments (comma-separated):**
1. `browser` - `chrome` or `canary` (default: canary)
2. `account` - Google account email (optional, for account-specific URLs)

**Examples:**
- `dynamic:gemini|canary,user@example.com` - Canary with specific account
- `dynamic:gemini|chrome,user@example.com` - Chrome with specific account
- `dynamic:gemini|,user@example.com` - Default browser with account
- `dynamic:gemini` - Default browser, no account specified

**Fixed Keys:**
- `1` - New Chat (opens `https://gemini.google.com/u/{account}/app`)
- `2` - Search (opens `https://gemini.google.com/u/{account}/search`)

**Dynamic Keys:** `a`-`z` list existing Gemini conversations

**Example:**
```toml
[m]
action = "dynamic:gemini|canary,user@example.com"
label = "Gemini"
icon = "gemini.png"
layout_mode = "vertical"
max_column_height = 15
```

**Features:**
- **Smart window focus**: When opening a new chat or search, the generator brings the window containing an existing Gemini tab to the front, then opens the new tab in that window
- **Conversation titles**: Displays actual conversation descriptions extracted by the Chrome extension
- **Extension detection**: Shows a warning menu item (`0`) if the extension isn't installed and tabs have generic titles

**Required: Chrome Extension**

The generator requires the "Gemini Tab Titles" Chrome extension to display conversation titles. Without it, all tabs show as "Google Gemini".

**Extension Location:** `extensions/gemini-tab-titles/`

**Installation:**
1. Open Chrome/Canary and navigate to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `extensions/gemini-tab-titles/` folder

**What the extension does:**
- Updates each Gemini tab's `document.title` with the conversation description from `<span class="conversation-title gds-title-m">`
- Uses a MutationObserver to handle SPA navigation
- Provides a popup (click extension icon) to see all Gemini tabs

### Creating Custom Generators

Create your own generators by adding a new file to `DynamicMenu/generators/`:

```lua
-- DynamicMenu/generators/myprojects.lua
return function(args)
  return {
    {label = "Website", action = "code:~/projects/website"},
    {label = "Mobile App", action = "code:~/projects/app"},
    {label = "API Server", action = "code:~/projects/api"}
  }
end
```

Then use it in config.toml:
```toml
p = "dynamic:myprojects"        # No registration needed!
```

### Generator Return Formats

Generators can return items in several formats:

```lua
-- Simple string array (launches as applications)
return {"Safari", "Chrome", "Firefox"}

-- Objects with actions
return {
  {label = "Google", action = "https://google.com"},
  {label = "GitHub", action = "https://github.com"},
  {label = "Lock Screen", action = function() hs.caffeinate.lockScreen() end}
}

-- Mixed formats
return {
  "TextEdit",  -- Simple app launch
  {label = "My Project", action = "code:~/project"},  -- Custom action
  {label = "Sleep", action = function() hs.caffeinate.systemSleep() end}  -- Function
}

-- Rich actions with Keyboard Maestro integration
return {
  {
    label = "Window Name",
    icon = "cursor.png",
    action = {
      type = "km",
      macro = "MacroName",
      variables = {
        var1 = "value1",
        var2 = "value2"
      }
    }
  }
}
```

### Advanced Example

See `examples/custom_dynamic_menu.lua` for comprehensive examples including:
- Project switchers
- Bookmark managers
- System control panels
- API integrations
- Context-aware menus
- Music controls

## Tips

- Use F17, F18, or F19 as leader keys - they're dedicated function keys that don't interfere with other shortcuts
- Organize related actions into logical groups with descriptive labels
- Use conditional actions to make the same key do different things in different apps
- Take advantage of the visual grid to discover and remember your shortcuts
- Start simple and gradually add more complex configurations as you learn

## Credits

Based on the Hammerspoon RecursiveBinder spoon with enhancements for modern UI and TOML configuration. Originally created by Sam Lewis.
