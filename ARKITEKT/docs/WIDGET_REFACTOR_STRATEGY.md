# Widget Refactor Strategy: Option 3 Implementation

## Overview

Refactor widgets to read `Style.COLORS` directly, eliminating intermediate preset tables for truly dynamic theming with zero rebuild.

## Scope Analysis

**Total widgets**: 69 files
**Widgets needing refactor**: 5 primitives
- `button.lua`
- `checkbox.lua`
- `combo.lua` (includes dropdown)
- `corner_button.lua`
- `inputtext.lua` (includes search input)

**Why so few?** Most widgets (64) are containers, data displays, or composites that don't manage their own colors - they use the 5 primitives above.

## Current Architecture (Baked)

```lua
// Module load time - VALUES are copied:
M.COLORS.BG_BASE = 0x252525FF

M.BUTTON_COLORS.bg = M.COLORS.BG_BASE  // Copies 0x252525FF

M.BUTTON.bg_color = M.BUTTON_COLORS.bg  // Copies 0x252525FF

// Every frame - widgets read static preset:
local config = Style.apply_defaults(Style.BUTTON, user_opts)
config.bg_color = 0x252525FF  // Still old value!
```

**Problem**: Changing `M.COLORS.BG_BASE` at runtime doesn't propagate.

## Target Architecture (Dynamic)

```lua
// Module load time - only define keys:
M.COLORS.BG_BASE = 0x252525FF

// NO intermediate tables needed!

// Every frame - widgets read M.COLORS directly:
local config = {
  bg_color = M.COLORS.BG_BASE,  // Reads CURRENT value
  bg_hover_color = M.COLORS.BG_HOVER,
  // ...
}

// Theme change:
M.COLORS.BG_BASE = 0xE5E5E5FF  // Next frame uses new value!
```

**Benefit**: Direct memory read, truly dynamic, zero rebuild.

## Refactoring Steps

### Phase 1: Eliminate Intermediate Tables (defaults.lua)

**Remove:**
- `M.BUTTON_COLORS` table
- `M.PANEL_COLORS` table
- `M.DROPDOWN_COLORS` table
- `M.SEARCH_INPUT_COLORS` table
- `M.TOOLTIP_COLORS` table

**Keep:**
- `M.COLORS` (single source of truth)
- `M.RENDER` utilities
- Helper functions

**Replace:**
- `M.BUTTON`, `M.DROPDOWN`, etc. presets → Functions that return configs
- Or eliminate entirely and build in widgets

### Phase 2: Refactor Widgets

For each of the 5 widgets:

#### **Before** (button.lua:187-197):
```lua
local function resolve_config(opts)
  local base = Style.BUTTON  -- Static preset

  if opts.preset_name and Style[opts.preset_name] then
    base = Style.apply_defaults(base, Style[opts.preset_name])
  end

  return Style.apply_defaults(base, opts)
end
```

#### **After**:
```lua
local function resolve_config(opts)
  -- Build config from M.COLORS directly
  local config = {
    -- Backgrounds
    bg_color = Style.COLORS.BG_BASE,
    bg_hover_color = Style.COLORS.BG_HOVER,
    bg_active_color = Style.COLORS.BG_ACTIVE,
    bg_disabled_color = Colors.adjust_lightness(Style.COLORS.BG_BASE, -0.05),

    -- Borders
    border_outer_color = Style.COLORS.BORDER_OUTER,
    border_inner_color = Style.COLORS.BORDER_INNER,
    border_hover_color = Style.COLORS.BORDER_HOVER,
    border_active_color = Style.COLORS.BORDER_ACTIVE,

    -- Text
    text_color = Style.COLORS.TEXT_NORMAL,
    text_hover_color = Style.COLORS.TEXT_HOVER,
    text_active_color = Style.COLORS.TEXT_ACTIVE,
    text_disabled_color = Style.COLORS.TEXT_DIMMED,

    -- Geometry
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }

  -- Apply preset if specified
  if opts.preset_name then
    apply_preset(config, opts.preset_name)
  end

  -- User overrides
  for k, v in pairs(opts) do
    if v ~= nil and config[k] ~= nil then
      config[k] = v
    end
  end

  return config
end
```

### Phase 3: Preset System Redesign

Presets become **key mappings** instead of color values:

