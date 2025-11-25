-- @noindex
-- Widget Refactor Example: Before & After (Option 3)
-- This file shows the refactoring pattern for dynamic theming

-- ============================================================================
-- BEFORE: Static Presets (Baked at Module Load)
-- ============================================================================

-- OLD VERSION (button.lua before refactor):
local Style = require('arkitekt.gui.style.defaults')

local function resolve_config_OLD(opts)
  -- Problem: Style.BUTTON is a static table, copied at module load time
  local base = Style.BUTTON  -- Contains 0x252525FF (baked value)

  -- Apply preset (also static)
  if opts.preset_name and Style[opts.preset_name] then
    base = Style.apply_defaults(base, Style[opts.preset_name])
  elseif opts.preset and type(opts.preset) == 'table' then
    base = Style.apply_defaults(base, opts.preset)
  end

  -- User config
  return Style.apply_defaults(base, opts)
end

-- Result: Changing Style.COLORS.BG_BASE doesn't affect buttons
-- because base.bg_color = 0x252525FF (old value)

-- ============================================================================
-- AFTER: Dynamic Config Builder (Reads M.COLORS Every Frame)
-- ============================================================================

-- NEW VERSION (button.lua after refactor):
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')

local function resolve_config_NEW(opts)
  -- Build config from CURRENT M.COLORS values
  local config = Style.build_button_config()  -- Reads M.COLORS NOW

  -- Apply dynamic preset (resolves keys to colors)
  if opts.preset_name then
    Style.apply_dynamic_preset(config, opts.preset_name)
  end

  -- User overrides (color values or direct hex)
  for key, value in pairs(opts) do
    -- Skip metadata keys
    if key ~= "preset_name" and key ~= "preset" and key ~= "id" then
      if value ~= nil and config[key] ~= nil then
        config[key] = value
      end
    end
  end

  return config
end

-- Result: Changing Style.COLORS.BG_BASE immediately affects buttons
-- because build_button_config() reads CURRENT value every call

-- ============================================================================
-- DETAILED COMPARISON
-- ============================================================================

--[[ OLD FLOW (Static):

Module Load Time:
  Style.COLORS.BG_BASE = 0x252525FF
  Style.BUTTON_COLORS.bg = Style.COLORS.BG_BASE  -- Copies 0x252525FF
  Style.BUTTON.bg_color = Style.BUTTON_COLORS.bg -- Copies 0x252525FF

Frame 1:
  config = resolve_config({label = "Click"})
  config.bg_color = 0x252525FF  -- From Style.BUTTON

Runtime Theme Change:
  Style.COLORS.BG_BASE = 0xE5E5E5FF  -- Light background

Frame 2:
  config = resolve_config({label = "Click"})
  config.bg_color = 0x252525FF  -- STILL OLD VALUE!
  ❌ Button doesn't update

]]

--[[ NEW FLOW (Dynamic):

Module Load Time:
  Style.COLORS.BG_BASE = 0x252525FF
  -- No intermediate copies!

Frame 1:
  config = Style.build_button_config()
  -- Inside build_button_config():
  --   bg_color = M.COLORS.BG_BASE  -- Reads 0x252525FF
  config.bg_color = 0x252525FF

Runtime Theme Change:
  Style.COLORS.BG_BASE = 0xE5E5E5FF  -- Light background

Frame 2:
  config = Style.build_button_config()
  -- Inside build_button_config():
  --   bg_color = M.COLORS.BG_BASE  -- Reads 0xE5E5E5FF (NEW!)
  config.bg_color = 0xE5E5E5FF
  ✅ Button updates automatically!

]]

-- ============================================================================
-- PRESET SYSTEM: Before & After
-- ============================================================================

--[[ OLD PRESET (Static Color Values):

Style.BUTTON_TOGGLE_TEAL = {
  bg_on_color = 0x295650FF,           -- Baked hex value
  bg_on_hover_color = 0x2E6459FF,
  text_on_color = 0x41E0A3FF,
  -- ...
}

Problem: These hex values never change, even if theme changes

]]

