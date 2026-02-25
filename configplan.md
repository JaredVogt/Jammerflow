# Hammerflow Visual Config Editor - Implementation Plan

## Executive Summary

Build a static HTML-based visual editor for Hammerflow's config.toml that uses browser UI for editing and Hammerspoon URL events for file operations. This hybrid approach leverages browser security constraints while providing full functionality through a clean interface between the web UI and Hammerspoon's filesystem access.

## Architecture Overview

### Component Diagram
```
┌─────────────────────────┐
│   config-editor.html    │
│  (Static HTML/JS/CSS)   │
│  - Visual TOML Editor   │
│  - Drag & Drop Import   │
│  - Menu Tree Builder    │
│  - Action Type Selector │
│  - Icon Management      │
└───────────┬─────────────┘
            │
      URL Events ↓
            │
┌───────────┴─────────────┐
│    Hammerspoon/         │
│    Hammerflow           │
│  - URL Event Handlers   │
│  - File Operations      │
│  - Config Validation    │
│  - Auto-reload          │
└─────────────────────────┘
```

### Data Flow
1. **Load**: Drag config.toml → Parse TOML → Display in visual editor
2. **Edit**: Visual editing → Generate TOML → Live preview
3. **Save**: Download to ~/Downloads → URL event → Hammerspoon validates & moves file
4. **Feedback**: Hammerspoon shows alerts → Config reloads

## Implementation Phases

### Phase 1: Backend Infrastructure (Hammerspoon)
- [ ] Add URL event handlers to Hammerflow init.lua
  - [ ] `hammerflow_install` - Install config from Downloads
  - [ ] `hammerflow_backup` - Create manual backup
  - [ ] `hammerflow_validate` - Validate TOML syntax
- [ ] Implement config backup system with timestamps
- [ ] Add TOML validation using existing validateTomlStructure
- [ ] Create success/error notifications
- [ ] Test file operations with various scenarios

### Phase 2: Core HTML Editor
- [ ] Create config-editor.html structure
- [ ] Implement TOML parser (using @iarna/toml CDN)
- [ ] Build data model for config structure
- [ ] Add drag-and-drop file loader
- [ ] Implement TOML generator with proper formatting
- [ ] Create basic save/load workflow

### Phase 3: Visual Editor UI
- [ ] Design responsive layout (sidebar tree + main editor + preview)
- [ ] Create menu tree component with expand/collapse
- [ ] Build dynamic action editor forms
- [ ] Add icon picker with preview from images/ directory
- [ ] Implement keyboard shortcut selector/tester
- [ ] Add layout options editor (grid, spacing, etc.)
- [ ] Create background configuration UI
- [ ] Implement drag-and-drop reordering

### Phase 4: Advanced Features
- [ ] Add undo/redo functionality (command pattern)
- [ ] Implement live TOML preview with syntax highlighting
- [ ] Create validation feedback system
- [ ] Add search/filter capabilities
- [ ] Build import/export presets
- [ ] Add keyboard navigation support
- [ ] Implement copy/paste between menus

### Phase 5: Testing & Polish
- [ ] Test all action types (app, URL, window, etc.)
- [ ] Verify TOML generation accuracy
- [ ] Test error handling edge cases
- [ ] Add inline help documentation
- [ ] Create getting started tutorial
- [ ] Performance testing with large configs

## Code Templates

### Hammerspoon URL Event Handlers

