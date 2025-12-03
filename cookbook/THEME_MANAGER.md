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
local snap = Theme.snap      -- Discrete switch at t=0.5
local lerp = Theme.lerp      -- Smooth interpolation
local offset = Theme.offset  -- Delta from BG_BASE
local bg = Theme.bg          -- Use BG_BASE directly
```

### `snap(dark, light)` - Discrete Switch

Switches between values at t=0.5 threshold.

```lua
-- Colors: hex strings
TEXT_NORMAL = snap("#FFFFFF", "#000000")  -- White on dark, black on light

-- Numbers
OPACITY = snap(0.8, 0.5)  -- 0.8 on dark, 0.5 on light
```

### `lerp(dark, light)` - Smooth Interpolation

Smoothly interpolates between values.

```lua
-- Colors
ACCENT = lerp("#4CAF50", "#2E7D32")  -- Smooth green gradient

-- Numbers
BRIGHTNESS = lerp(0.5, 0.7)  -- Smooth 0.5→0.7 across themes
```

### `offset(dark_delta, light_delta)` - BG-Derived

Applies lightness delta to BG_BASE. Snaps at t=0.5.

```lua
BG_HOVER = offset(0.03, -0.06)  -- +3% dark, -6% light
BG_PANEL = offset(-0.04)        -- -4% both (light defaults to dark)
```

---

## Script Palette Registration

Register app-specific theme colors that react to theme changes.

```lua
-- In scripts/MyApp/config/palette.lua
local Theme = require('arkitekt.theme')
local snap, lerp, offset = Theme.snap, Theme.lerp, Theme.offset

-- Register at module load
Theme.register_script_palette("MyApp", {
  HIGHLIGHT = snap("#FF6B6B", "#CC4444"),
  ERROR_BG = snap("#240C0C", "#FFDDDD"),
  STRIPE_OPACITY = lerp(0.20, 0.30),
  PANEL_BG = offset(-0.06),
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

  -- Add new color
  MY_NEW_COLOR = snap("#AABBCC", "#334455"),
}
```

Access via `Theme.COLORS.MY_NEW_COLOR`.

### Create Custom Theme

```lua
local Colors = require('arkitekt.core.colors')
local custom_bg = Colors.hex("#3A3A3AFF")
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

-- DSL for palettes
snap("#dark", "#light")   -- discrete switch
lerp("#dark", "#light")   -- smooth interpolation
offset(0.05, -0.10)       -- BG-derived delta

-- Script palettes
Theme.register_script_palette("Name", { ... })
Theme.get_script_palette("Name")

-- REAPER sync
local sync = Theme.create_live_sync(1.0)
sync()  -- Call in main loop
```
