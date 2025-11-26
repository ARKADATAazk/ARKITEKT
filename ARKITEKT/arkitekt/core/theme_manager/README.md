# Theme Manager

Dynamic theme system with algorithmic color palette generation for ARKITEKT.

## Quick Start

```lua
local ThemeManager = require('arkitekt.core.theme_manager')

-- Pick a mode
ThemeManager.set_dark()   -- Dark preset (~14% lightness)
ThemeManager.set_light()  -- Light preset (~88% lightness)
ThemeManager.adapt()      -- Sync with REAPER's theme
```

All UI colors are then available via `Style.COLORS.*`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User selects mode                        │
│                 (dark / light / adapt)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  generate_palette(base_bg)                  │
│                            ↓                                │
│                   Flat palette with:                        │
│           offset() - BG-derived colors                      │
│           snap()   - discrete dark/light                    │
│           lerp()   - smooth interpolation                   │
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

## DSL Wrappers

Three wrappers define HOW values adapt to theme lightness:

### `offset(dark, light, [threshold])` - Delta from BG_BASE

Applies a lightness offset to BG_BASE. **Snaps** between deltas at threshold.

```lua
BG_HOVER = offset(0.03, -0.04)     -- +3% dark, -4% light (snap at 0.5)
BG_PANEL = offset(-0.04)           -- -4% both (constant)
SPECIAL  = offset(0.05, -0.05, 0.3) -- snap at t=0.3
```

### `lerp(dark, light)` - Smooth Interpolation

Linearly interpolates between values based on `t`.

```lua
OPACITY = lerp(0.87, 0.60)         -- smooth transition
ACCENT  = lerp("#334455", "#AABBCC") -- RGB color lerp
```

### `snap(dark, light, [threshold])` - Discrete Snap

No interpolation. Picks one value or the other.

```lua
TEXT_NORMAL = snap("#FFFFFF", "#000000")     -- snap at 0.5
SPECIAL     = snap("#AAA", "#555", 0.3)      -- snap at t=0.3
```

---

## Preset Anchors

| Anchor | Lightness | t value |
|--------|-----------|---------|
| `dark` | ~14% | 0.0 |
| `light` | ~88% | 1.0 |

The interpolation factor `t` is computed from current lightness:
```
t = (lightness - 0.14) / (0.88 - 0.14)
```

---

## Flat Palette Structure

All colors in one flat table. The mode determines processing:

```lua
M.palette = {
  -- === BACKGROUNDS (offset = BG-derived) ===
  BG_BASE   = "base",
  BG_HOVER  = offset(0.03, -0.04),
  BG_PANEL  = offset(-0.04),

  -- === TEXT (snap on hex = color) ===
  TEXT_NORMAL = snap("#FFFFFF", "#000000"),
  TEXT_DIMMED = snap("#A0A0A0", "#606060"),

  -- === VALUES (lerp on numbers = value) ===
  TILE_BRIGHTNESS = lerp(0.5, 1.4),
  BORDER_OPACITY  = lerp(0.87, 0.60),
}
```

Type inference:
- `offset` → Apply delta to BG_BASE → RGBA color
- `snap`/`lerp` on hex strings → RGBA color
- `snap`/`lerp` on numbers → numeric value

---

## Adding New Theme-Aware Values

### 1. Choose the wrapper:

| Behavior | Wrapper |
|----------|---------|
| Delta from BG_BASE | `offset(d, l)` |
| Smooth gradient | `lerp(d, l)` |
| Discrete snap | `snap(d, l)` |
| Custom threshold | `snap(d, l, t)` or `offset(d, l, t)` |

### 2. Add to palette:

```lua
M.palette = {
  -- ...existing...
  MY_NEW_BG = offset(0.08, -0.06),
  MY_NEW_OPACITY = lerp(0.9, 0.7),
  MY_NEW_COLOR = snap("#FF0000", "#00FF00"),
}
```