```lua
-- defaults.lua
M.PRESETS = {
  BUTTON_TOGGLE_TEAL = {
    -- ON state colors (map to M.COLORS keys)
    bg_on_color = "ACCENT_TEAL",
    bg_on_hover_color = "ACCENT_TEAL_BRIGHT",
    text_on_color = "ACCENT_TEAL_BRIGHT",
    border_inner_on_color = "ACCENT_TEAL_BRIGHT",
  },

  BUTTON_TOGGLE_WHITE = {
    bg_on_color = "ACCENT_WHITE",
    bg_on_hover_color = "ACCENT_WHITE_BRIGHT",
    text_on_color = "TEXT_BRIGHT",
    border_inner_on_color = "ACCENT_WHITE_BRIGHT",
  },

  BUTTON_TOGGLE_TRANSPARENT = {
    bg_on_color = "ACCENT_TRANSPARENT",
    -- ...
  },
}

-- Widget applies preset by resolving keys:
local function apply_preset(config, preset_name)
  local preset = Style.PRESETS[preset_name]
  if not preset then return end

  for key, color_key in pairs(preset) do
    if type(color_key) == "string" then
      -- Resolve key to actual color
      config[key] = Style.COLORS[color_key]
    else
      -- Direct color value
      config[key] = color_key
    end
  end
end
```

## Migration Strategy

### Option A: Big Bang (Fast, Risky)
Refactor all 5 widgets + defaults.lua in one commit.

**Pros**: Clean, immediate results
**Cons**: High conflict risk with pending branch

### Option B: Incremental (Slow, Safe)
1. Refactor defaults.lua first (keep old presets for compat)
2. Refactor one widget at a time
3. Remove old presets when all widgets migrated

**Pros**: Lower conflict risk
**Cons**: Temporary code duplication

### Option C: Parallel Systems (Safest)
Keep old system working while building new:

```lua
-- defaults.lua (transition period)
M.BUTTON_COLORS = {...}  -- Old system (deprecated)

M.get_button_colors = function()  -- New system
  return {
    bg_color = M.COLORS.BG_BASE,
    -- ...
  }
end

-- Widgets check for new function first:
local base = Style.get_button_colors and Style.get_button_colors() or Style.BUTTON
```

**Pros**: Zero breaking changes
**Cons**: Most code to maintain

## Recommended: Option B with Helper Functions

### Step 1: Add helper to defaults.lua
```lua
-- New dynamic config builders
function M.build_button_config()
  return {
    bg_color = M.COLORS.BG_BASE,
    bg_hover_color = M.COLORS.BG_HOVER,
    -- ... all colors
  }
end

function M.build_dropdown_config()
  return {
    bg_color = M.COLORS.BG_BASE,
    -- ... all colors
  }
end
```

### Step 2: Update widgets one by one
```lua
-- button.lua
local function resolve_config(opts)
  local config = Style.build_button_config()  -- Dynamic!

  if opts.preset_name then
    apply_preset(config, opts.preset_name)
  end

  merge_user_opts(config, opts)
  return config
end
```

### Step 3: Remove old presets when done
```lua
-- Delete M.BUTTON_COLORS, M.BUTTON, etc.
```

## Testing Strategy

1. **Visual regression tests**: Compare screenshots before/after
2. **Theme change test**: Apply theme, verify all widgets update
3. **REAPER sync test**: Change REAPER theme, verify UI matches
4. **Performance test**: Measure frame time impact (should be 0ms)

## Validation Checklist

For each refactored widget:
- [ ] No static color values in config resolution
- [ ] All colors read from `M.COLORS` or derived dynamically
- [ ] Preset system works (if applicable)
- [ ] User color overrides still work
- [ ] Theme changes apply immediately (no restart)
- [ ] No performance regression

## Risk Assessment

**Low Risk Areas**:
- Adding new `M.build_*_config()` functions
- Refactoring `button.lua` (most isolated)
- Refactoring `corner_button.lua` (simple)

**Medium Risk Areas**:
- Refactoring `combo.lua` (complex, has popup logic)
- Preset system redesign (breaking change)

**High Risk Areas**:
- Panel widgets (if touched - but might not need changes)
- Apps using custom presets (need migration guide)

## Timeline Estimate

Assuming no conflicts with pending branch:
- **Phase 1** (defaults.lua helpers): 1 hour
- **Phase 2** (5 widget refactors): 3-4 hours
- **Phase 3** (preset redesign): 2 hours
- **Testing & validation**: 2 hours

**Total**: ~8-9 hours for complete migration

## Next Steps

1. Wait for pending widget branch to merge (avoid conflicts)
2. Create helpers in defaults.lua
3. Refactor button.lua as template
4. Apply pattern to remaining 4 widgets
5. Test with theme manager demo
6. Update documentation

## Success Criteria

✅ Change `M.COLORS.BG_BASE` → All buttons update next frame
✅ `ThemeManager.sync_with_reaper()` → Entire UI matches REAPER
✅ `ThemeManager.apply_theme("light")` → Instant theme switch
✅ Zero performance regression (<0.01ms per frame)
✅ All existing apps still work (backward compatible)
