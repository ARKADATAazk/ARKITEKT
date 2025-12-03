# Theme Manager

Dynamic theme system with algorithmic color palette generation for ARKITEKT.

## Quick Start

```lua
local ThemeManager = require('arkitekt.theme.manager')

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
│           offset2() - BG-derived colors                     │
│           snap2()   - discrete dark/light                   │
│           lerp2()   - smooth interpolation                  │
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

Wrappers define HOW values adapt to theme lightness (2-zone and 3-zone variants):

### `offset2(dark, light)` - Delta from BG_BASE (2-zone)

Applies a lightness offset to BG_BASE. **Snaps** between deltas at t=0.5.

```lua
BG_HOVER = offset2(0.03, -0.04)     -- +3% dark, -4% light (snap at 0.5)
BG_PANEL = offset2(-0.04)           -- -4% both (constant)
```

### `lerp2(dark, light)` - Smooth Interpolation (2-zone)

Linearly interpolates between values based on `t`.

```lua
OPACITY = lerp2(0.87, 0.60)                       -- smooth transition
ACCENT  = lerp2(0x334455FF, 0xAABBCCFF)           -- RGB color lerp
```

### `snap2(dark, light)` - Discrete Snap (2-zone)

No interpolation. Picks one value or the other at t=0.5.

```lua
TEXT_NORMAL = snap2(0xFFFFFFFF, 0x000000FF)   -- snap at 0.5
```

### 3-Zone Variants

For finer control over mid-range themes, use the 3-zone variants with transitions at t=0.33 and t=0.67:

```lua
snap3(dark, mid, light)   -- discrete 3-zone switch
lerp3(dark, mid, light)   -- piecewise interpolation
offset3(dark, mid, light) -- 3-zone BG-relative delta
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
  BG_HOVER  = offset2(0.03, -0.04),
  BG_PANEL  = offset2(-0.04),

  -- === TEXT (snap on bytes = color) ===
  TEXT_NORMAL = snap2(0xFFFFFFFF, 0x000000FF),
  TEXT_DIMMED = snap2(0xA0A0A0FF, 0x606060FF),

  -- === VALUES (lerp on numbers = value) ===
  TILE_BRIGHTNESS = lerp2(0.5, 1.4),
  BORDER_OPACITY  = lerp2(0.87, 0.60),
}
```

Type inference:
- `offset2` → Apply delta to BG_BASE → RGBA color
- `snap2`/`lerp2` on byte colors (>255) → RGBA color
- `snap2`/`lerp2` on small numbers → numeric value

---

## Adding New Theme-Aware Values

### 1. Choose the wrapper:

| Behavior | Wrapper |
|----------|---------|
| Delta from BG_BASE (2-zone) | `offset2(d, l)` |
| Smooth gradient (2-zone) | `lerp2(d, l)` |
| Discrete snap (2-zone) | `snap2(d, l)` |
| 3-zone variants | `snap3(d, m, l)`, `lerp3(d, m, l)`, `offset3(d, m, l)` |

### 2. Add to palette:

```lua
M.palette = {
  -- ...existing...
  MY_NEW_BG = offset2(0.08, -0.06),
  MY_NEW_OPACITY = lerp2(0.9, 0.7),
  MY_NEW_COLOR = snap2(0xFF0000FF, 0x00FF00FF),
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
local ThemeManager = require('arkitekt.theme.manager')

local snap2 = ThemeManager.snap2
local lerp2 = ThemeManager.lerp2
local offset2 = ThemeManager.offset2

local M = {}

-- Register flat palette at load time
ThemeManager.register_script_palette("MyScript", {
  -- Colors (snap/lerp on bytes)
  HIGHLIGHT = snap2(0xFF6B6BFF, 0xCC4444FF),
  BADGE_TEXT = snap2(0xFFFFFFFF, 0x1A1A1AFF),
  ERROR_BG = snap2(0x240C0CFF, 0xFFDDDDFF),

  -- Values (lerp on numbers)
  GLOW_OPACITY = lerp2(0.8, 0.5),
  STRIPE_WIDTH = lerp2(8, 8),  -- constant

  -- BG-derived (offset)
  PANEL_BG = offset2(-0.06),
})

-- Access computed values (cached, auto-invalidated on theme change)
function M.get_colors()
  local p = ThemeManager.get_script_palette("MyScript")
  if not p then
    return { highlight = 0xFF6B6BFF }
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

Script palettes support all modes including `offset2` for BG-derived colors and 3-zone variants.

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
-- 2-zone variants (transition at t=0.5)
local snap2 = ThemeManager.snap2
local lerp2 = ThemeManager.lerp2
local offset2 = ThemeManager.offset2

-- 3-zone variants (transitions at t=0.33 and t=0.67)
local snap3 = ThemeManager.snap3
local lerp3 = ThemeManager.lerp3
local offset3 = ThemeManager.offset3

-- Usage
snap2(dark, light)              -- discrete snap at t=0.5
lerp2(dark, light)              -- smooth interpolation
offset2(dark, [light])          -- BG-relative delta
snap3(dark, mid, light)         -- discrete 3-zone snap
lerp3(dark, mid, light)         -- piecewise interpolation
offset3(dark, mid, light)       -- 3-zone BG-relative delta
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
local bg = 0x3A3A3AFF
ThemeManager.generate_and_apply(bg)
```

### Script Palette API

```lua
-- Register flat palette
ThemeManager.register_script_palette("ScriptName", {
  MY_COLOR = snap(0xAAAAAAFF, 0x555555FF),
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