### 3. Access in UI code:

```lua
local color = Style.COLORS.MY_NEW_COLOR
local opacity = Style.COLORS.MY_NEW_OPACITY
```

---

## Script-Specific Palettes

Scripts can register their own theme-reactive palettes using the same DSL:

```lua
-- MyScript/defs/palette.lua
local ThemeManager = require('arkitekt.core.theme_manager')
local Colors = require('arkitekt.core.colors')

local snap = ThemeManager.snap
local lerp = ThemeManager.lerp
local offset = ThemeManager.offset

local M = {}

-- Register flat palette at load time
ThemeManager.register_script_palette("MyScript", {
  -- Colors (snap/lerp on hex)
  HIGHLIGHT = snap("#FF6B6B", "#CC4444"),
  BADGE_TEXT = snap("#FFFFFF", "#1A1A1A"),
  ERROR_BG = snap("#240C0C", "#FFDDDD"),

  -- Values (lerp on numbers)
  GLOW_OPACITY = lerp(0.8, 0.5),
  STRIPE_WIDTH = lerp(8, 8),  -- constant

  -- BG-derived (offset)
  PANEL_BG = offset(-0.06),
})

-- Access computed values (cached, auto-invalidated on theme change)
function M.get_colors()
  local p = ThemeManager.get_script_palette("MyScript")
  if not p then
    return { highlight = Colors.hexrgb("#FF6B6BFF") }
  end

  return {
    highlight = p.HIGHLIGHT,      -- Already RGBA
    badge_text = p.BADGE_TEXT,
    glow_alpha = p.GLOW_OPACITY,  -- Number
    panel_bg = p.PANEL_BG,        -- RGBA (derived from BG_BASE)
  }
end

return M
```

Script palettes support all three modes including `offset` for BG-derived colors.

---

## API Reference

### Mode Selection

```lua
ThemeManager.set_dark()    -- Apply dark preset (t=0)
ThemeManager.set_light()   -- Apply light preset (t=1)
ThemeManager.adapt()       -- Sync with REAPER theme

ThemeManager.set_mode("dark")  -- Same as set_dark()
```

### DSL Wrappers

```lua
local snap = ThemeManager.snap
local lerp = ThemeManager.lerp
local offset = ThemeManager.offset

-- Usage
snap(dark, light, [threshold])   -- discrete snap (default t=0.5)
lerp(dark, light)                -- smooth interpolation
offset(dark, [light], [threshold]) -- BG-relative delta
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

### Debugging

```lua
-- Get current values
local l = ThemeManager.get_theme_lightness()
local t = ThemeManager.get_current_t()

-- Toggle debug window (F12 hotkey also works)
ThemeManager.toggle_debug()

-- Validate palette configuration
local valid, err = ThemeManager.validate()
```

### Custom Themes

```lua
-- Generate from a single base color
local bg = Colors.hexrgb("#3A3A3AFF")
ThemeManager.generate_and_apply(bg)
```

### Script Palette API

```lua
-- Register flat palette
ThemeManager.register_script_palette("ScriptName", {
  MY_COLOR = snap("#AAA", "#555"),
  MY_OPACITY = lerp(0.8, 0.5),
  MY_PANEL = offset(-0.04),
})

-- Get computed palette (cached, invalidated on theme change)
local p = ThemeManager.get_script_palette("ScriptName")
if p then
  local color = p.MY_COLOR    -- RGBA
  local opacity = p.MY_OPACITY -- Number
  local panel = p.MY_PANEL    -- RGBA (BG-derived)
end

-- Unregister when script unloads
ThemeManager.unregister_script_palette("ScriptName")
```

---

## Performance

- **Theme switch**: <0.1ms (table updates)
- **Live sync check**: <1µs (one REAPER API call per second)
- **Per-frame cost**: 0ms (widgets read colors directly)

No rebuild needed - when `Style.COLORS` changes, the next frame uses new colors automatically.
