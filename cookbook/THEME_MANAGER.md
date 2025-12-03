# ThemeManager Guide

> Dynamic theming system for ARKITEKT with REAPER integration.

## Quick Start

```lua
local Theme = require('arkitekt.theme')

-- Set theme
Theme.set_dark()                    -- Dark preset
Theme.set_light()                   -- Light preset
Theme.adapt()                       -- Sync with REAPER

-- Access colors (read every frame, not at init!)
local bg = Theme.COLORS.BG_BASE
local text = Theme.COLORS.TEXT_NORMAL

-- Widget config builders
local btn_config = Theme.build_button_config()
```

---

## Core Concept: Dynamic Colors

**Critical**: Read `Theme.COLORS` during render, not at initialization.

```lua
-- CORRECT: Fresh colors each frame
function draw_widget(ctx)
  local bg = Theme.COLORS.BG_BASE  -- Gets current theme color
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg)
end

-- WRONG: Cached at load time (stale when theme changes)
local BG = Theme.COLORS.BG_BASE  -- Outdated after theme switch!
function draw_widget(ctx)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, BG)
end
```

---

## API Reference

### Theme Selection

| Method | Purpose |
|--------|---------|
| `Theme.set_dark()` | Apply dark preset (t=0) |
| `Theme.set_light()` | Apply light preset (t=1) |
| `Theme.adapt()` | Sync with REAPER's current theme |
| `Theme.set_mode(mode, persist)` | Set by name with optional persistence |
| `Theme.init(default_mode)` | Initialize from saved preference |

### Color Access

| Method | Purpose |
|--------|---------|
| `Theme.COLORS` | All computed colors (read every frame) |
| `Theme.get_theme_lightness()` | Current lightness (0.0-1.0) |
| `Theme.get_t()` | Interpolation factor (0=dark, 1=light) |
| `Theme.generate_and_apply(base_bg)` | Apply custom base color |

### Config Builders

```lua
Theme.build_button_config()                  -- Standard button
Theme.build_colored_button_config("danger")  -- danger/success/warning/info
Theme.build_dropdown_config()                -- Dropdown menu
Theme.build_search_input_config()            -- Search field
Theme.build_tooltip_config()                 -- Tooltips
Theme.build_panel_colors()                   -- Panel/tabs/scrollbars
```

### REAPER Integration

```lua
-- One-time sync
Theme.sync_with_reaper()              -- Match REAPER with slight offset
Theme.sync_with_reaper_no_offset()    -- Exact match (for docking)

-- Live sync (in main loop)
local sync = Theme.create_live_sync(1.0)  -- Check every 1 second
function main_loop()
  sync()  -- Non-blocking
  draw_ui()
  reaper.defer(main_loop)
end
```

---

## Available Colors

### Backgrounds
```lua
Theme.COLORS.BG_BASE      -- Main background
Theme.COLORS.BG_HOVER     -- Hover state
Theme.COLORS.BG_ACTIVE    -- Active/pressed state
Theme.COLORS.BG_PANEL     -- Panel backgrounds
Theme.COLORS.BG_HEADER    -- Headers
Theme.COLORS.BG_CHROME    -- Window chrome
```

### Text
```lua
Theme.COLORS.TEXT_NORMAL  -- Primary text
Theme.COLORS.TEXT_DIMMED  -- Secondary text
Theme.COLORS.TEXT_HOVER   -- Hover state
Theme.COLORS.TEXT_ACTIVE  -- Active state
```

### Borders
```lua
Theme.COLORS.BORDER_OUTER -- Outer border
Theme.COLORS.BORDER_INNER -- Inner border
Theme.COLORS.BORDER_HOVER -- Hover border
Theme.COLORS.BORDER_FOCUS -- Focus ring
```

