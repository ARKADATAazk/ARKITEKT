# ThemeManager Cleanup

## Status: COMPLETED

The hardcoded fallback values have been removed. `M.COLORS` is now generated from DSL at require time.

### What Changed
- Removed ~45 lines of hardcoded color values from `arkitekt/theme/init.lua`
- Added DSL generation at require time using `Engine.generate_palette(DEFAULT_BASE_BG)`
- Single source of truth: `DEFAULT_BASE_BG = 0x242424FF` (dark theme base)

### Benefits
- DSL in `config/colors/theme.lua` is now THE single source of truth
- No duplicate values to maintain
- Pattern colors (with alpha) are correctly generated from DSL

---

## Original Problem (for reference)

`arkitekt/theme/init.lua` contained hardcoded fallback values in `M.COLORS`:

```lua
M.COLORS = {
  BG_BASE        = 0x242424FF,
  BG_HOVER       = 0x2A2A2AFF,
  BG_PANEL       = 0x1A1A1AFF,
  -- ... 30+ more hardcoded values
}
```

These didn't make sense because:
1. **ThemeManager always generates colors** from a base color using the DSL in `config/colors/theme.lua`
2. **The palette DSL is the source of truth** - it defines how colors derive from `BG_BASE`
3. **Hardcoded defaults are never used** in practice since `generate_and_apply()` overwrites them on startup
4. **Maintenance burden** - two places to update when changing color relationships

## Architecture

```
User selects theme preset (dark/grey/light)
         │
         ▼
Presets.apply(name) → gets base BG color (e.g., 0x242424FF for 'dark')
         │
         ▼
Theme.generate_and_apply(base_bg)
         │
         ▼
Engine.generate_palette(base_bg) → processes config/colors/theme.lua DSL
         │
         ▼
Overwrites Theme.COLORS with generated values
```

## Files Involved

| File | Purpose | Issue |
|------|---------|-------|
| `arkitekt/theme/init.lua` | Exports `M.COLORS` table | Contains hardcoded fallbacks that are always overwritten |
| `arkitekt/config/colors/theme.lua` | DSL palette definitions | **Source of truth** - defines all color relationships |
| `arkitekt/theme/manager/engine.lua` | Generates palette from DSL | Processes theme.lua and outputs to Theme.COLORS |
| `arkitekt/theme/manager/presets.lua` | Theme presets (dark/light/etc) | Triggers palette generation |

## Proposed Cleanup

### Phase 1: Document Current State
- [x] Create this TODO document
- [ ] Audit all color keys in both files
- [ ] Verify 1:1 correspondence between hardcoded and DSL-defined colors

### Phase 2: Simplify Theme.COLORS Initialization
**Option A: Empty table, populate on first use**
```lua
M.COLORS = {}  -- Populated by generate_and_apply() on startup

-- Ensure theme is applied before first use
function M.ensure_initialized()
  if not M._initialized then
    M.apply_theme('dark')  -- Default theme
    M._initialized = true
  end
end
```

**Option B: Generate defaults at require time**
```lua
-- Generate default palette immediately (no hardcoded values)
local Engine = require('arkitekt.theme.manager.engine')
local default_bg = 0x242424FF  -- Single source: dark theme base
M.COLORS = Engine.generate_palette(default_bg)
```

**Option C: Keep hardcoded but auto-generate from DSL** (build step)
- Script that generates hardcoded values from DSL
- Ensures consistency, but adds build complexity

### Phase 3: Verify No Require-Time Color Access
Some code might access `Theme.COLORS.X` at module load time before theme is applied. Audit for:
```lua
-- BAD: Captures value at require time
local my_bg = Theme.COLORS.BG_PANEL

-- GOOD: Reads dynamically at runtime
local function get_bg()
  return Theme.COLORS.BG_PANEL
end
```

### Phase 4: Remove Redundant Fallbacks
Once verified safe, remove hardcoded values from `theme/init.lua`.

## Risk Assessment

**Low Risk:**
- Theme is applied early in app startup (shell.lua)
- Most widgets read Theme.COLORS at draw time, not require time

**Potential Issues:**
- Code that caches Theme.COLORS values at module load
- Tests that don't initialize theme
- Edge cases where theme isn't applied yet

## Notes

- The pattern color fix (snap2 with alpha) should remain - that was a real bug
- Config caches (`_button_config_cache`, etc.) already invalidate on theme change
- Registry system handles dynamic color lookups correctly
