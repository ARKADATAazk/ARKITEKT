# REFACTOR: Colors Module Cleanup

**Status:** Planning
**Priority:** High
**Created:** 2025-12-02
**Affects:** `arkitekt/core/colors.lua` (774 lines → ~200 lines target)

---

## Executive Summary

The colors module has grown to 70+ functions with inconsistent naming and duplicate functionality. This refactor will:
- Keep HSL (required for ThemeManager DSL)
- Remove legacy/duplicate functions
- Standardize naming conventions
- Use native REAPER/ImGui where appropriate

---

## Decision Log

### ✅ DECIDED: Keep HSL

**Reason:** ThemeManager DSL's `offset()` mode requires HSL lightness adjustment.

HSL vs HSV comparison:
- HSL: "Make lighter" = increase L (one operation)
- HSV: "Make lighter" = increase V AND decrease S (two operations)

HSL is superior for theme offset operations. The ~50 lines of HSL code is worth keeping.

### ✅ DECIDED: Bytes Everywhere

**Decision:** Use raw bytes (`0xRRGGBBAA`) everywhere for maximum optimization.

**Reason:**
- Zero parsing overhead (not even at load time)
- VS Code extension provides color preview for byte format
- Direct integer operations
- Eliminates need for hexrgb() function entirely

**Format:** `0xRRGGBBAA`
```lua
0xFF0000FF  -- Red (R=FF, G=00, B=00, A=FF)
0x00FF00FF  -- Green
0x0000FFFF  -- Blue
0x242424FF  -- Dark gray (theme base)
0xFFFFFF80  -- White, 50% opacity
```

**Migration scope:**
- Widget defaults: Convert hexrgb("#RRGGBB") → 0xRRGGBBAA
- App constants: Convert all defs/constants.lua files
- DSL presets: Convert "#RRGGBB" → 0xRRGGBBAA

**Exception:** Theme DSL `lerp()` mode currently uses hex strings for interpolation.
This will need special handling (see Phase 5).

```lua
-- Before (DSL)
BUTTON_DANGER_BG = lerp("#B91C1C", "#FCA5A5"),

-- After (DSL with bytes)
BUTTON_DANGER_BG = lerp(0xB91C1CFF, 0xFCA5A5FF),

-- Theme.COLORS at runtime: Always bytes (already computed)
local bg = Theme.COLORS.BG_BASE  -- 0x242424FF
```

---

## Current State Analysis

### Functions by Category (70+ total)

| Category | Count | Keep? |
|----------|-------|-------|
| Hex parsing | 4 | ⚠️ TBD |
| HSL operations | 6 | ✅ Keep all |
| Alpha/opacity | 5 | ✅ Keep, rename |
| Component pack/unpack | 2 | ✅ Keep, alias |
| Color manipulation | 10 | ✅ Keep core |
| Format conversion | 4 | 🗑️ Use native |
| Legacy wrappers | 7 | 🗑️ Delete |
| Derive functions | 8 | ⚠️ Review usage |
| Tile-specific | 3 | 🗑️ Move to app |
| Palette generation | 4 | ✅ Keep |
| Sorting/analysis | 4 | ✅ Keep |

### Files with hexrgb() Calls

**Total: 1,302 occurrences across 170 files**

Breakdown:
- `defs/*.lua`, `constants.lua`: Cached at load ✅
- Widget `draw()` functions: Per-frame parsing ❌

---

## Refactoring Plan

### Phase 1: Cleanup Legacy (Low Risk)

**Delete these functions:**
```lua
-- Legacy wrappers (just call derive_* directly)
M.generate_border()
M.generate_hover()
M.generate_active_border()
M.generate_selection_color()
M.generate_marching_ants_color()
M.auto_palette()
M.flashy_palette()
```

**Move to app-specific:**
```lua
-- These belong in scripts/*/defs/colors.lua, not core
M.tile_text_colors()
M.tile_meta_color()
M.same_hue_variant()
```

**Delete duplicate REAPER conversion:**
```lua
-- Keep only one, use native
M.rgb_to_reaper()           -- DELETE (confusing, has edge cases)
M.rgba_to_reaper_native()   -- RENAME to M.to_reaper()
```

### Phase 2: Standardize Naming

