-- @noindex
-- arkitekt/core/theme_manager/registry.lua
-- Script palette registration
--
-- Allows scripts to register their own theme-reactive palettes
-- using the same DSL as the main palette (snap/lerp/offset).
-- Flat structure with type inference.

local Colors = require('arkitekt.core.colors')
local Palette = require('arkitekt.defs.colors')
local Engine = require('arkitekt.core.theme_manager.engine')

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    _Theme = require('arkitekt.core.theme')
  end
  return _Theme
end

-- =============================================================================
-- SCRIPT PALETTE REGISTRATION
-- =============================================================================
-- Scripts register flat palettes using the same DSL wrappers:
--   snap(dark, light)  → color (hex) or value (number)
--   lerp(dark, light)  → color (hex) or value (number)
--   offset(dark, light) → BG-derived color

--- Registered script palette definitions
--- @type table<string, table>
M.script_palettes = {}

--- Cache for computed script palettes { palette = {}, t = number }
local palette_cache = {}

--- Round t to 3 decimal places to avoid float comparison issues
local function round_t(t)
  return (t * 1000 + 0.5) // 1 / 1000
end

--- Clear the script palette cache (called when theme changes)
function M.clear_cache()
  palette_cache = {}
end

--- Register a script's theme-reactive palette (flat structure)
--- @param script_name string Name of the script
--- @param palette table Flat palette with DSL wrappers
function M.register_palette(script_name, palette)
  if type(script_name) ~= "string" or type(palette) ~= "table" then
    return
  end
  M.script_palettes[script_name] = palette
  palette_cache[script_name] = nil  -- Invalidate cache
end

--- Unregister a script's palette
--- @param script_name string Name of the script to unregister
function M.unregister_palette(script_name)
  M.script_palettes[script_name] = nil
  palette_cache[script_name] = nil
end

--- Get computed palette for a script (computed for current theme)
--- @param script_name string Name of the script
--- @param current_t number Current interpolation factor
--- @return table|nil Computed palette, or nil if not registered
function M.get_computed_palette(script_name, current_t)
  local palette_def = M.script_palettes[script_name]
  if not palette_def then
    return nil
  end

  -- Round t to avoid float comparison issues
  local t_key = round_t(current_t)

  -- Check cache (t stored separately, not in palette)
  local cached = palette_cache[script_name]
  if cached and cached.t == t_key then
    return cached.palette
  end

  -- Get current BG_BASE for offset support
  local Theme = get_theme()
  local bg_base = Theme.COLORS and Theme.COLORS.BG_BASE

  -- Compute palette for current theme
  local computed = {}

  for key, def in pairs(palette_def) do
    -- Use unified derive_entry if BG_BASE available, otherwise fallback
    if type(def) == "table" and def.mode == "offset" then
      -- Offset mode requires BG_BASE
      if bg_base then
        computed[key] = Engine.derive_entry(bg_base, def, current_t, key)
      else
        -- Fallback: can't compute offset without BG_BASE
        computed[key] = nil
      end
    elseif type(def) == "table" and def.mode then
      -- snap or lerp
      local resolved = Engine.resolve_value(def, current_t)
      if type(resolved) == "string" then
        -- Hex string → convert to RGBA
        computed[key] = Colors.hexrgb(resolved .. "FF")
      else
        -- Number → clamp to valid range for key type
        computed[key] = Palette.clamp_value(key, resolved)
      end
    else
      -- Raw value
      computed[key] = def
    end
  end

  -- Cache with t stored separately
  palette_cache[script_name] = { palette = computed, t = t_key }
  return computed
end

--- Get all registered script palettes (definitions, not computed)
--- @return table<string, table>
function M.get_all_palettes()
  return M.script_palettes
end

return M
