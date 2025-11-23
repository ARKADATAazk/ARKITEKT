# Theme Adjuster - REAPER Integration Guide

## Architecture Overview

The Theme Adjuster connects to REAPER's theme engine through three layers:

```
┌─────────────────────────────────────────────────────┐
│  UI Layer (ImGui Views)                             │
│  - tcp_view.lua, mcp_view.lua, global_view.lua     │
│  - Layout buttons (A/B/C)                           │
│  - Spinners, sliders, checkboxes                    │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│  Parameter Layer (theme_params.lua)                 │
│  - Parameter indexing: param_name → numeric_index   │
│  - Layout scoping: tracks active layout (A/B/C)     │
│  - Value conversion: spinner_index ↔ param_value    │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│  REAPER API                                         │
│  - ThemeLayout_GetParameter(index)                  │
│  - ThemeLayout_SetParameter(index, value, persist)  │
│  - ThemeLayout_RefreshAll()                         │
└─────────────────────────────────────────────────────┘
```

## Parameter Scoping System

### Three Types of Parameters

#### 1. **Global Parameters** (Affect ALL Layouts)
```lua
-- These parameters have NO layout variants (A/B/C)
tcp_indent           -- Folder indentation width
tcp_control_align    -- Control alignment behavior
tcp_LabelMeasure     -- Dynamic track name width
mcp_indent           -- Mixer folder indentation
```

**Storage:** Stored once in theme, indexed under 'A' or 'global'
**UI Behavior:** Changing in Layout A also changes B and C

#### 2. **Per-Layout Parameters** (Separate for A, B, C)
```lua
-- These have A/B/C variants in the theme
tcp_LabelSize        -- Track name field width
tcp_vol_size         -- Volume control size
tcp_MeterSize        -- Meter width
mcp_border           -- Border style
```

**Storage:** Three separate parameters in theme:
- `"A_tcp_LabelSize"` → index 42
- `"B_tcp_LabelSize"` → index 87
- `"C_tcp_LabelSize"` → index 132

**UI Behavior:** Each layout tab shows/edits its own values

#### 3. **Panel-Wide Parameters** (No A/B/C variants)
```lua
envcp_labelSize      -- Envelope name size (only 1 layout)
trans_rateSize       -- Transport rate control size
glb_track_label_color -- Global color setting
```

**Storage:** Stored once, no layout variants
**UI Behavior:** No layout tabs for these panels

## Layout Tab System Implementation

### Current Active Layout Tracking

```lua
-- In theme_params.lua
local activeLayout = {
  tcp = 'A',    -- Currently editing TCP Layout A
  mcp = 'B',    -- Currently editing MCP Layout B
  envcp = 'A',  -- (Always A - no variants)
  trans = 'A'   -- (Always A - no variants)
}
```

### When User Clicks Layout Button

```lua
-- In tcp_view.lua:draw()
for _, layout in ipairs({'A', 'B', 'C'}) do
  if Button.draw_at_cursor(ctx, {
    label = layout,
    is_toggled = (self.active_layout == layout),
    preset_name = "BUTTON_TOGGLE_WHITE",
    on_click = function()
      -- 1. Update local state
      self.active_layout = layout

      -- 2. Update global active layout
      ThemeParams.set_active_layout('tcp', layout)

      -- 3. Reload ALL parameters from new layout
      self:load_from_theme()
    end
  }) then end
end
```

### Parameter Reading Flow

```lua
function TCPView:load_from_theme()
  -- Get parameter for CURRENT layout (A/B/C)
  local param = ThemeParams.get_param('tcp_LabelSize')
  if param then
    -- Find spinner index that matches this value
    self.tcp_LabelSize_idx = ThemeParams.get_spinner_index('tcp_LabelSize', param.value)
  end

  -- Global parameter (same for all layouts)
  local indent_param = ThemeParams.get_param('tcp_indent')
  if indent_param then
    self.tcp_indent_idx = ThemeParams.get_spinner_index('tcp_indent', indent_param.value)
  end
end
```

### Parameter Writing Flow

```lua
-- When user changes a spinner
function TCPView:on_spinner_changed(param_name, new_index)
  -- Convert spinner index to parameter value
  local new_value = ThemeParams.get_spinner_value(param_name, new_index)

  -- Write to theme (for CURRENT layout)
  -- persist=false during drag, persist=true on mouse-up
  ThemeParams.set_param(param_name, new_value, true)

  -- REAPER automatically redraws UI
end
```

## Complete Integration Example

### Integrating TCP View

```lua
-- tcp_view.lua
local ThemeParams = require('ThemeAdjuster.core.theme_params')

function M.new(State, Config, settings)
  local self = setmetatable({
    active_layout = ThemeParams.get_active_layout('tcp'),  -- Get current
    -- ... other fields
  }, TCPView)

  self:load_from_theme()
  return self
end

function TCPView:load_from_theme()
  -- Read all spinner values from theme
  local spinners = {
    'tcp_LabelSize', 'tcp_vol_size', 'tcp_MeterSize',
    'tcp_InputSize', 'tcp_MeterLoc', 'tcp_sepSends'
  }

  for _, param_name in ipairs(spinners) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      self[idx_field] = ThemeParams.get_spinner_index(param_name, param.value)
    end
  end

  -- Read visibility flags
  for _, elem in ipairs(VISIBILITY_ELEMENTS) do
    local param = ThemeParams.get_param(elem.id)
    if param then
      self.visibility[elem.id] = param.value
    end
  end
end

function TCPView:draw(ctx, shell_state)
  -- Layout buttons
  for _, layout in ipairs({'A', 'B', 'C'}) do
    if Button.draw_at_cursor(ctx, {
      label = layout,
      is_toggled = (self.active_layout == layout),
      preset_name = "BUTTON_TOGGLE_WHITE",
      on_click = function()
        self.active_layout = layout
        ThemeParams.set_active_layout('tcp', layout)
        self:load_from_theme()  -- Reload from new layout
      end
    }) then end
  end

  -- Spinners
  local changed, new_idx = Spinner.draw_at_cursor(ctx, {
    label = "Name Size",
    values = ThemeParams.SPINNER_VALUES.tcp_LabelSize,
    current_index = self.tcp_LabelSize_idx,
  }, "tcp_label_size")

  if changed then
    self.tcp_LabelSize_idx = new_idx
    local new_value = ThemeParams.get_spinner_value('tcp_LabelSize', new_idx)
    ThemeParams.set_param('tcp_LabelSize', new_value, true)
  end
end
```

