# TOML Inline Table Test Results

## Summary
The tinytoml parser **fully supports inline tables** in arrays! You can replace the string format with proper TOML inline tables.

## Working Syntaxes

### ✅ All of these work:
1. **With spaces (recommended for readability)**:
   ```toml
   test = ["action", "label", "icon", { layout_mode = "vertical", max_column_height = 8 }]
   ```

2. **Without spaces**:
   ```toml
   test = ["action", "label", "icon", {layout_mode="vertical",max_column_height=8}]
   ```

3. **With underscores in keys**:
   ```toml
   test = ["action", "label", "icon", { layout_mode = "vertical", max_column_height = 8 }]
   ```

4. **With quoted keys (for special characters)**:
   ```toml
   test = ["action", "label", "icon", { "layout-mode" = "vertical", "grid-spacing" = " | " }]
   ```

5. **Mixed value types**:
   ```toml
   test = ["action", "label", "icon", { enabled = true, count = 10, name = "test" }]
   ```

6. **Empty inline tables**:
   ```toml
   test = ["action", "label", "icon", {}]
   ```

### ❌ What doesn't work:
- Bare values without quotes: `{ key = value }` (must be `{ key = "value" }`)
- Unquoted keys with hyphens: `{ layout-mode = "value" }` (use `{ "layout-mode" = "value" }`)

## Migration Examples

### Before (string format):
```toml
"3" = ["dynamic:cursor", "Cursor Windows", "", "layout_mode=vertical,max_column_height=8"]

[apps]
label = ["[apps]", "", "", "layout_mode=vertical,max_column_height=10"]
```

### After (inline table format):
```toml
"3" = ["dynamic:cursor", "Cursor Windows", "", { layout_mode = "vertical", max_column_height = 8 }]

[apps]
label = ["[apps]", "", "", { layout_mode = "vertical", max_column_height = 10 }]
```

## Code Changes Needed

The existing code in `init.lua` already supports inline tables! Lines 832-834 show:
```lua
elseif type(v[4]) == "table" then
  layoutOptions = v[4]
end
```

This means you can start using inline tables immediately without any code changes.

## Recommendation

Use inline tables with spaces around `=` for better readability:
```toml
["action", "label", "icon", { layout_mode = "vertical", max_column_height = 8 }]
```

This is standard TOML syntax and makes the configuration more maintainable.