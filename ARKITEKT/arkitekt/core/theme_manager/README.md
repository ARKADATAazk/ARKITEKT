# Theme Manager

Dynamic theme system with algorithmic color palette generation for ARKITEKT.

## Overview

The Theme Manager generates **entire UI color palettes from just 1-3 base colors** using HSL color space manipulation. This enables:

- **REAPER theme auto-sync**: Match REAPER's current theme automatically
- **Preset themes**: Built-in themes (dark, light, midnight, Pro Tools, etc.)
- **Custom themes**: Generate themes from user-selected colors
- **Live sync**: Automatically update when REAPER's theme changes
- **Smooth transitions**: Animated color transitions between themes

## Quick Start

```lua
local ThemeManager = require('arkitekt.core.theme_manager')

-- Sync with REAPER's current theme (2-3 colors → 25+ UI colors!)
ThemeManager.sync_with_reaper()

-- Or apply a preset theme
ThemeManager.apply_theme("dark")       -- Dark theme (default)
ThemeManager.apply_theme("light")      -- Light theme
ThemeManager.apply_theme("midnight")   -- Very dark theme
ThemeManager.apply_theme("pro_tools")  -- Pro Tools inspired

-- Or generate from custom colors
local bg = Colors.hexrgb("#FF6B6BFF")
local text = Colors.auto_text_color(bg)
ThemeManager.generate_and_apply(bg, text)
```

## How It Works

### Algorithmic Generation

Instead of manually defining 25+ colors, the Theme Manager derives them algorithmically:

**Input (2-3 base colors):**
```lua
base_bg    = RGB(51, 51, 51)     -- REAPER's background
base_text  = RGB(170, 170, 170)  -- REAPER's text color
base_accent = RGB(255, 0, 0)     -- REAPER's time selection
```

**Output (25+ derived colors):**
```lua
BG_BASE        = RGB(51, 51, 51)     ← base_bg
BG_HOVER       = RGB(56, 56, 56)     ← base_bg +2% lightness
BG_ACTIVE      = RGB(61, 61, 61)     ← base_bg +4% lightness
BORDER_OUTER   = RGB(26, 26, 26)     ← base_bg -10% lightness
BORDER_INNER   = RGB(64, 64, 64)     ← base_bg +5% lightness
TEXT_NORMAL    = RGB(170, 170, 170)  ← base_text
TEXT_HOVER     = RGB(187, 187, 187)  ← base_text +5% lightness
ACCENT_PRIMARY = RGB(255, 0, 0)      ← base_accent
... (20+ more colors)
```

### HSL Color Space

All derivations use HSL (Hue, Saturation, Lightness) manipulation:

- **Lightness adjustments**: Create hover/active/dimmed variants
- **Saturation adjustments**: Create muted/vivid variants
- **Hue preservation**: Maintains color harmony

This ensures **mathematically consistent** and **visually harmonious** color relationships.

## API Reference

### Core Functions

#### `generate_palette(base_bg, base_text, base_accent)`
Generate a complete color palette from base colors.

**Parameters:**
- `base_bg` (number): Background color in RGBA format
- `base_text` (number): Text color in RGBA format
- `base_accent` (number, optional): Accent color (defaults to teal)

**Returns:** Table of colors with keys matching `Style.COLORS`

**Example:**
```lua
local palette = ThemeManager.generate_palette(
  Colors.hexrgb("#252525FF"),  -- Dark gray bg
  Colors.hexrgb("#CCCCCCFF"),  -- Light gray text
  Colors.hexrgb("#41E0A3FF")   -- Teal accent
)
```

#### `generate_and_apply(base_bg, base_text, base_accent)`
Generate palette and immediately apply to `Style.COLORS`.

**Example:**
```lua
-- User picks a color
local user_color = Colors.hexrgb("#FF6B6BFF")
local auto_text = Colors.auto_text_color(user_color)

ThemeManager.generate_and_apply(user_color, auto_text)
```

### REAPER Integration

#### `sync_with_reaper()`
Sync with REAPER's current theme.

**Returns:** `true` if successful, `false` if failed to read REAPER colors

**Example:**
```lua
if ThemeManager.sync_with_reaper() then
  print("Synced with REAPER theme!")
end
```

**REAPER Colors Used:**
- `col_main_bg2`: Main window background → `base_bg`
- `col_main_text2`: Main window text → `base_text`
- `col_tl_bgsel`: Time selection → `base_accent`

#### `create_live_sync(interval)`
Create a function for live REAPER theme monitoring.

**Parameters:**
- `interval` (number, optional): Check interval in seconds (default: 1.0)