## Initialization Flow

### On Script Startup

```lua
-- main.lua
local ThemeParams = require('ThemeAdjuster.core.theme_params')

function main()
  -- CRITICAL: Index all theme parameters first
  ThemeParams.initialize()

  -- Create views (they will load from theme)
  local tcp_view = TCPView.new(State, Config, settings)
  local mcp_view = MCPView.new(State, Config, settings)

  -- Run GUI loop
  while running do
    tcp_view:draw(ctx, shell_state)
    -- ...
  end
end
```

## Applying Layouts to Tracks

### "Apply Size" Button Implementation

```lua
-- When user clicks "150%_A" button:
if Button.draw_at_cursor(ctx, {
  label = "150%",
  on_click = function()
    ThemeParams.apply_layout_to_tracks('tcp', self.active_layout, '150%_')
  end
}) then end

-- This sets selected tracks to use:
-- - TCP Layout A at 150% scale
-- - Stored in track property P_TCP_LAYOUT = "150%_A"
```

### What This Does

1. Iterates all selected tracks
2. Sets track property `P_TCP_LAYOUT` to `"150%_A"`
3. REAPER immediately switches that track's TCP to Layout A at 150% scale
4. Track remembers this setting (saved in project file)

## Visibility Flags (Bitwise Operations)

### Understanding Flag Bits

```lua
-- Each visibility parameter stores 4 condition bits:
-- Bit 1 (value 1): Hide if mixer visible
-- Bit 2 (value 2): Hide if track not selected
-- Bit 4 (value 4): Hide if track not armed
-- Bit 8 (value 8): Always hide

-- Examples:
value = 0   -- Always visible
value = 1   -- Hide if mixer visible
value = 3   -- Hide if mixer visible (1) OR track not selected (2)
value = 5   -- Hide if mixer visible (1) OR track not armed (4)
value = 8   -- Always hidden
```

### Checkbox Implementation

```lua
-- For each visibility element (Record Arm, Monitor, etc.):
for col_idx, col in ipairs(VISIBILITY_COLUMNS) do
  local is_checked = ThemeParams.is_flag_set(elem.id, col.bit)

  if Checkbox.draw_at_cursor(ctx, "", is_checked) then
    -- Toggle this bit
    ThemeParams.toggle_flag(elem.id, col.bit)
  end
end
```

## Critical Implementation Notes

### 1. **Persist Flag**
```lua
-- During drag operations:
ThemeParams.set_param('tcp_vol_size', value, false)  -- Don't save yet

-- On mouse-up:
ThemeParams.set_param('tcp_vol_size', value, true)   -- Save now
```
This avoids excessive disk writes during dragging.

### 2. **Refresh After Changes**
```lua
ThemeParams.set_param('tcp_LabelSize', new_value, true)
-- Automatically calls ThemeLayout_RefreshAll() to redraw REAPER UI
```

### 3. **Layout Switching**
When switching layouts, **ALL** parameters must be reloaded because each layout has its own values.

### 4. **Parameter Index Caching**
The `theme_params.lua` module caches all parameter indices on startup for fast lookup. Don't call `ThemeLayout_GetParameter` in loops.

## Testing Checklist

- [ ] Parameter indexing builds correctly on startup
- [ ] Layout buttons (A/B/C) switch active layout
- [ ] Changing layout reloads different parameter values
- [ ] Spinner changes update theme immediately
- [ ] REAPER UI updates when parameters change
- [ ] "Apply Size" buttons assign layouts to tracks
- [ ] Visibility checkboxes toggle bits correctly
- [ ] Global parameters (indent, align) affect all layouts
- [ ] Per-layout parameters only affect current layout

## Common Issues

### Issue: Parameters not loading
**Cause:** `initialize()` not called before creating views
**Fix:** Call `ThemeParams.initialize()` in main.lua before creating views

### Issue: Layout changes don't update UI
**Cause:** Forgot to call `self:load_from_theme()` after layout switch
**Fix:** Always reload parameters when changing active layout

### Issue: Changes don't persist
**Cause:** Using `persist=false` but never saving
**Fix:** Set `persist=true` when done editing (mouse-up)

### Issue: Wrong parameter value displayed
**Cause:** Reading parameter for wrong layout
**Fix:** Ensure `activeLayout[panel]` is set correctly before reading

## Next Steps

To complete integration:

1. Update `tcp_view.lua` to use `ThemeParams` module
2. Update `mcp_view.lua` to use `ThemeParams` module
3. Update `global_view.lua` for color parameters (-1000 to -1006)
4. Add "Apply Size" button handlers
5. Implement visibility flag tables with checkboxes
6. Test with real REAPER theme

## API Reference

See `core/theme_params.lua` for complete API documentation.