**Rename for clarity:**
```lua
-- Current → New
hexrgb()              → hex()           -- or parse_hex() or from_hex()
to_hexrgb()           → to_hex()
to_hexrgba()          → to_hex_alpha()
hexrgba()             → DELETE (confusing, rarely used)

rgba_to_components()  → unpack()
components_to_rgba()  → pack()

with_alpha()          → set_alpha()
with_opacity()        → set_opacity()
get_opacity()         → get_opacity()   -- keep
opacity()             → to_alpha_byte() -- or delete, inline

rgba_to_argb()        → to_imgui()      -- if kept
argb_to_rgba()        → from_imgui()    -- if kept
```

### Phase 3: Fix Widget Defaults

**Problem:** Widgets call hexrgb() in draw functions:
```lua
-- slider.lua:77 - BAD: Parsed every frame
local bg_color = config.bg_color or hexrgb("#1A1A1A")
```

**Solution:** Move to module-level defaults:
```lua
-- Option A: Cached hex parsing
local DEFAULTS = {
    bg = hexrgb("#1A1A1A"),  -- Parsed once at require
}

-- Option B: Raw bytes
local DEFAULTS = {
    bg = 0x1A1A1AFF,  -- Zero parsing
}

-- In draw function:
local bg_color = config.bg_color or DEFAULTS.bg
```

**Files to update:** ~44 widget files (see codebase review)

### Phase 4: Use Native APIs

**Replace with REAPER native:**
```lua
-- Before
local native = Colors.rgba_to_reaper_native(color)

-- After
local r, g, b = Colors.unpack(color)
local native = reaper.ColorToNative(r, g, b) | 0x1000000
```

**Replace with ImGui native (optional):**
```lua
-- Before
local r, g, b, a = Colors.rgba_to_components(color)

-- After (if frequently used with ImGui)
local r, g, b, a = ImGui.ColorConvertU32ToDouble4(color)
```

### Phase 5: Convert All Hex Strings to Bytes

**This is the big migration: 1,302 hexrgb() calls across 170 files**

**5a. Widget defaults (44 files):**
```lua
-- Before
local bg_color = config.bg_color or hexrgb("#1A1A1A")

-- After
local DEFAULTS = { bg = 0x1A1A1AFF }
local bg_color = config.bg_color or DEFAULTS.bg
```

**5b. App constants (defs/constants.lua in each app):**
```lua
-- Before
COLORS = {
    accent = hexrgb("#4A90D9"),
    danger = hexrgb("#E54545"),
}

-- After
COLORS = {
    accent = 0x4A90D9FF,
    danger = 0xE54545FF,
}
```

**5c. Theme DSL (arkitekt/defs/colors/theme.lua):**
```lua
-- Before
M.presets = {
    dark = "#242424",
    light = "#E0E0E0",
}
BUTTON_DANGER_BG = lerp("#B91C1C", "#FCA5A5"),

-- After
M.presets = {
    dark = 0x242424FF,
    light = 0xE0E0E0FF,
}
BUTTON_DANGER_BG = lerp(0xB91C1CFF, 0xFCA5A5FF),
```

**5d. Update theme engine to handle bytes:**
- `engine.lua` currently parses hex strings in lerp mode
- Update to detect number type and skip parsing

**5e. Delete hexrgb() and related functions**

### Phase 6: Final Cleanup

- Remove all @deprecated shims
- Update documentation
- Final testing of all apps

---

## Final API Design

### Minimal Core (~150 lines)