--[[ NEW PRESET (Key Mappings):

Style.DYNAMIC_PRESETS.BUTTON_TOGGLE_TEAL = {
  bg_on_color = "ACCENT_TEAL",              -- Key into M.COLORS
  bg_on_hover_color = "ACCENT_TEAL_BRIGHT", -- Resolved at apply time
  text_on_color = "ACCENT_TEAL_BRIGHT",
  -- ...
}

-- When applied:
function Style.apply_dynamic_preset(config, "BUTTON_TOGGLE_TEAL")
  config.bg_on_color = M.COLORS["ACCENT_TEAL"]  -- Reads CURRENT value
  config.text_on_color = M.COLORS["ACCENT_TEAL_BRIGHT"]
end

Benefit: Presets adapt to theme changes automatically

]]

-- ============================================================================
-- MIGRATION CHECKLIST
-- ============================================================================

--[[ For Each Widget:

1. Replace resolve_config() pattern:
   OLD: local base = Style.BUTTON
   NEW: local config = Style.build_button_config()

2. Replace preset application:
   OLD: if opts.preset_name and Style[opts.preset_name] then...
   NEW: if opts.preset_name then Style.apply_dynamic_preset(config, opts.preset_name) end

3. Replace defaults merging:
   OLD: return Style.apply_defaults(base, opts)
   NEW: for key, value in pairs(opts) do config[key] = value end

4. Test:
   - Change Style.COLORS.BG_BASE
   - Verify widget updates immediately

]]

-- ============================================================================
-- COMPLETE EXAMPLE: Button Widget (Simplified)
-- ============================================================================

-- FULL IMPLEMENTATION:
local function resolve_config(opts)
  -- Step 1: Build base config from current theme
  local config = Style.build_button_config()

  -- Step 2: Apply preset if specified (resolves keys)
  if opts.preset_name then
    Style.apply_dynamic_preset(config, opts.preset_name)
  end

  -- Step 3: Handle toggle button ON state colors
  if opts.is_toggled then
    -- Populate ON state colors if preset didn't define them
    config.bg_on_color = config.bg_on_color or config.bg_active_color
    config.text_on_color = config.text_on_color or config.text_active_color
    -- ...
  end

  -- Step 4: User overrides (highest priority)
  for key, value in pairs(opts) do
    local is_metadata = (key == "preset_name" or key == "id" or key == "label")
    if not is_metadata and value ~= nil and config[key] ~= nil then
      config[key] = value
    end
  end

  -- Step 5: Derive disabled colors if not explicitly set
  if opts.disabled then
    config.bg_disabled_color = config.bg_disabled_color or
      Colors.adjust_lightness(config.bg_color, -0.05)
  end

  return config
end

-- Usage example:
function Button.draw(ctx, opts)
  local config = resolve_config(opts)
  -- config now has CURRENT theme colors!

  -- ... render button with config colors ...
end

-- ============================================================================
-- PERFORMANCE NOTES
-- ============================================================================

--[[

Q: Doesn't calling build_button_config() every frame hurt performance?

A: No! Negligible impact because:

1. Table creation is fast (~50ns in LuaJIT)
2. Reading M.COLORS is just table access (~5ns per read)
3. We're already doing apply_defaults() every frame in old system
4. Total overhead: <1µs per button per frame

Old system: apply_defaults(STATIC_TABLE, opts) = table copy
New system: build_button_config() + merge opts = table creation + merge

Nearly identical cost, but new system is truly dynamic!

]]

-- ============================================================================
-- BACKWARD COMPATIBILITY
-- ============================================================================

--[[

To maintain backward compatibility during transition:

-- In defaults.lua:
function M.build_button_config()
  -- New dynamic system
end

M.BUTTON = M.build_button_config()  -- Compat: populate old preset once

-- Widgets can check:
local base = Style.build_button_config and Style.build_button_config() or Style.BUTTON

This allows gradual migration without breaking existing code.

]]

return {
  resolve_config_OLD = resolve_config_OLD,
  resolve_config_NEW = resolve_config_NEW,
}
