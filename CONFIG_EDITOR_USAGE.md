# Hammerflow Visual Config Editor - Usage Guide

## Quick Start

### 1. Open the Editor
Open `/Users/jaredvogt/projects/dotfiles.v2/hammerspoon/Hammerflow/config-editor.html` in your web browser (Chrome/Safari recommended).

### 2. Load Your Config
- **Drag & Drop**: Drag your existing `config.toml` file onto the editor
- **File Picker**: Click "📁 Load Config File" button
- **Create New**: Click "✨ Create New Config" for a fresh start

### 3. Edit Your Configuration
- **Global Settings**: Click "⚙️ Global Settings" to configure leader key, display mode, etc.
- **Add Items**: Click "➕ Add New Item" to create menus or actions
- **Edit Items**: Click any item in the tree to edit its properties

### 4. Save Your Changes
Click "💾 Save Config" which will:
1. Download the config file to your Downloads folder
2. Trigger Hammerspoon to install it automatically
3. Reload your Hammerflow configuration

## Features Overview

### Visual Menu Tree
- **📁 Menus**: Collapsible sections containing other items
- **⚡ Actions**: Individual shortcuts with their action types
- **Hierarchy**: Nested structure with visual indentation

### Action Types Supported
- **App**: Launch applications (`"Kitty"`)
- **URL**: Open web links (`"https://google.com"`)
- **Window**: Window management (`"window:left-half"`)
- **Command**: Terminal commands (`"cmd:ls -la"`)
- **Text**: Type text (`"text:email@example.com"`)
- **Input**: Prompt for input (`"input:https://google.com/search?q={input}"`)
- **KM**: Keyboard Maestro macros (`"km:MacroName"`)
- **Dynamic**: Runtime-generated menus (`"dynamic:cursor"`)

### Global Settings
- **Leader Key**: Choose F17-F21 as your trigger key
- **Display Mode**: Webview (visual) or Text mode
- **Grid Layout**: Columns, spacing, separators
- **Auto-reload**: Automatically reload on config changes

### Advanced Features
- **Undo/Redo**: Cmd+Z/Cmd+Shift+Z or full history tracking
- **Live Preview**: Real-time TOML generation
- **Keyboard Shortcuts**: Cmd+S to save, Cmd+Shift+B for backup
- **Validation**: Automatic TOML syntax checking
- **Backup System**: Timestamped backups before changes

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+S` | Save configuration |
| `Cmd+Z` | Undo last change |
| `Cmd+Shift+Z` | Redo change |
| `Cmd+Shift+B` | Create backup |

## URL Events Available

The editor communicates with Hammerspoon via these URL schemes:

- `hammerspoon://hammerflow_install?file=filename.toml` - Install config
- `hammerspoon://hammerflow_backup` - Create manual backup
- `hammerspoon://hammerflow_validate?file=filename.toml` - Validate TOML

## Troubleshooting

### Config Not Installing
1. Check that the file was downloaded to Downloads folder
2. Verify Hammerspoon is running
3. Look for error alerts from Hammerspoon
4. Check Hammerspoon Console for detailed logs

### Editor Not Loading
1. Use Chrome or Safari (best compatibility)
2. Check browser console for JavaScript errors
3. Ensure internet connection (for TOML library CDN)

### TOML Syntax Errors
1. Use the live preview panel to identify issues
2. Check for unmatched quotes or brackets
3. Verify proper key naming (avoid spaces without quotes)

### Large Config Performance
1. Consider breaking large configs into smaller sections
2. Use Chrome/Safari for better performance
3. Limit undo history if memory becomes an issue

## Tips & Best Practices

### Menu Organization
- Use descriptive labels for clarity
- Group related actions in menus
- Keep frequently used items at top level

### Action Design
- Use custom labels for better readability
- Add icons for visual identification
- Test keyboard shortcuts don't conflict

### Performance
- Avoid deeply nested menus (>5 levels)
- Use dynamic menus for large lists
- Keep action descriptions concise

### Backup Strategy
- Create backups before major changes
- Use version control for config files
- Test changes in small increments

## Browser Compatibility

| Browser | Support | Notes |
|---------|---------|-------|
| **Chrome** | ✅ Full | Recommended, best performance |
| **Safari** | ✅ Full | Good for macOS users |
| **Firefox** | ⚠️ Partial | Some CSS differences |
| **Edge** | ✅ Good | Similar to Chrome |

## Future Enhancements

Planned features for future versions:
- ☐ Cloud sync support
- ☐ Configuration templates
- ☐ Visual theme customization
- ☐ Collaborative editing
- ☐ Mobile companion app
- ☐ Git integration
- ☐ AI-powered suggestions

## Support

For issues or questions:
1. Check the `configplan.md` for detailed technical specs
2. Review Hammerspoon Console logs
3. Verify all prerequisites are installed
4. Test with a minimal configuration first

---

**Happy configuring!** 🚀