```lua
-- In Hammerflow/init.lua - Add after existing URL event bindings

-- Install config from Downloads folder
hs.urlevent.bind("hammerflow_install", function(eventName, params)
    if params.file then
        local downloads = os.getenv("HOME") .. "/Downloads/"
        local source = downloads .. params.file
        local dest = hs.configdir .. "/Hammerflow/config.toml"

        -- Check if source file exists
        if not file_exists(source) then
            hs.alert("❌ Config file not found in Downloads", 3)
            return
        end

        -- Validate TOML first
        local valid, message = validateTomlStructure(source)
        if not valid then
            hs.alert("❌ Invalid TOML: " .. message, 5)
            return
        end

        -- Create backup with timestamp
        local timestamp = os.date("%Y%m%d-%H%M%S")
        local backupPath = dest .. ".backup-" .. timestamp
        os.execute(string.format("cp '%s' '%s'", dest, backupPath))

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
    else
        hs.alert("❌ Backup failed", 3)
    end
end)

-- Validate TOML without installing
hs.urlevent.bind("hammerflow_validate", function(eventName, params)
    if params.file then
        local downloads = os.getenv("HOME") .. "/Downloads/"
        local source = downloads .. params.file

        local valid, message = validateTomlStructure(source)
        if valid then
            hs.alert("✅ TOML is valid", 2)
        else
            hs.alert("❌ TOML invalid: " .. message, 5)
        end
    end
end)
```

### HTML Editor Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hammerflow Config Editor</title>
    <script src="https://cdn.jsdelivr.net/npm/@iarna/toml@2.2.5/lib/toml.min.js"></script>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: 'SF Pro Text', system-ui, -apple-system, sans-serif;
            background: #1a1a1a;
            color: #fff;
        }

        .app {
            height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .header {
            background: #2d2d2d;
            padding: 1rem;
            border-bottom: 1px solid #444;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .header h1 {
            margin: 0;
            color: #00ff00;
            font-size: 1.5rem;
        }

        .actions {
            display: flex;
            gap: 0.5rem;
        }

        .btn {
            padding: 0.5rem 1rem;
            background: #00ff00;
            color: #000;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: 600;
        }

        .btn:hover {
            background: #00cc00;
        }

        .btn-secondary {
            background: #555;
            color: #fff;
        }

        .btn-secondary:hover {
            background: #666;
        }

        .editor-container {
            flex: 1;
            display: flex;
            overflow: hidden;
        }

        .sidebar {
            width: 300px;
            background: #2d2d2d;
            border-right: 1px solid #444;
            overflow-y: auto;
        }

        .tree-view {
            padding: 1rem;
        }

        .tree-item {
            padding: 0.5rem;
            margin: 0.25rem 0;
            background: #3d3d3d;
            border-radius: 4px;
            cursor: pointer;
            user-select: none;
        }

        .tree-item:hover {
            background: #4d4d4d;
        }

        .tree-item.selected {
            background: #00ff0020;
            border-left: 3px solid #00ff00;
        }

        .main-editor {
            flex: 1;
            padding: 1rem;
            overflow-y: auto;
        }

        .preview-panel {
            width: 400px;
            background: #2d2d2d;
            border-left: 1px solid #444;
            display: flex;
            flex-direction: column;
        }

        .preview-header {
            padding: 1rem;
            border-bottom: 1px solid #444;
            font-weight: 600;
        }

        .preview-content {
            flex: 1;
            padding: 1rem;
            overflow-y: auto;
        }

        #tomlPreview {
            background: #1a1a1a;
            border: 1px solid #444;
            border-radius: 4px;
            padding: 1rem;
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 0.85rem;
            white-space: pre-wrap;
            margin: 0;
        }

        .drop-zone {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 255, 0, 0.1);
            border: 3px dashed #00ff00;
            display: none;
            align-items: center;
            justify-content: center;
            font-size: 2rem;
            font-weight: 600;
            z-index: 1000;
        }

        .drop-zone.active {
            display: flex;
        }

        .form-group {
            margin: 1rem 0;
        }

        .form-group label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 600;
        }

        .form-group input,
        .form-group select,
        .form-group textarea {
            width: 100%;
            padding: 0.5rem;
            background: #3d3d3d;
            border: 1px solid #555;
            border-radius: 4px;
            color: #fff;
        }

        .form-group input:focus,
        .form-group select:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #00ff00;
        }

        .icon-picker {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(60px, 1fr));
            gap: 0.5rem;
            max-height: 200px;
            overflow-y: auto;
            margin-top: 0.5rem;
        }

        .icon-option {
            width: 60px;
            height: 60px;
            background: #3d3d3d;
            border: 2px solid #555;
            border-radius: 4px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            font-size: 0.7rem;
            text-align: center;
        }

        .icon-option:hover {
            border-color: #00ff00;
        }

        .icon-option.selected {
            border-color: #00ff00;
            background: #00ff0020;
        }
    </style>
