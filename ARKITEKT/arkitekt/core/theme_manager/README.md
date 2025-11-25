# Theme Manager

Dynamic theme system with algorithmic color palette generation for ARKITEKT.

## Quick Start

```lua
local ThemeManager = require('arkitekt.core.theme_manager')

-- Pick a mode
ThemeManager.set_dark()   -- Dark preset (~14% lightness)
ThemeManager.set_grey()   -- Grey preset (~24% lightness, auto-interpolated)
ThemeManager.set_light()  -- Light preset (~88% lightness)
ThemeManager.adapt()      -- Sync with REAPER's theme
```

All UI colors are then available via `Style.COLORS.*`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User selects mode                        │
│              (dark / grey / light / adapt)                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              generate_palette(base_bg, base_text)           │
│                            ↓                                │
│         compute_rules_for_lightness(lightness, mode)        │
│                     ┌─────┴─────┐                           │
│                     ↓           ↓                           │
│               M.presets    M.contrast                       │
│            (blend/step)   (threshold)                       │
│                     └─────┬─────┘                           │
│                           ↓                                 │
│                    merged rules                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Style.COLORS                           │
│   BG_BASE, TEXT_NORMAL, TILE_NAME_COLOR, etc.              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       UI Code                               │
│              Reads Style.COLORS at render time              │
└─────────────────────────────────────────────────────────────┘
```

---

## Two-Preset System

The theme manager uses just **two anchor presets** (dark and light). All intermediate themes (grey, adapt, custom colors) are automatically interpolated between them.

| Preset | Lightness | Description |
|--------|-----------|-------------|
| `dark` | ~14% | Very dark (OLED-friendly) |
| `light` | ~88% | Bright (paper-like) |

**Grey is auto-derived**: When you call `set_grey()`, it applies a 24% lightness background with values automatically interpolated between dark and light presets.

**Adapt mode**: Reads REAPER's background color and interpolates proportionally.

---

## Value Wrappers

Two wrappers define HOW values transition between presets:

### `blend(value)` - Smooth Gradient

Smoothly interpolates between dark and light based on background lightness.

```lua
-- In presets
dark  = { tile_fill_brightness = blend(0.5) },   -- 50%
light = { tile_fill_brightness = blend(1.4) },   -- 140%

-- At 50% lightness (midpoint):
-- Result: ~0.95 (linear interpolation)
```

Works with:
- **Numbers**: Linear interpolation
- **Colors**: RGB interpolation (`blend("#FF0000")` → `blend("#00FF00")`)

### `step(value)` - Discrete Snap

No interpolation. Snaps to the closest preset's value at midpoint.

```lua
-- In presets
dark  = { border_outer_color = step("#000000") },  -- Pure black
light = { border_outer_color = step("#404040") },  -- Soft grey

-- At 40% lightness: "#000000" (closer to dark)
-- At 60% lightness: "#404040" (closer to light)
```

Use for:
- Semantic colors that shouldn't blend
- Values with distinct meanings per theme

### Contrast Rules - Binary Flip

For values that need hard contrast (text readability), use `M.contrast`:

```lua
-- Single definition - no duplication, can't desync
M.contrast = {
  tile_name_color = { threshold = 0.5, dark = "#DDE3E9", light = "#1A1A1A" },
}

-- At 40% lightness: "#DDE3E9" (below 0.5 threshold)
-- At 60% lightness: "#1A1A1A" (above 0.5 threshold)
```

Each rule is `{ threshold, dark, light }`:
- `threshold`: Lightness value to flip at (0.0-1.0)
- `dark`: Value when bg lightness < threshold
- `light`: Value when bg lightness >= threshold

Use for:
- Text colors that need hard contrast
- Any value that must be readable regardless of gradual changes

---

## Data Structures

### `M.presets` - Two Anchor Presets

```lua
M.presets = {
  dark = {
    bg_hover_delta = blend(0.03),
    tile_fill_brightness = blend(0.5),
    border_outer_color = step("#000000"),
    -- ...
  },
  light = {
    bg_hover_delta = blend(-0.04),
    tile_fill_brightness = blend(1.4),
    border_outer_color = step("#404040"),
    -- ...
  },
}
```

### `M.contrast` - Binary Contrast Rules

Single-definition rules for contrast-critical values:

```lua
M.contrast = {
  tile_name_color = { threshold = 0.5, dark = "#DDE3E9", light = "#1A1A1A" },
  -- Add more contrast rules as needed:
  -- another_text = { threshold = 0.45, dark = "#FFFFFF", light = "#000000" },
}
```

Each key maps to `{ threshold, dark, light }` - no duplication, can't desync.

### `M.preset_anchors` - Lightness Values

Defines where each preset sits on the lightness scale:

```lua
M.preset_anchors = {
  dark = 0.14,   -- 14% lightness
  light = 0.88,  -- 88% lightness
}
```

Used to calculate interpolation factor `t` between presets.

---

## Interpolation Logic

### For `blend()` values:

```
Lightness:  0%    14%                    88%    100%
            |     |                       |      |
