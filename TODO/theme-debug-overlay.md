# Theme Debug Overlay

Visual debugging tool for tuning theme values in real-time.

## What It Does

Renders an overlay showing:
1. Current lightness value and interpolation factor `t`
2. All preset values with their current interpolated result
3. Visual swatches for color values
4. Live updates as you change themes

## Implementation

### 1. Add debug state to ThemeManager

```lua
M.debug_enabled = false

function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
end
```

### 2. Create debug render function

```lua
function M.render_debug_overlay(ctx)
  if not M.debug_enabled then return end

  local lightness = M.get_theme_lightness()
  local t = (lightness - M.preset_anchors.dark) / (M.preset_anchors.light - M.preset_anchors.dark)
  t = math.max(0, math.min(1, t))

  -- Draw semi-transparent background
  ImGui.SetNextWindowBgAlpha(ctx, 0.9)

  if ImGui.Begin(ctx, "Theme Debug", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    -- Header info
    ImGui.Text(ctx, string.format("Lightness: %.2f", lightness))
    ImGui.Text(ctx, string.format("Interpolation t: %.2f", t))
    ImGui.Text(ctx, string.format("Mode: %s", M.current_mode or "nil"))
    ImGui.Separator(ctx)

    -- Show each preset value
    local rules = M.get_current_rules()
    for key, value in pairs(rules) do
      local dark_val = unwrap(M.presets.dark[key])
      local light_val = unwrap(M.presets.light[key])
      local mode = get_mode(M.presets.dark[key])

      -- Color swatch for hex values
      if type(value) == "string" and value:match("^#") then
        local color = Colors.hexrgb(value)
        ImGui.ColorButton(ctx, key, color)
        ImGui.SameLine(ctx)
      end

      ImGui.Text(ctx, string.format("%s [%s]: %s", key, mode, tostring(value)))

      -- Show dark→light range on hover
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, string.format(
          "dark: %s\nlight: %s\nt=%.2f",
          tostring(dark_val), tostring(light_val), t
        ))
      end
    end

    ImGui.End(ctx)
  end
end
```

### 3. Call from main render loop

```lua
function render()
  -- ... normal UI rendering ...

  ThemeManager.render_debug_overlay(ctx)
end
```

### 4. Toggle via keyboard shortcut

```lua
-- In main loop or key handler
if ImGui.IsKeyPressed(ctx, ImGui.Key_F12) then
  ThemeManager.toggle_debug()
end
```

## Visual Layout

```
┌─────────────────────────────────────┐
│ Theme Debug                      [x]│
├─────────────────────────────────────┤
│ Lightness: 0.24                     │
│ Interpolation t: 0.14               │
│ Mode: grey                          │
├─────────────────────────────────────┤
│ ■ tile_name_color [step]: #DDE3E9   │
│ ■ border_outer_color [step]: #000   │
│   tile_fill_brightness [blend]: 0.6 │
│   bg_hover_delta [blend]: 0.028     │
│   ...                               │
└─────────────────────────────────────┘
```

## Optional Enhancements

1. **Live editing**: Sliders to adjust values and see immediate effect
2. **Export**: Button to copy current interpolated values
3. **Presets comparison**: Side-by-side view of dark vs light values
4. **Lightness slider**: Manually scrub through lightness range to preview interpolation

## Files to Modify

- `arkitekt/core/theme_manager/init.lua` - Add debug state and render function
- `arkitekt/gui/app.lua` (or equivalent) - Call render_debug_overlay in main loop

## Effort

Low-medium. Core functionality is ~50 lines. Enhancements add complexity.
