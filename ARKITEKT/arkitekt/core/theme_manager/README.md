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
│                            ↓                                │
│                        M.rules                              │
│       (offsetFromBase / lerpDarkLight / snapAtMidpoint)     │
│                            ↓                                │
│                    computed rule values                     │
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

## Unified Rules System

The theme manager uses a **single rules table** with self-documenting wrapper functions. Each rule is defined once with its dark/light behavior baked in.

### Preset Anchors

| Anchor | Lightness | t value |
|--------|-----------|---------|
| `dark` | ~14% | 0.0 |
| `light` | ~88% | 1.0 |

The interpolation factor `t` is computed from current lightness:
```
t = (lightness - 0.14) / (0.88 - 0.14)
```

---

## Rule Wrappers

Four wrappers define HOW values adapt to theme lightness:

### `offsetFromBase(dark, light)` - Delta from BG_BASE

Applies a lightness offset to BG_BASE. **Snaps** between deltas at threshold (no lerp, because BG_BASE already adapts).

```lua
-- Different deltas: snap at t=0.5
bg_hover_delta = offsetFromBase(0.03, -0.04)
-- t < 0.5: +3% (lighter on dark themes)
-- t >= 0.5: -4% (darker on light themes)

-- Same delta: constant offset
bg_panel_delta = offsetFromBase(-0.04)
-- Always -4% (panels darker than base)

-- Custom threshold
special_delta = offsetFromBase(0.05, -0.05, 0.3)
-- Snaps at t=0.3 instead of t=0.5
```

**Why snap instead of lerp?** BG_BASE already changes with lightness. If we lerped the delta, `offsetFromBase(+0.03, -0.03)` would give delta=0 at midpoint (no contrast!). Snapping preserves contrast.

### `lerpDarkLight(dark, light)` - Smooth Interpolation

Linearly interpolates between dark and light values based on `t`.

```lua
-- Numeric lerp
border_opacity = lerpDarkLight(0.87, 0.60)
-- t=0: 0.87, t=0.5: 0.735, t=1: 0.60

-- Color lerp (hex strings)
some_accent = lerpDarkLight("#334455", "#AABBCC")
-- Smoothly transitions through intermediate colors
```

Works with:
- **Numbers**: Linear interpolation
- **Hex colors**: RGB interpolation

### `snapAtMidpoint(dark, light)` - Discrete Snap at t=0.5

No interpolation. Picks one value or the other at the midpoint.

```lua
tile_name_color = snapAtMidpoint("#DDE3E9", "#1A1A1A")
-- t < 0.5: "#DDE3E9" (light text for dark themes)
-- t >= 0.5: "#1A1A1A" (dark text for light themes)
```

Use for:
- Text colors (need hard contrast)
- Semantic colors that shouldn't blend
- Boolean-like choices per theme

### `snapAt(threshold, dark, light)` - Snap at Custom Threshold

Same as `snapAtMidpoint` but at a custom `t` value.

```lua
special_element = snapAt(0.3, "#AAA", "#555")
-- Snaps at t=0.3 (~37% lightness)
```

---

## Rules Table

All rules are defined in `M.rules`:

```lua
M.rules = {
  -- ========== BACKGROUND OFFSETS ==========
  bg_hover_delta = offsetFromBase(0.03, -0.04),      -- Contrast-preserving
  bg_active_delta = offsetFromBase(0.05, -0.07),
  bg_header_delta = offsetFromBase(-0.024, -0.06),
  bg_panel_delta = offsetFromBase(-0.04),            -- Same both (constant)

  -- ========== BORDER COLORS ==========
  border_outer_color = snapAtMidpoint("#000000", "#404040"),
  border_outer_opacity = lerpDarkLight(0.87, 0.60),
  border_inner_delta = offsetFromBase(0.05, -0.03),

  -- ========== TILE RENDERING ==========
  tile_fill_brightness = lerpDarkLight(0.5, 1.4),
  tile_name_color = snapAtMidpoint("#DDE3E9", "#1A1A1A"),

  -- ========== BADGES ==========
  badge_bg_color = snapAtMidpoint("#14181C", "#E8ECF0"),
  badge_text_color = snapAtMidpoint("#FFFFFF", "#1A1A1A"),
  -- ...
}
```

