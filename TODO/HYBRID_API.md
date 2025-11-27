# Hybrid API: Positional Params + Opts Table

## Goal

Support **both** ImGui-style positional parameters AND ARKITEKT-style opts tables for all primitive widgets, making migration effortless while keeping power when needed.

## Current State

All primitives use **opts-only**:
```lua
-- Current: Must use opts table
Ark.Button.draw(ctx, {label = "Click", width = 100, height = 30})
```

**Problem**: Requires rewriting every simple ImGui widget call during migration.

## Target State

Support **both** signatures:

```lua
-- Simple case: positional params (ImGui-style, easy migration)
Ark.Button.draw(ctx, "Click", 100, 30)

-- Complex case: opts table (ARKITEKT improvements)
Ark.Button.draw(ctx, {
  label = "Click",
  width = 100,
  height = 30,
  on_click = handler,
  tooltip = "Click this",
  preset_name = "BUTTON_SUCCESS",
})
```

## Benefits

### 1. **Effortless Migration**
```lua
-- ImGui code ports directly with minimal changes
ImGui.Button(ctx, "Open")           → Ark.Button.draw(ctx, "Open")
ImGui.Button(ctx, "Save", 80)       → Ark.Button.draw(ctx, "Save", 80)
ImGui.Checkbox(ctx, "Enable", true) → Ark.Checkbox.draw(ctx, "Enable", true)
```

Just add `Ark.` and `.draw()` - no need to restructure every call!

### 2. **Gradual Learning Curve**
- Start with familiar positional params
- Discover opts table when you need callbacks, styling, tooltips
- No forced verbosity for prototyping

### 3. **Best of Both Worlds**
```lua
-- Quick prototype (fast & familiar)
Ark.Button.draw(ctx, "Test")

-- Production code (powerful & flexible)
Ark.Button.draw(ctx, {
  label = "Submit Order",
  disabled = not cart.has_items,
  on_click = submit_order,
  preset_name = "BUTTON_SUCCESS",
  tooltip = "Complete purchase"
})
```

## Implementation Pattern

```lua
function M.draw(ctx, label_or_opts, width, height, ...)
  local opts

  if type(label_or_opts) == "string" then
    -- Positional params (ImGui-compatible)
    opts = {
      label = label_or_opts,
      width = width,
      height = height,
      -- ... map other positional params
    }
  elseif type(label_or_opts) == "table" then
    -- Opts table (ARKITEKT-style)
    opts = label_or_opts
  else
    error("First parameter must be string (label) or table (opts)")
  end

  opts = Base.parse_opts(opts, DEFAULTS)
  -- ... rest of implementation
end
```

## Widgets to Update

### High Priority (Commonly Used)
- [ ] **Button** - `Ark.Button.draw(ctx, label, width, height)`
- [ ] **Checkbox** - `Ark.Checkbox.draw(ctx, label, checked)`
- [ ] **InputText** - `Ark.InputText.draw(ctx, label, text, width)`
- [ ] **Slider** - `Ark.Slider.draw(ctx, label, value, min, max, width)`
- [ ] **Combo** - `Ark.Combo.draw(ctx, label, preview_value, width)`

### Medium Priority
- [ ] **RadioButton** - `Ark.RadioButton.draw(ctx, label, active)`
- [ ] **Badge** - `Ark.Badge.draw(ctx, text, color)`
- [ ] **Spinner** - `Ark.Spinner.draw(ctx, size)`

### Low Priority (Less Common)
- [ ] **HueSlider**
- [ ] **Scrollbar**
- [ ] **MarkdownField**

## Signature Mappings

### Button
```lua
-- ImGui: Button(ctx, label, size_x, size_y)
ImGui.Button(ctx, "Click", 100, 30)

-- ARKITEKT positional
Ark.Button.draw(ctx, "Click", 100, 30)

-- ARKITEKT opts
Ark.Button.draw(ctx, {label = "Click", width = 100, height = 30})
```