### Accents
```lua
Theme.COLORS.ACCENT_PRIMARY  -- Primary accent
Theme.COLORS.ACCENT_TEAL     -- Teal variant
Theme.COLORS.ACCENT_SUCCESS  -- Green
Theme.COLORS.ACCENT_WARNING  -- Orange
Theme.COLORS.ACCENT_DANGER   -- Red
```

### Operations (drag/drop feedback)
```lua
Theme.COLORS.OP_MOVE    -- Move operation
Theme.COLORS.OP_COPY    -- Copy operation
Theme.COLORS.OP_DELETE  -- Delete operation
Theme.COLORS.OP_LINK    -- Link operation
```

### Colored Buttons (4 variants × 4 states)
```lua
Theme.COLORS.BUTTON_DANGER_BG      -- Danger button background
Theme.COLORS.BUTTON_DANGER_HOVER   -- Danger hover
Theme.COLORS.BUTTON_DANGER_ACTIVE  -- Danger active
Theme.COLORS.BUTTON_DANGER_TEXT    -- Danger text
-- Also: SUCCESS, WARNING, INFO variants
```

---

## DSL System (Defining Palettes)

### DSL Wrappers

```lua
-- 2-zone variants (transition at t=0.5)
local snap2 = Theme.snap2      -- Discrete switch at t=0.5
local lerp2 = Theme.lerp2      -- Smooth interpolation
local offset2 = Theme.offset2  -- Delta from BG_BASE
local bg = Theme.bg            -- Use BG_BASE directly

-- 3-zone variants (transitions at t=0.33 and t=0.67)
local snap3 = Theme.snap3      -- Discrete 3-zone switch
local lerp3 = Theme.lerp3      -- Piecewise interpolation
local offset3 = Theme.offset3  -- 3-zone BG delta
```

### `snap2(dark, light)` - Discrete Switch (2-zone)

Switches between values at t=0.5 threshold.

```lua
-- Colors (use byte format 0xRRGGBBAA)
TEXT_NORMAL = snap2(0xFFFFFFFF, 0x000000FF)  -- White on dark, black on light

-- Numbers
OPACITY = snap2(0.8, 0.5)  -- 0.8 on dark, 0.5 on light
```

### `lerp2(dark, light)` - Smooth Interpolation (2-zone)

Smoothly interpolates between values.

```lua
-- Colors
ACCENT = lerp2(0x4CAF50FF, 0x2E7D32FF)  -- Smooth green gradient

-- Numbers
BRIGHTNESS = lerp2(0.5, 0.7)  -- Smooth 0.5→0.7 across themes
```

### `offset2(dark_delta, light_delta)` - BG-Derived (2-zone)

Applies lightness delta to BG_BASE. Snaps at t=0.5.

```lua
BG_HOVER = offset2(0.03, -0.06)  -- +3% dark, -6% light
BG_PANEL = offset2(-0.04)        -- -4% both (light defaults to dark)
```

### 3-Zone Variants

For finer control over mid-range themes (grey, light_grey):

```lua
-- snap3: discrete zones at t=0.33 and t=0.67
TEXT_SPECIAL = snap3(0xFFFFFFFF, 0xCCCCCCFF, 0x000000FF)

-- lerp3: piecewise interpolation through mid-point
ACCENT = lerp3(0x4CAF50FF, 0x66BB6AFF, 0x2E7D32FF)

-- offset3: 3-zone BG-relative deltas
BG_SPECIAL = offset3(0.05, 0.02, -0.08)
```

---

## Script Palette Registration

Register app-specific theme colors that react to theme changes.

```lua
-- In scripts/MyApp/config/palette.lua
local Theme = require('arkitekt.theme')
local snap2, lerp2, offset2 = Theme.snap2, Theme.lerp2, Theme.offset2

-- Register at module load
Theme.register_script_palette("MyApp", {
  HIGHLIGHT = snap2(0xFF6B6BFF, 0xCC4444FF),
  ERROR_BG = snap2(0x240C0CFF, 0xFFDDDDFF),
  STRIPE_OPACITY = lerp2(0.20, 0.30),
  PANEL_BG = offset2(-0.06),
})

-- Access in another module
local p = Theme.get_script_palette("MyApp")
if p then
  local color = p.HIGHLIGHT
  local opacity = p.STRIPE_OPACITY
end

-- Cleanup on script exit
Theme.unregister_script_palette("MyApp")
```

