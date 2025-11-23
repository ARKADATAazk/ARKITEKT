# Arkitekt Style System

Centralized styling and theming for Arkitekt.

## Files

### `defaults.lua`
**SINGLE SOURCE OF TRUTH for all colors and component presets.**

Use this for:
- All custom Arkitekt components (buttons, dropdowns, panels, etc.)
- Color definitions via `M.COLORS`
- Component style presets (`BUTTON_TOGGLE_TEAL`, `BUTTON_TOGGLE_WHITE`, etc.)
- Toggle button variants

```lua
local Style = require('arkitekt.gui.style.defaults')

-- Access centralized colors
local bg = Style.COLORS.BG_BASE
local text = Style.COLORS.TEXT_NORMAL

-- Use presets
local config = {
  preset_name = "BUTTON_TOGGLE_TEAL",
  is_toggled = true,
}
```

### `imgui_defaults.lua`
**ImGui theme overrides for native widgets.**

Use this for:
- Native ImGui widgets (when not using custom components)
- ImGui PushStyle functions
- Base theme application

```lua
local ImGuiStyle = require('arkitekt.gui.style.imgui_defaults')

-- Apply ImGui theme
ImGuiStyle.PushMyStyle(ctx)
-- ... your ImGui code
ImGuiStyle.PopMyStyle(ctx)

-- Access ImGui palette
local color = ImGuiStyle.palette.grey_10
```

## Adding New Colors

**ALWAYS add to `defaults.lua` M.COLORS:**

```lua
M.COLORS = {
  -- Add your color here
  MY_NEW_COLOR = hexrgb("#RRGGBBAA"),
}
```

Then reference it everywhere:
```lua
local Style = require('arkitekt.gui.style.defaults')
local my_color = Style.COLORS.MY_NEW_COLOR
```

## Adding New Component Presets

1. Define in `defaults.lua`
2. Use centralized colors
3. Export as M.YOUR_PRESET

```lua
M.MY_COMPONENT = {
  bg_color = M.COLORS.BG_BASE,
  text_color = M.COLORS.TEXT_NORMAL,
  -- ...
}
```

## Available Easing Curves

For overlays and animations, use these curve names (from `gui/fx/animation/easing.lua`):

- `'linear'` - No easing
- `'smoothstep'` - Smooth start/end
- `'smootherstep'` - Extra smooth start/end
- `'ease_in_quad'`, `'ease_out_quad'`, `'ease_in_out_quad'`
- `'ease_in_cubic'`, `'ease_out_cubic'`, `'ease_in_out_cubic'`
- `'ease_in_sine'`, `'ease_out_sine'`, `'ease_in_out_sine'`
- `'ease_in_expo'`, `'ease_out_expo'`, `'ease_in_out_expo'`
- `'ease_in_back'`, `'ease_out_back'`

Example:
```lua
overlay_mgr:push({
  fade_curve = 'smootherstep',
  fade_duration = 0.3,
  -- ...
})
```

## Architecture

```
gui/
  style/
    defaults.lua         ← Custom components, centralized colors
    imgui_defaults.lua   ← ImGui native widgets theme
    README.md            ← This file
```

**DO NOT** create duplicate color definitions elsewhere!