</head>
<body>
    <div class="app">
        <header class="header">
            <h1>🔨 Hammerflow Config Editor</h1>
            <div class="actions">
                <button class="btn btn-secondary" onclick="editor.createBackup()">Backup</button>
                <button class="btn btn-secondary" onclick="editor.exportConfig()">Export</button>
                <button class="btn" onclick="editor.saveConfig()">Save Config</button>
            </div>
        </header>

        <div class="editor-container">
            <aside class="sidebar">
                <div class="tree-view" id="menuTree">
                    <div class="tree-item" onclick="editor.addNewMenu()">
                        + Add Menu
                    </div>
                </div>
            </aside>

            <main class="main-editor" id="mainEditor">
                <div id="actionEditor">
                    <h2>Hammerflow Config Editor</h2>
                    <p>Drag and drop your config.toml file to get started, or create a new configuration.</p>
                </div>
            </main>

            <aside class="preview-panel">
                <div class="preview-header">
                    TOML Preview
                </div>
                <div class="preview-content">
                    <pre id="tomlPreview"># Generated TOML will appear here</pre>
                </div>
            </aside>
        </div>

        <div id="dropZone" class="drop-zone">
            📁 Drop config.toml here to load
        </div>
    </div>

    <script src="config-editor.js"></script>
</body>
</html>
```

### JavaScript Core Implementation

```javascript
class HammerflowConfigEditor {
    constructor() {
        this.config = {
            leader_key: "f20",
            leader_key_mods: "",
            auto_reload: true,
            toast_on_reload: true,
            show_ui: true,
            display_mode: "webview",
            max_grid_columns: 5,
            grid_spacing: " | ",
            grid_separator: " ▸ ",
            background: {}
        };
        this.selectedItem = null;
        this.history = [];
        this.historyIndex = -1;
        this.availableIcons = [];

        this.init();
    }

    init() {
        this.setupDragDrop();
        this.loadAvailableIcons();
        this.render();
        this.setupKeyboardShortcuts();
    }