### Checkbox
```lua
-- ImGui: Checkbox(ctx, label, v)
local rv, v = ImGui.Checkbox(ctx, "Enable", true)

-- ARKITEKT positional
local result = Ark.Checkbox.draw(ctx, "Enable", true)
-- result.changed, result.value

-- ARKITEKT opts
local result = Ark.Checkbox.draw(ctx, {label = "Enable", checked = true})
```

### InputText
```lua
-- ImGui: InputText(ctx, label, buf, flags)
local rv, text = ImGui.InputText(ctx, "Name", current_text)

-- ARKITEKT positional
local result = Ark.InputText.draw(ctx, "Name", current_text)
-- result.changed, result.text

-- ARKITEKT opts
local result = Ark.InputText.draw(ctx, {
  label = "Name",
  text = current_text,
  hint = "Enter your name",
  on_change = handle_change,
})
```

### Slider
```lua
-- ImGui: SliderInt(ctx, label, v, v_min, v_max, format, flags)
local rv, v = ImGui.SliderInt(ctx, "Volume", 50, 0, 100)

-- ARKITEKT positional
local result = Ark.Slider.draw(ctx, "Volume", 50, 0, 100)
-- result.changed, result.value

-- ARKITEKT opts
local result = Ark.Slider.draw(ctx, {
  label = "Volume",
  value = 50,
  min = 0,
  max = 100,
  format = "%d%%",
})
```

## Migration Example

### Before (Pure ImGui)
```lua
if ImGui.Button(ctx, "Open", 80, 30) then
  open_file()
end

local rv, enabled = ImGui.Checkbox(ctx, "Auto-save", config.auto_save)
if rv then
  config.auto_save = enabled
end

local rv, volume = ImGui.SliderInt(ctx, "Volume", config.volume, 0, 100)
if rv then
  config.volume = volume
end
```

### After (ARKITEKT Positional)
```lua
-- Minimal changes - just add Ark. and .draw()
if Ark.Button.draw(ctx, "Open", 80, 30).clicked then
  open_file()
end

local result = Ark.Checkbox.draw(ctx, "Auto-save", config.auto_save)
if result.changed then
  config.auto_save = result.value
end

local result = Ark.Slider.draw(ctx, "Volume", config.volume, 0, 100)
if result.changed then
  config.volume = result.value
end
```

### Eventually (ARKITEKT Opts)
```lua
-- Upgrade to opts when you need more features
Ark.Button.draw(ctx, {
  label = "Open",
  width = 80,
  height = 30,
  on_click = open_file,  -- Callback instead of polling!
  tooltip = "Open file dialog",
})

Ark.Checkbox.draw(ctx, {
  label = "Auto-save",
  checked = config.auto_save,
  on_change = function(value)
    config.auto_save = value
  end,
})

Ark.Slider.draw(ctx, {
  label = "Volume",
  value = config.volume,
  min = 0,
  max = 100,
  format = "%d%%",
  on_change = function(value)
    config.volume = value
    audio.set_volume(value)
  end,
})
```

## Implementation Notes

1. **Type detection**: Check `type(first_param)` to distinguish string/number vs table
2. **Parameter order**: Match ImGui exactly for positional params
3. **Backward compatibility**: Existing opts-only code still works
4. **Documentation**: Show both signatures in API docs
5. **Error messages**: Clear errors if wrong types passed

## Success Metrics

- ✅ ImGui code ports with <5 character changes per widget
- ✅ Simple cases stay simple (no forced verbosity)
- ✅ Power users get full opts when needed
- ✅ No breaking changes to existing ARKITEKT code

## References

- [API_DESIGN_PHILOSOPHY.md](../cookbook/API_DESIGN_PHILOSOPHY.md)
- [IMGUI_API_COVERAGE.md](./IMGUI_API_COVERAGE.md)
