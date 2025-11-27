# Migration Script: ImGui → ARKITEKT

## Purpose

Automated tool to migrate ImGui code to ARKITEKT with minimal manual work.

**Why not just make APIs identical?**
- ARKITEKT has **better** patterns (result objects, right-click support, callbacks)
- Script automates the boring conversions
- No API compromises needed

## Target Usage

```bash
# Migrate single file
lua scripts/migrate.lua input.lua output.lua

# Migrate directory
lua scripts/migrate.lua my_app/ migrated_app/ --recursive

# Dry run (show what would change)
lua scripts/migrate.lua input.lua --dry-run
```

## Conversion Rules

### 1. Widget Calls → ARKITEKT API

#### Button
```lua
-- Before (ImGui)
if ImGui.Button(ctx, "Click", 100, 30) then
  handle_click()
end

-- After (ARKITEKT)
if Ark.Button.draw(ctx, "Click", 100, 30).clicked then
  handle_click()
end
```

**Rule**: `if ImGui.Button(ARGS) then` → `if Ark.Button.draw(ARGS).clicked then`

#### Checkbox
```lua
-- Before (ImGui)
local changed, value = ImGui.Checkbox(ctx, "Enable", current_value)
if changed then
  config.enabled = value
end

-- After (ARKITEKT)
local result = Ark.Checkbox.draw(ctx, "Enable", current_value)
if result.changed then
  config.enabled = result.value
end
```

**Rule**: Convert multiple returns to result object access

#### InputText
```lua
-- Before (ImGui)
local changed, text = ImGui.InputText(ctx, "Name", current_text)
if changed then
  name = text
end

-- After (ARKITEKT)
local result = Ark.InputText.draw(ctx, "Name", current_text)
if result.changed then
  name = result.text
end
```

#### Slider
```lua
-- Before (ImGui)
local changed, value = ImGui.SliderInt(ctx, "Volume", vol, 0, 100)

-- After (ARKITEKT)
local result = Ark.Slider.draw(ctx, "Volume", vol, 0, 100)
-- Use result.changed and result.value
```

### 2. Namespace Changes

```lua
-- Simple find-replace
ImGui.Text(ctx, "Hello")           → Ark.ImGui.Text(ctx, "Hello")
ImGui.SameLine(ctx)                → Ark.Layout.same_line(ctx)
ImGui.Separator(ctx)               → Ark.Layout.separator(ctx)
```

### 3. Style Push/Pop → Presets (Advanced)

```lua
-- Before (ImGui)
ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)
ImGui.Button(ctx, "Danger")
ImGui.PopStyleColor(ctx)

-- After (ARKITEKT) - suggest but don't auto-convert
Ark.Button.draw(ctx, {
  label = "Danger",
  preset_name = "BUTTON_DANGER",  -- MANUAL: Choose appropriate preset
})
```

**Rule**: Flag for manual review, suggest preset usage

### 4. Context Menus (Flag for Enhancement)

```lua
-- Before (ImGui)
if ImGui.Button(ctx, "File") then
  open_file()
end

-- After (ARKITEKT) - flag as enhanceable
if Ark.Button.draw(ctx, "File").clicked then
  open_file()
end
-- SUGGESTION: Add right-click handler?
-- if result.right_clicked then
--   show_context_menu()
-- end
```

**Rule**: Add comment suggesting right-click enhancement

## Implementation Phases

### Phase 1: Basic Widget Conversion
- [x] Button if-statements
- [x] Checkbox multiple returns
- [x] InputText multiple returns
- [x] Slider multiple returns
- [x] Combo multiple returns

### Phase 2: Namespace & Layout
- [ ] ImGui.Text → Ark.ImGui.Text
- [ ] SameLine, Separator, Spacing → Ark.Layout.*
- [ ] BeginChild/EndChild → Ark.Child.*

### Phase 3: Advanced Features
- [ ] Style push/pop → Preset suggestions
- [ ] Right-click enhancement suggestions
- [ ] Callback conversion opportunities

### Phase 4: Polish
- [ ] Format output code nicely
- [ ] Generate migration report
- [ ] Highlight manual review items

## Script Structure

```lua
-- scripts/migrate.lua
local M = {}

-- Pattern definitions
M.patterns = {
  button = {
    from = "if%s+ImGui%.Button%((.-)%)%s+then",
    to = "if Ark.Button.draw(%1).clicked then",
  },
  checkbox = {
    from = "local%s+(%w+),%s*(%w+)%s*=%s*ImGui%.Checkbox%((.-)%)",
    to = function(rv, val, args)
      return string.format(
        "local result = Ark.Checkbox.draw(%s)\nlocal %s, %s = result.changed, result.value",
        args, rv, val
      )
    end,
  },
  -- ... more patterns
}

-- Apply conversions
function M.convert_file(input, output)
  local content = read_file(input)

  for name, pattern in pairs(M.patterns) do
    content = apply_pattern(content, pattern)
  end

  write_file(output, content)
end

-- Generate report
function M.generate_report(changes)
  print("Migration Report:")
  print("  Converted: " .. changes.converted)
  print("  Flagged for review: " .. changes.flagged)
  print("  Suggestions: " .. changes.suggestions)
end

return M
```

## Output Example

```lua
-- Migrated from: my_app.lua
-- Date: 2025-11-27
-- ARKITEKT Migration v1.0

-- ✅ AUTO-CONVERTED (5 widgets)
-- ⚠️  MANUAL REVIEW (2 items)

local Ark = require('arkitekt')

function my_app(ctx)
  -- ✅ Converted: Button
  if Ark.Button.draw(ctx, "Open", 80, 30).clicked then
    open_file()
  end

  -- ⚠️  MANUAL: Consider adding right-click handler
  local result = Ark.Button.draw(ctx, "File")
  if result.clicked then
    open_file()
  end
  -- SUGGESTION: Add right-click?
  -- if result.right_clicked then
  --   show_context_menu()
  -- end

  -- ✅ Converted: Checkbox
  local result = Ark.Checkbox.draw(ctx, "Enable", config.enabled)
  if result.changed then
    config.enabled = result.value
  end
end
```

## Success Metrics

- ✅ 90%+ of simple widgets auto-convert correctly
- ✅ Manual review items clearly flagged
- ✅ Output code is valid Lua
- ✅ No loss of functionality
- ✅ Enhancement opportunities highlighted

## Future Enhancements

- [ ] Interactive mode (ask for preset choices)
- [ ] Plugin system for custom patterns
- [ ] IDE integration (VS Code extension)
- [ ] Reverse migration (ARKITEKT → ImGui)
- [ ] Pattern learning (analyze user code patterns)

## References

- [HYBRID_API.md](../HYBRID_API.md) - Target API for widgets
- [API_DESIGN_PHILOSOPHY.md](../../cookbook/API_DESIGN_PHILOSOPHY.md)
- [IMGUI_API_COVERAGE.md](../IMGUI_API_COVERAGE.md)

---

## Why This Approach?

**Instead of contorting ARKITEKT to match ImGui exactly:**
1. Keep ARKITEKT's better patterns (result objects, right-click)
2. Automate the boring conversion work
3. Suggest enhancements (callbacks, context menus)
4. Make migration painless while preserving improvements

**Result**: Users get ImGui familiarity + ARKITEKT power with minimal friction.