---

## Adding New Theme-Aware Values

### 1. Choose the wrapper:

| Behavior | Wrapper |
|----------|---------|
| Delta from BG_BASE (contrast-preserving) | `offsetFromBase(d, l)` |
| Delta from BG_BASE (constant) | `offsetFromBase(d)` |
| Smooth gradient | `lerpDarkLight(d, l)` |
| Discrete snap at midpoint | `snapAtMidpoint(d, l)` |
| Discrete snap at custom point | `snapAt(t, d, l)` |

### 2. Add to `M.rules`:

```lua
M.rules = {
  -- ...existing rules...
  my_new_delta = offsetFromBase(0.08, -0.06),
  my_new_opacity = lerpDarkLight(0.9, 0.7),
  my_new_color = snapAtMidpoint("#FF0000", "#00FF00"),
}
```

### 3. Use in `generate_palette()`:

```lua
return {
  -- ...existing colors...
  MY_NEW_COLOR = Colors.hexrgb(rules.my_new_color),
  MY_NEW_BG = Colors.adjust_lightness(base_bg, rules.my_new_delta),
}
```

### 4. Access in UI code:

```lua
local color = Style.COLORS.MY_NEW_COLOR
```

---

## Script-Specific Colors

Scripts can define their own colors that follow the theme system:

```lua
-- MyScript/defs/colors.lua
local ThemeManager = require('arkitekt.core.theme_manager')
local Style = require('arkitekt.gui.style')

local M = {}

-- Option 1: Static colors (don't change with theme)
M.STATIC = {
  HIGHLIGHT = 0xFF6B6BFF,
}

-- Option 2: Register with ThemeManager for debug visibility
ThemeManager.register_script_colors("MyScript", M.STATIC)

-- Option 3: Theme-reactive with fallback
function M.get_colors()
  local S = Style.COLORS
  return {
    bg = S.BG_PANEL,           -- Follows theme
    highlight = M.STATIC.HIGHLIGHT,  -- Fixed
  }
end

return M
```

---

## API Reference

### Mode Selection

```lua
ThemeManager.set_dark()    -- Apply dark preset (t=0)
ThemeManager.set_grey()    -- Apply grey (t≈0.14)
ThemeManager.set_light()   -- Apply light preset (t=1)
ThemeManager.adapt()       -- Sync with REAPER theme

ThemeManager.set_mode("dark")  -- Same as set_dark()
```

### Rule Wrappers (for extending rules)

```lua
local offsetFromBase = ThemeManager.offsetFromBase
local lerpDarkLight = ThemeManager.lerpDarkLight
local snapAtMidpoint = ThemeManager.snapAtMidpoint
local snapAt = ThemeManager.snapAt
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
-- Get current computed rules
local rules = ThemeManager.get_current_rules()

-- Get current background lightness
local l = ThemeManager.get_theme_lightness()

-- Get current interpolation factor
local t = ThemeManager.get_current_t()

-- Toggle debug overlay
ThemeManager.toggle_debug()

-- Render debug overlay (in main loop)
ThemeManager.render_debug_overlay(ctx, ImGui)

-- Validate rules configuration
local valid, err = ThemeManager.validate()
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

---

## Legacy API

For backward compatibility, these aliases exist:

```lua
-- Old wrappers (map to new system)
M.blend = function(v) return lerpDarkLight(v, v) end
M.step = function(v) return snapAtMidpoint(v, v) end

-- Legacy presets (via metatable, read-only)
M.presets.dark[key]   -- Returns M.rules[key].dark
M.presets.light[key]  -- Returns M.rules[key].light

M.theme_rules = M.presets
M.theme_anchors = M.preset_anchors
M.derivation_rules  -- Returns dark values
```

---

## Performance

- **Theme switch**: <0.1ms (table updates)
- **Live sync check**: <1µs (one REAPER API call per second)
- **Per-frame cost**: 0ms (widgets read colors directly)

No rebuild needed - when `Style.COLORS` changes, the next frame uses new colors automatically.