**Returns:** Function to call in main loop

**Example:**
```lua
local live_sync = ThemeManager.create_live_sync(1.0)

function main_loop()
  live_sync()  -- Checks REAPER theme every second
  draw_ui()
  reaper.defer(main_loop)
end
```

### Preset Themes

#### `apply_theme(name)`
Apply a built-in preset theme.

**Parameters:**
- `name` (string): Theme name

**Returns:** `true` if theme exists, `false` otherwise

**Available Themes:**
- `"dark"`: Default ARKITEKT dark theme
- `"light"`: Light theme
- `"midnight"`: Very dark theme
- `"pro_tools"`: Pro Tools inspired
- `"ableton"`: Ableton inspired (dark with orange)
- `"fl_studio"`: FL Studio inspired (dark with purple)

**Example:**
```lua
ThemeManager.apply_theme("pro_tools")
```

#### `get_theme_names()`
Get list of available theme names.

**Returns:** Array of theme name strings (sorted)

**Example:**
```lua
local themes = ThemeManager.get_theme_names()
for _, name in ipairs(themes) do
  print(name)
end
```

### Smooth Transitions

#### `transition_to_theme(name, duration, on_complete)`
Smoothly transition to a theme with animation.

**Parameters:**
- `name` (string): Theme name
- `duration` (number, optional): Transition duration in seconds (default: 0.3)
- `on_complete` (function, optional): Callback when complete

**Example:**
```lua
ThemeManager.transition_to_theme("light", 0.5, function()
  print("Transition complete!")
end)
```

## Configuration

### Derivation Rules

Customize how colors are derived by modifying `ThemeManager.derivation_rules`:

```lua
-- Default values
ThemeManager.derivation_rules = {
  bg_hover_delta = 0.02,        -- +2% lighter on hover
  bg_active_delta = 0.04,       -- +4% lighter when active
  border_outer_delta = -0.10,   -- -10% darker for borders
  text_dimmed_delta = -0.10,    -- -10% darker for dimmed text
  -- ... etc
}

-- Customize for more contrast on hover
ThemeManager.derivation_rules.bg_hover_delta = 0.05  -- +5% instead of +2%

-- Regenerate with new rules
ThemeManager.sync_with_reaper()  -- Now uses custom deltas
```

## Demo

Run the theme manager demo to test all features:

```
scripts/demos/demo_theme_manager.lua
```

Features in demo:
- Switch between preset themes
- Sync with REAPER theme (manual + live)
- Generate custom themes from example colors
- View current color palette values

## Architecture

### Option 3: Direct References

The theme manager is designed for **Option 3** of the theming refactor:

1. **Theme Manager**: Generates color palettes algorithmically
2. **Style.COLORS**: Single source of truth (updated by Theme Manager)
3. **Widgets**: Read `Style.COLORS` directly every frame

**No rebuild needed** - when `Style.COLORS` changes, the next frame uses new colors automatically.

### Performance

- **Theme switch**: <0.1ms (just table updates)
- **Live sync check**: <1µs (one REAPER API call per second)
- **Per-frame cost**: 0ms (widgets already read colors every frame)

### Future: Widget Refactor

Once widgets are refactored to read `Style.COLORS` directly (not via intermediate preset tables), the system will be fully dynamic with zero overhead.

## Examples

### Basic Usage

```lua
local ThemeManager = require('arkitekt.core.theme_manager')

-- Sync with REAPER on startup
ThemeManager.sync_with_reaper()
```

### Theme Switcher UI

```lua
local themes = ThemeManager.get_theme_names()
local current_theme = "dark"

for _, name in ipairs(themes) do
  if Button.draw(ctx, {
    label = name,
    is_toggled = (name == current_theme),
  }).clicked then
    ThemeManager.apply_theme(name)
    current_theme = name
  end
end
```

### Custom Color Picker

```lua
-- User picks a color in color picker
local user_color = picked_color

-- Auto-generate complementary text color
local text_color = Colors.auto_text_color(user_color)

-- Generate and apply entire theme from this one color!
ThemeManager.generate_and_apply(user_color, text_color)
```

### Smooth Theme Transitions

```lua
-- Animated theme switch (like macOS dark mode)
ThemeManager.transition_to_theme("light", 0.5)
```

## Credits

Uses HSL color manipulation functions from `arkitekt/core/colors.lua`:
- `adjust_lightness()`: Lighten/darken colors
- `adjust_saturation()`: Saturate/desaturate colors
- `adjust_hue()`: Rotate hue
- `rgb_to_hsl()` / `hsl_to_rgb()`: Color space conversion