```lua
local Colors = {}

-- ============================================
-- COMPONENTS
-- ============================================
Colors.unpack(color)      -- → r, g, b, a (0-255)
Colors.pack(r, g, b, a)   -- → 0xRRGGBBAA

-- ============================================
-- ALPHA
-- ============================================
Colors.set_alpha(c, a)    -- Set alpha byte (0-255)
Colors.get_alpha(c)       -- Get alpha byte
Colors.set_opacity(c, o)  -- Set alpha from float (0-1)
Colors.get_opacity(c)     -- Get alpha as float

-- ============================================
-- HSL (required for ThemeManager)
-- ============================================
Colors.rgb_to_hsl(color)          -- → h, s, l
Colors.hsl_to_rgb(h, s, l)        -- → r, g, b
Colors.adjust_lightness(c, delta) -- Offset L value
Colors.set_lightness(c, l)        -- Set absolute L
Colors.adjust_saturation(c, delta)
Colors.adjust_hue(c, delta)

-- ============================================
-- MANIPULATION
-- ============================================
Colors.lerp(a, b, t)      -- Interpolate colors
Colors.lighten(c, amt)    -- Convenience for adjust_lightness(+)
Colors.darken(c, amt)     -- Convenience for adjust_lightness(-)
Colors.luminance(c)       -- WCAG luminance (0-1)
Colors.auto_text(bg)      -- Black or white for contrast

-- ============================================
-- REAPER BRIDGE
-- ============================================
Colors.to_reaper(rgba)    -- For REAPER API (BGR + flag)
Colors.from_reaper(native)-- From REAPER API

-- ============================================
-- ANALYSIS & SORTING
-- ============================================
Colors.analyze(color)     -- → { luminance, saturation, is_dark, ... }
Colors.compare(a, b)      -- For sorting by hue
Colors.sort_key(color)    -- → h, s, l for sorting

-- ============================================
-- PALETTE GENERATION
-- ============================================
Colors.derive_palette(base, opts)
Colors.derive_palette_adaptive(base, preset)
```

### Removed from Core

```lua
-- Hex parsing (bytes everywhere, no longer needed):
hexrgb()                  -- DELETE: Use 0xRRGGBBAA directly
hexrgba()                 -- DELETE
to_hexrgb()               -- DELETE (or keep minimal for debug)
to_hexrgba()              -- DELETE

-- Moved to apps or deleted:
tile_text_colors()
tile_meta_color()
same_hue_variant()
generate_*()              -- All 7 legacy functions
flashy_palette()
auto_palette()

-- Use native instead:
rgb_to_reaper()           -- Use reaper.ColorToNative()
rgba_to_argb()            -- Use ImGui.ColorConvertU32ToDouble4 if needed
argb_to_rgba()
```

---

## Migration Checklist

### Phase 1: Preparation
- [ ] Audit hexrgb() usage: identify per-frame vs cached calls
- [ ] Audit derive_*() usage: which apps use which functions
- [ ] Audit tile_*() usage: confirm only used in specific apps

### Phase 2: Non-Breaking Changes
- [ ] Add new aliases (hex, unpack, pack, set_alpha, etc.)
- [ ] Mark old names as @deprecated in comments
- [ ] Add to_reaper() using native API
- [ ] Move tile_*() to app-specific locations

### Phase 3: Widget Fixes (44 files)
- [ ] Move hexrgb() calls from draw() to module DEFAULTS
- [ ] Decision: Use bytes or cached hex for DEFAULTS?
- [ ] Update all 44 widget files

### Phase 4: Cleanup
- [ ] Remove legacy generate_*() functions (find & fix callers first)
- [ ] Remove duplicate rgb_to_reaper()
- [ ] Remove or deprecate old aliases
- [ ] Update documentation

### Phase 5: Final
- [ ] Run all apps, verify themes work
- [ ] Update cookbook/THEME_MANAGER.md
- [ ] Update CLAUDE.md if API changed significantly

---

## Open Questions

1. ~~**Bytes vs Strings for widget defaults?**~~ → ✅ DECIDED: Bytes everywhere

2. ~~**Keep hexrgb() or remove entirely?**~~ → ✅ DECIDED: Remove (bytes everywhere)

3. **Keep argb_to_rgba / rgba_to_argb?**
   - Only needed for ImGui Color3 widgets
   - Check if we actually use Color3 anywhere
   - If not used, delete

4. **derive_*() functions - keep all?**
   - Some may be unused
   - Audit needed before removal

---

## References

- Codebase Review: `/home/user/ARKITEKT/CODEBASE_REVIEW_FULL.md`
- Current colors.lua: `/home/user/ARKITEKT/ARKITEKT/arkitekt/core/colors.lua`
- Theme DSL: `/home/user/ARKITEKT/ARKITEKT/arkitekt/defs/colors/theme.lua`
- Theme Engine: `/home/user/ARKITEKT/ARKITEKT/arkitekt/core/theme_manager/engine.lua`