---

## App Initialization Pattern

```lua
-- In scripts/MyApp/ARK_MyApp.lua
local Theme = require('arkitekt.theme')

-- Initialize theme
Theme.init("adapt")  -- Load saved or default to REAPER sync

-- Live REAPER sync
local sync = Theme.create_live_sync(1.0)

function main_loop()
  sync()  -- Non-blocking check
  draw_ui()
  reaper.defer(main_loop)
end

main_loop()
```

---

## File Structure

```
arkitekt/
├── theme/                     # Main theme module
│   ├── init.lua               # Public API entry point
│   └── manager/
│       ├── engine.lua         # Palette generation
│       ├── integration.lua    # REAPER sync, persistence
│       ├── registry.lua       # Script palette registration
│       └── presets.lua        # Preset application
│
└── config/
    └── colors/
        ├── init.lua           # Entry point
        ├── theme.lua          # DSL definitions & palette
        └── static.lua         # Wwise color palette
```

---

## Common Tasks

### Add a New Theme Color

Edit `arkitekt/config/colors/theme.lua`:

```lua
M.colors = {
  -- ... existing colors ...

  -- Add new color (use byte format 0xRRGGBBAA)
  MY_NEW_COLOR = snap2(0xAABBCCFF, 0x334455FF),
}
```

Access via `Theme.COLORS.MY_NEW_COLOR`.

### Create Custom Theme

```lua
local custom_bg = 0x3A3A3AFF  -- Use byte format directly
Theme.generate_and_apply(custom_bg)
```

### Smooth Theme Transition

```lua
Theme.transition_to_theme("light", 0.3, function()
  print("Transition complete")
end)
```

### Debug Theme Colors

```lua
Theme.toggle_debug()  -- Opens debug window
-- Or press F12 (requires Theme.check_debug_hotkey in loop)
```

---

## Gotchas

| Gotcha | Solution |
|--------|----------|
| Colors stale after theme switch | Read `Theme.COLORS` every frame, not at init |
| Script palette not updating | Make sure `register_script_palette` was called at module load |
| REAPER sync not working | Call `sync()` in main loop, not just once |
| Docked window color mismatch | Use `sync_with_reaper_no_offset()` for exact match |
| Offset not smooth | Offset uses snap (discrete), use lerp for smooth |

---

## Performance

- Theme switch: <0.1ms
- Live sync check: <1µs/second
- Per-frame cost: 0ms (just table reads)
- No rebuild needed on color change

---

## Quick Reference Card

```lua
-- Import
local Theme = require('arkitekt.theme')

-- Set theme
Theme.set_dark() / Theme.set_light() / Theme.adapt()

-- Read colors (every frame)
Theme.COLORS.BG_BASE, Theme.COLORS.TEXT_NORMAL, etc.

-- Config builders
Theme.build_button_config()
Theme.build_colored_button_config("danger")

-- DSL for palettes (2-zone)
snap2(0xDARKCOLOR, 0xLIGHTCOLOR)  -- discrete switch at t=0.5
lerp2(0xDARKCOLOR, 0xLIGHTCOLOR)  -- smooth interpolation
offset2(0.05, -0.10)              -- BG-derived delta

-- DSL for palettes (3-zone)
snap3(dark, mid, light)   -- discrete at t=0.33, 0.67
lerp3(dark, mid, light)   -- piecewise interpolation
offset3(dark, mid, light) -- 3-zone BG delta

-- Script palettes
Theme.register_script_palette("Name", { ... })
Theme.get_script_palette("Name")

-- REAPER sync
local sync = Theme.create_live_sync(1.0)
sync()  -- Call in main loop
```