Presets:    dark ←──────────────────────→ light
                          │
                          t = (lightness - dark) / (light - dark)
```

Between anchors, `t` ranges from 0.0 to 1.0:
- `t = 0.0` → use dark preset's value
- `t = 0.5` → 50/50 blend
- `t = 1.0` → use light preset's value

### For `step()` values:

Same calculation, but snaps at `t = 0.5`:
- `t < 0.5` → use dark preset's value
- `t >= 0.5` → use light preset's value

### For contrast rules:

Ignores presets entirely. Uses absolute lightness:
- `lightness < threshold` → use `dark` value
- `lightness >= threshold` → use `light` value

---

## Adding New Theme-Aware Values

### 1. Decide the behavior:

| Behavior | Define in | Format |
|----------|-----------|--------|
| Smooth gradient | `M.presets` | `blend(value)` |
| Discrete snap | `M.presets` | `step(value)` |
| Binary contrast | `M.contrast` | `{ threshold, dark, light }` |

### 2. Add to appropriate table:

```lua
-- For blend/step (in both presets):
M.presets.dark.my_new_value = blend(0.3)
M.presets.light.my_new_value = blend(0.8)

-- For contrast (single definition):
M.contrast.my_contrast_value = { threshold = 0.5, dark = "#FFFFFF", light = "#000000" }
```

### 3. Use in `generate_palette()`:

```lua
return {
  -- ...existing colors...
  MY_NEW_VALUE = rules.my_new_value,
  MY_CONTRAST_VALUE = rules.my_contrast_value,
}
```

### 4. Access in UI code:

```lua
local value = Style.COLORS.MY_NEW_VALUE
```

---

## Script-Specific Colors

Scripts can override library colors via `script/defs/colors.lua`:

```lua
-- ThemeAdjuster/defs/colors.lua
local Style = require('arkitekt.gui.style')

local M = {}

M.TILE = {
  bg_inactive = nil,        -- nil → use Style.COLORS.BG_PANEL
  bg_active = "#2D4A37",    -- Explicit → stays fixed
}

function M.get_tile_colors()
  local S = Style.COLORS
  return {
    bg_inactive = M.TILE.bg_inactive or S.BG_PANEL,
    bg_active = M.TILE.bg_active,
  }
end

return M
```

Pattern:
- `nil` = fall back to `Style.COLORS` (theme-reactive)
- Explicit value = stays fixed regardless of theme

---

## API Reference

### Mode Selection

```lua
ThemeManager.set_dark()    -- Apply dark preset
ThemeManager.set_grey()    -- Apply grey (auto-interpolated)
ThemeManager.set_light()   -- Apply light preset
ThemeManager.adapt()       -- Sync with REAPER theme

ThemeManager.set_mode("dark")  -- Same as set_dark()
```

### Preset Themes

```lua
-- Apply named preset
ThemeManager.apply_theme("dark")
ThemeManager.apply_theme("pro_tools")
ThemeManager.apply_theme("ableton")

-- Get available names
local names = ThemeManager.get_theme_names()
```

### REAPER Integration

```lua
-- One-time sync
ThemeManager.sync_with_reaper()

-- Live sync (call in main loop)
local sync = ThemeManager.create_live_sync(1.0)
function main_loop()
  sync()  -- Checks REAPER theme every second
  draw_ui()
end
```

### Custom Themes

```lua
-- Generate from custom colors
local bg = Colors.hexrgb("#FF6B6BFF")
local text = Colors.auto_text_color(bg)
ThemeManager.generate_and_apply(bg, text)

-- Or with accent
ThemeManager.generate_and_apply(bg, text, accent_color)
```

### Debugging

```lua
-- Get current interpolated rules
local rules = ThemeManager.get_current_rules()

-- Get current background lightness
local l = ThemeManager.get_theme_lightness()
```

### Wrappers (for extending presets)

```lua
local blend = ThemeManager.blend
local step = ThemeManager.step

-- Add to presets (both dark and light)
M.presets.dark.my_value = blend(0.5)
M.presets.light.my_value = blend(0.9)

-- Add to contrast (single definition)
M.contrast.my_text = { threshold = 0.5, dark = "#FFFFFF", light = "#000000" }
```

---

## Legacy API

For backward compatibility, these aliases exist:

```lua
M.theme_rules = {
  dark = M.presets.dark,
  grey = M.presets.dark,   -- Grey uses dark (auto-interpolated at runtime)
  light = M.presets.light,
}

M.theme_anchors = M.preset_anchors
M.derivation_rules = unwrap_preset(M.presets.dark)
```

---

## Performance

- **Theme switch**: <0.1ms (table updates)
- **Live sync check**: <1µs (one REAPER API call per second)
- **Per-frame cost**: 0ms (widgets read colors directly)

No rebuild needed - when `Style.COLORS` changes, the next frame uses new colors automatically.