    setupDragDrop() {
        const dropZone = document.getElementById('dropZone');
        const body = document.body;

        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
            body.addEventListener(eventName, this.preventDefaults, false);
        });

        ['dragenter', 'dragover'].forEach(eventName => {
            body.addEventListener(eventName, () => dropZone.classList.add('active'), false);
        });

        ['dragleave', 'drop'].forEach(eventName => {
            body.addEventListener(eventName, () => dropZone.classList.remove('active'), false);
        });

        body.addEventListener('drop', this.handleDrop.bind(this), false);
    }

    preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    handleDrop(e) {
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            const file = files[0];
            if (file.name.endsWith('.toml')) {
                this.loadConfigFile(file);
            } else {
                alert('Please drop a .toml file');
            }
        }
    }

    loadConfigFile(file) {
        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const content = e.target.result;
                this.config = TOML.parse(content);
                this.saveToHistory();
                this.render();
                this.showNotification('Config loaded successfully!', 'success');
            } catch (error) {
                this.showNotification('Failed to parse TOML: ' + error.message, 'error');
            }
        };
        reader.readAsText(file);
    }

    saveConfig() {
        try {
            const tomlContent = this.generateTOML();
            const timestamp = Date.now();
            const filename = `hammerflow-config-${timestamp}.toml`;

            // Download file to Downloads
            const blob = new Blob([tomlContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            // Trigger Hammerspoon installation
            setTimeout(() => {
                window.location.href = `hammerspoon://hammerflow_install?file=${filename}`;
            }, 1000);

            this.showNotification('Config saved! Installing via Hammerspoon...', 'success');
        } catch (error) {
            this.showNotification('Failed to save config: ' + error.message, 'error');
        }
    }

    generateTOML() {
        try {
            return TOML.stringify(this.config);
        } catch (error) {
            throw new Error('Failed to generate TOML: ' + error.message);
        }
    }

    createBackup() {
        window.location.href = 'hammerspoon://hammerflow_backup';
        this.showNotification('Creating backup...', 'info');
    }

    exportConfig() {
        try {
            const tomlContent = this.generateTOML();
            const blob = new Blob([tomlContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'hammerflow-config.toml';
            a.click();
            URL.revokeObjectURL(url);
        } catch (error) {
            this.showNotification('Export failed: ' + error.message, 'error');
        }
    }

    showNotification(message, type = 'info') {
        // Simple notification - could be enhanced with toast library
        const color = type === 'success' ? '#00ff00' : type === 'error' ? '#ff0000' : '#0088ff';
        console.log(`%c${message}`, `color: ${color}; font-weight: bold;`);
    }

    render() {
        this.renderMenuTree();
        this.renderActionEditor();
        this.renderTOMLPreview();
    }

    renderMenuTree() {
        const treeView = document.getElementById('menuTree');
        treeView.innerHTML = '<div class="tree-item" onclick="editor.addNewMenu()">+ Add Menu</div>';

        // Render existing menus and actions
        this.renderConfigItems(this.config, treeView, '');
    }

    renderConfigItems(obj, container, prefix) {
        Object.keys(obj).forEach(key => {
            if (this.isConfigProperty(key)) return;

            const value = obj[key];
            const itemDiv = document.createElement('div');
            itemDiv.className = 'tree-item';
            itemDiv.style.marginLeft = prefix.length * 20 + 'px';

            if (typeof value === 'object' && !Array.isArray(value)) {
                // It's a submenu
                itemDiv.textContent = `📁 [${key}]`;
                itemDiv.onclick = () => this.selectItem(key, value, 'menu');
                container.appendChild(itemDiv);
                this.renderConfigItems(value, container, prefix + '  ');
            } else {
                // It's an action
                const actionType = this.getActionType(value);
                itemDiv.textContent = `⚡ ${key} (${actionType})`;
                itemDiv.onclick = () => this.selectItem(key, value, 'action');
                container.appendChild(itemDiv);
            }
        });
    }

    isConfigProperty(key) {
        const configProps = [
            'leader_key', 'leader_key_mods', 'auto_reload', 'toast_on_reload',
            'show_ui', 'display_mode', 'max_grid_columns', 'grid_spacing',
            'grid_separator', 'layout_mode', 'max_column_height', 'background',
            'label', 'icon', 'apps'
        ];
        return configProps.includes(key);
    }

    getActionType(value) {
        if (typeof value === 'string') {
            if (value.startsWith('http')) return 'URL';
            if (value.startsWith('window:')) return 'Window';
            if (value.startsWith('cmd:')) return 'Command';
            if (value.startsWith('text:')) return 'Text';
            if (value.startsWith('input:')) return 'Input';
            if (value.startsWith('km:')) return 'KM Macro';
            if (value === 'reload') return 'Reload';
            return 'App';
        }
        if (Array.isArray(value)) return 'Custom';
        return 'Unknown';
    }

    selectItem(key, value, type) {
        this.selectedItem = { key, value, type };

        // Update tree selection
        document.querySelectorAll('.tree-item').forEach(item => {
            item.classList.remove('selected');
        });
        event.target.classList.add('selected');

        this.renderActionEditor();
    }

    renderActionEditor() {
        const editor = document.getElementById('actionEditor');
        if (!this.selectedItem) {
            editor.innerHTML = '<h2>Select an item to edit</h2>';
            return;
        }

        if (this.selectedItem.type === 'menu') {
            this.renderMenuEditor();
        } else {
            this.renderActionForm();
        }
    }

    renderActionForm() {
        const editor = document.getElementById('actionEditor');
        const { key, value, type } = this.selectedItem;

        editor.innerHTML = `
            <h2>Edit Action: ${key}</h2>
            <div class="form-group">
                <label>Action Type:</label>
                <select id="actionType" onchange="editor.updateActionType()">
                    <option value="app">Launch App</option>
                    <option value="url">Open URL</option>
                    <option value="window">Window Management</option>
                    <option value="command">Run Command</option>
                    <option value="text">Type Text</option>
                    <option value="input">Input Dialog</option>
                    <option value="km">Keyboard Maestro</option>
                    <option value="custom">Custom (Array)</option>
                </select>
            </div>
            <div id="actionForm"></div>
            <div class="form-group">
                <button class="btn" onclick="editor.saveAction()">Save Changes</button>
                <button class="btn btn-secondary" onclick="editor.deleteAction()">Delete</button>
            </div>
        `;

        this.renderActionTypeForm();
    }

    renderActionTypeForm() {
        // Implementation for different action type forms
        // This would be quite extensive, showing forms for each action type
    }

    renderTOMLPreview() {
        try {
            const toml = this.generateTOML();
            document.getElementById('tomlPreview').textContent = toml;
        } catch (error) {
            document.getElementById('tomlPreview').textContent = 'Error generating TOML: ' + error.message;
        }
    }

    saveToHistory() {
        this.history = this.history.slice(0, this.historyIndex + 1);
        this.history.push(JSON.parse(JSON.stringify(this.config)));
        this.historyIndex = this.history.length - 1;
    }

    undo() {
        if (this.historyIndex > 0) {
            this.historyIndex--;
            this.config = JSON.parse(JSON.stringify(this.history[this.historyIndex]));
            this.render();
        }
    }

    redo() {
        if (this.historyIndex < this.history.length - 1) {
            this.historyIndex++;
            this.config = JSON.parse(JSON.stringify(this.history[this.historyIndex]));
            this.render();
        }
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            if (e.metaKey || e.ctrlKey) {
                switch (e.key) {
                    case 'z':
                        e.preventDefault();
                        if (e.shiftKey) {
                            this.redo();
                        } else {
                            this.undo();
                        }
                        break;
                    case 's':
                        e.preventDefault();
                        this.saveConfig();
                        break;
                }
            }
        });
    }
}

// Initialize the editor when the page loads
let editor;
document.addEventListener('DOMContentLoaded', () => {
    editor = new HammerflowConfigEditor();
});
```

## UI Components Specification

### 1. Menu Tree View
- **Hierarchical display** of menus/actions with proper indentation
- **Drag & drop reordering** between menu items
- **Add/delete buttons** for quick menu management
- **Expand/collapse nodes** for better navigation
- **Visual indicators** for item types (📁 menu, ⚡ action)
- **Search/filter** functionality for large configs

### 2. Action Editor Forms
- **Dynamic form** based on selected action type
- **Action type selector** dropdown with all supported types
- **Label input field** with live preview
- **Icon picker** with visual grid of available icons
- **Keyboard shortcut configurator** with conflict detection
- **URL validation** for web actions
- **Path validation** for file/app actions

### 3. Layout Options Panel
- **Mode selector** (horizontal/vertical)
- **Column settings** with visual preview
- **Background configuration** with image picker
- **Grid spacing controls**
- **Entry length limits**

### 4. TOML Preview
- **Syntax highlighted** TOML output
- **Live updates** as user edits
- **Copy button** for manual use
- **Validation indicators** showing errors
- **Diff view** for changes

## Testing Checklist

### Functional Tests
- [ ] Load existing config.toml via drag & drop
- [ ] Create new menu with nested structure
- [ ] Add all supported action types
- [ ] Edit existing actions and verify changes
- [ ] Delete items and verify removal
- [ ] Reorder items via drag-drop
- [ ] Save config and verify Hammerspoon installation
- [ ] Test backup creation workflow

### Edge Cases
- [ ] Very large config files (>1000 lines)
- [ ] Invalid TOML syntax handling
- [ ] Special characters in labels and values
- [ ] Deeply nested menu structures (5+ levels)
- [ ] Missing Downloads folder scenario
- [ ] Permission errors on file operations
- [ ] Concurrent save operations

### Browser Compatibility
- [ ] Chrome/Edge (primary target)
- [ ] Safari (macOS focus)
- [ ] Firefox (alternative)

### Performance Tests
- [ ] Large config loading time
- [ ] Real-time preview updates
- [ ] Memory usage with complex configs
- [ ] Drag & drop responsiveness

## Security Considerations

### Input Validation
1. **Sanitize all user inputs** to prevent XSS
2. **Validate TOML syntax** before allowing save
3. **Check file paths** for directory traversal attempts
4. **Limit file sizes** to prevent memory issues

### Local-Only Access
1. **No external dependencies** beyond CDN TOML parser
2. **No network requests** to external servers
3. **URL events only work locally** by design
4. **No data transmission** outside local machine

### File Safety
1. **Always create backups** before overwriting
2. **Validate configurations** before installation
3. **Use timestamps** to prevent filename conflicts
4. **Atomic operations** where possible

## Troubleshooting Guide

| Issue | Symptoms | Solution |
|-------|----------|----------|
| File not found in Downloads | "Config file not found" alert | Check Downloads folder, wait for download completion |
| Permission denied | File move fails | Check Hammerspoon accessibility permissions |
| Config not updating | No visible changes | Verify Hammerspoon reload, check for errors |
| TOML syntax error | Parser fails | Use preview to identify issues, check quotes/brackets |
| Large file issues | Slow performance | Consider breaking into smaller configs |
| Browser compatibility | Features not working | Use Chrome/Safari, check console for errors |
| Drag & drop not working | No file upload | Check browser permissions, try manual file selection |

## Future Enhancements

### Phase 6: Advanced Features
- [ ] **Cloud sync support** via GitHub/iCloud integration
- [ ] **Theme customization** with multiple visual themes
- [ ] **Collaborative editing** with conflict resolution
- [ ] **Git integration** for version control
- [ ] **Config templates library** with presets
- [ ] **AI-powered suggestions** for optimal layouts
- [ ] **Mobile companion app** for quick edits

### Phase 7: Integration Features
- [ ] **Live config testing** without saving
- [ ] **Performance metrics** for menu usage
- [ ] **Icon generation** from app bundles
- [ ] **Automatic backup scheduling**
- [ ] **Export to other formats** (JSON, YAML)
- [ ] **Import from other tools** (Alfred, LaunchBar)

## Resources & References

- **TOML Specification**: https://toml.io/en/v1.0.0
- **Hammerspoon URL Events**: https://www.hammerspoon.org/docs/hs.urlevent.html
- **Drag & Drop API**: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API
- **File API**: https://developer.mozilla.org/en-US/docs/Web/API/File
- **TOML Parser Library**: https://github.com/iarna/iarna-toml

## Development Timeline

- **Week 1**: Phase 1 (Hammerspoon backend)
- **Week 2**: Phase 2 (Core HTML editor)
- **Week 3**: Phase 3 (Visual UI components)
- **Week 4**: Phase 4 (Advanced features)
- **Week 5**: Phase 5 (Testing & polish)

Total estimated effort: **5 weeks** for full implementation with comprehensive testing.

---

**Next Steps**: Begin with Phase 1 by implementing the Hammerspoon URL event handlers, then proceed systematically through each phase while maintaining the todo list for progress tracking.