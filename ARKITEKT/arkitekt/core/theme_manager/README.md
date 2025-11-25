# Theme Manager

Dynamic theme system with algorithmic color palette generation for ARKITEKT.

## Quick Start

```lua
local ThemeManager = require('arkitekt.core.theme_manager')

-- Pick a mode
ThemeManager.set_dark()   -- Black preset
ThemeManager.set_grey()   -- Grey preset
ThemeManager.set_light()  -- White preset
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
│            (blend/step)     (flipAt)                        │
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

## Value Wrappers

Three wrappers define HOW values transition between themes:

### `blend(value)` - Smooth Gradient

Smoothly interpolates across presets based on background lightness.

```lua
-- In presets
black = { tile_fill_brightness = blend(0.5) },   -- 50%
grey  = { tile_fill_brightness = blend(0.55) },  -- 55%
white = { tile_fill_brightness = blend(1.4) },   -- 140%

-- At 20% lightness (between black and grey anchors):
-- Result: ~0.52 (interpolated)
```

Works with:
- **Numbers**: Linear interpolation
- **Colors**: RGB interpolation (`blend("#FF0000")` → `blend("#00FF00")`)

### `step(value)` - Discrete Zones

No interpolation. Snaps to the nearest preset's value.

```lua
-- In presets
black = { border_outer_color = step("#000000") },  -- Pure black
grey  = { border_outer_color = step("#000000") },  -- Still black
white = { border_outer_color = step("#404040") },  -- Soft grey

-- At 50% lightness:
-- Result: "#000000" (closest to grey anchor)
```

Use for:
- Semantic colors that shouldn't blend
- Values with distinct meanings per theme

### `flipAt(threshold, value)` - Binary Flip

Flips between dark/light at an absolute lightness threshold.

```lua
-- In contrast (not presets!)
M.contrast = {
  dark  = { tile_name_color = flipAt(0.5, "#DDE3E9") },  -- Light text
  light = { tile_name_color = flipAt(0.5, "#1A1A1A") },  -- Dark text
}

-- At 40% lightness: "#DDE3E9" (below 0.5)
-- At 60% lightness: "#1A1A1A" (above 0.5)
```

Use for:
- Text colors that need hard contrast
- Any value that must be readable regardless of gradual changes

---

## Data Structures

### `M.presets` - Concrete Theme Presets

Three presets defining the color "anchors":

| Preset | Lightness | Description |
|--------|-----------|-------------|
| `black` | ~14% | Very dark (OLED-friendly) |
| `grey` | ~24% | Balanced neutral |
| `white` | ~88% | Bright (paper-like) |

```lua
M.presets = {
  black = {
    bg_hover_delta = blend(0.03),
    tile_fill_brightness = blend(0.5),
    border_outer_color = step("#000000"),
    -- ...
  },
  grey = { ... },
  white = { ... },
}
```

### `M.contrast` - Binary Contrast Modes

Two modes for `flipAt()` values:

| Mode | Condition | Description |
|------|-----------|-------------|
| `dark` | lightness < threshold | Dark background mode |
| `light` | lightness >= threshold | Light background mode |

```lua
M.contrast = {
  dark = {
    tile_name_color = flipAt(0.5, "#DDE3E9"),  -- Light text
  },
  light = {
    tile_name_color = flipAt(0.5, "#1A1A1A"),  -- Dark text
  },
}
```

### `M.preset_anchors` - Lightness Values

Defines where each preset sits on the lightness scale:

```lua
M.preset_anchors = {
  black = 0.14,  -- 14% lightness
  grey = 0.24,   -- 24% lightness
  white = 0.88,  -- 88% lightness
}
```

Used to calculate interpolation factor `t` between presets.

---

## Interpolation Logic

### For `blend()` values:

```
Lightness:  0%    14%    24%         88%    100%
            |     |      |           |      |
Presets:    black ←→ grey ←────────→ white
            │      │                  │
            └──t───┘                  │
               │                      │
        t = (lightness - black) / (grey - black)
```

Between anchors, `t` ranges from 0.0 to 1.0:
- `t = 0.0` → use preset A's value
- `t = 0.5` → 50/50 blend
- `t = 1.0` → use preset B's value

### For `step()` values:

Same calculation, but snaps at `t = 0.5`:
- `t < 0.5` → use preset A's value
- `t >= 0.5` → use preset B's value

### For `flipAt()` values:

Ignores presets entirely. Uses absolute lightness:
- `lightness < threshold` → use `M.contrast.dark` value
- `lightness >= threshold` → use `M.contrast.light` value

---

## Adding New Theme-Aware Values

### 1. Decide the behavior:

| Behavior | Wrapper | Define in |
|----------|---------|-----------|
| Smooth gradient | `blend()` | `M.presets` |
| Discrete zones | `step()` | `M.presets` |
| Binary contrast | `flipAt()` | `M.contrast` |

### 2. Add to appropriate table:

```lua
-- For blend/step (in M.presets):
M.presets = {
  black = { my_new_value = blend(0.3) },
  grey  = { my_new_value = blend(0.5) },
  white = { my_new_value = blend(0.8) },
}

-- For flipAt (in M.contrast):
M.contrast = {
  dark  = { my_contrast_value = flipAt(0.5, "#FFFFFF") },
  light = { my_contrast_value = flipAt(0.5, "#000000") },
}
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
ThemeManager.set_dark()    -- Apply black preset
ThemeManager.set_grey()    -- Apply grey preset
ThemeManager.set_light()   -- Apply white preset
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
local flipAt = ThemeManager.flipAt

-- Add to presets
M.presets.black.my_value = blend(0.5)
M.presets.grey.my_value = blend(0.6)
M.presets.white.my_value = blend(0.9)

-- Add to contrast
M.contrast.dark.my_text = flipAt(0.5, "#FFFFFF")
M.contrast.light.my_text = flipAt(0.5, "#000000")
```

---

## Legacy API

For backward compatibility, these aliases exist:

```lua
M.theme_rules = {
  dark = M.presets.black,
  grey = M.presets.grey,
  light = M.presets.white,
}

M.theme_anchors = M.preset_anchors
M.derivation_rules = unwrap_preset(M.presets.black)
```

---

## Performance

- **Theme switch**: <0.1ms (table updates)
- **Live sync check**: <1µs (one REAPER API call per second)
- **Per-frame cost**: 0ms (widgets read colors directly)

No rebuild needed - when `Style.COLORS` changes, the next frame uses new colors automatically.
