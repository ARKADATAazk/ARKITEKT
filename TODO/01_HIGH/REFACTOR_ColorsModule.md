# REFACTOR: Colors Module Cleanup

**Status:** ✅ COMPLETE (Bytes Migration)
**Priority:** Complete
**Created:** 2025-12-02
**Updated:** 2025-12-03
**Affects:** `arkitekt/core/colors.lua`

---

## Executive Summary

The colors module has been refactored to use byte literals (`0xRRGGBBAA`) for all static colors, eliminating hex string parsing overhead entirely.

**Completed:**
- ✅ Migrated 143 files from `hex('#RRGGBB')` to `0xRRGGBBFF` byte literals
- ✅ Fixed 29 files with conversion errors
- ✅ Removed 128 dead `local hex = Colors.hex` imports
- ✅ Removed legacy functions (~100 lines)
- ✅ `Colors.hex()` retained for runtime conversion only

---

## Decision Log

### ✅ DECIDED: Bytes Everywhere (superseded Memoization)

**Final Decision:** Use byte literals for all static colors.

**Reason (why memoization wasn't enough):**
- Color picker edge case: user dragging generates unique hex strings every frame
- Memoization cache grows unbounded with unique inputs
- Bytes are simpler: just number literals, zero overhead, zero complexity

**Pattern:**
```lua
-- Static colors: use byte literals
local COLORS = {
    red = 0xFF0000FF,      -- Opaque red
    blue = 0x0000FF80,     -- 50% transparent blue
}

-- Dynamic colors: use WithOpacity for computed alpha
local fill = Ark.Colors.WithOpacity(base_color, 0.5)

-- Runtime user input: use hex() to convert strings
local user_color = Colors.hex(user_input)  -- Theme manager, palettes
```

**What was migrated:**
- `hex('#RRGGBB')` → `0xRRGGBBFF`
- `hex('#RRGGBBAA')` → `0xRRGGBBAA`
- `hex('#RRGGBB', 0.5)` → `Colors.WithOpacity(0xRRGGBBFF, 0.5)`

### ✅ DECIDED: Keep HSL

**Reason:** ThemeManager DSL's `offset()` mode requires HSL lightness adjustment.

HSL vs HSV comparison:
- HSL: "Make lighter" = increase L (one operation)
- HSV: "Make lighter" = increase V AND decrease S (two operations)

---

## Migration Summary

### Files Modified

| Phase | Files | Description |
|-------|-------|-------------|
| Bytes conversion | 143 | `hex('#...')` → `0x...FF` |
| Error fixes | 29 | Fixed `Colors.0x...` patterns |
| Import cleanup | 128 | Removed dead `local hex =` lines |
| **Total unique** | ~180 | Across entire codebase |

### Functions Removed from colors.lua

**Legacy wrappers (deleted):**
- `generate_border()`
- `generate_hover()`
- `generate_active_border()`
- `generate_selection_color()`
- `generate_marching_ants_color()`
- `auto_palette()`
- `flashy_palette()`

**Unused utilities (deleted):**
- `rgb_to_reaper()`
- `tile_text_colors()`
- `tile_meta_color()`
- `to_opacity()`
- `lerp_component()`

**Result:** 828 → 728 lines (-100 lines)

---

## Current API

### What remains in colors.lua

**Core:**
- `hex(hex_string, opacity?)` - Parse hex strings (for runtime/user input)
- `WithOpacity(color, opacity)` - Set opacity on byte color
- `unpack(color)` → r, g, b, a
- `pack(r, g, b, a)` → color

**HSL (for ThemeManager):**
- `rgb_to_hsl()`, `hsl_to_rgb()`
- `adjust_lightness()`, `adjust_saturation()`, `adjust_hue()`
- `lighten()`, `darken()`

**Manipulation:**
- `lerp()` - Interpolate colors
- `luminance()` - WCAG luminance
- `auto_text()` - Black/white for contrast

**Palette:**
- `derive_palette()`, `derive_palette_adaptive()`

### Where hex() is still used

Runtime conversion needed (correct usage):
- `arkitekt/theme/manager/` - User theme definitions
- `arkitekt/config/colors/theme.lua` - Dynamic theme colors
- `scripts/TemplateBrowser/` - User color palettes

---

## Scripts Created

Located in `Utils/Python/`:

1. **`hex_to_bytes.py`** - Converts `hex('#...')` to byte literals
2. **`fix_bytes_conversion.py`** - Fixes conversion errors
3. **`remove_dead_hex_imports.py`** - Removes unused imports

---

## Future Considerations

### Optional Cleanup (Low Priority)

- [ ] Audit `argb_to_rgba` / `rgba_to_argb` usage
- [ ] Review `derive_*()` functions for unused ones
- [ ] Consider removing `hex()` aliases (`Hexrgb`, `hexrgb`)

### Not Needed

- Widget default fixes - byte literals solve this
- Per-frame caching - no string parsing in hot paths
- Memoization complexity - eliminated entirely

---

## References

- Colors module: `arkitekt/core/colors.lua`
- Theme DSL: `arkitekt/config/colors/theme.lua`
- Theme Engine: `arkitekt/theme/manager/engine.lua`
