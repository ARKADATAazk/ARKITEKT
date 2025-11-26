-- @noindex
-- arkitekt/core/theme_manager/registry.lua
-- Script palette registration
--
-- Allows scripts to register their own theme-reactive palettes
-- using the same DSL as the main palette (snap/lerp/offset).

local Colors = require('arkitekt.core.colors')
local Engine = require('arkitekt.core.theme_manager.engine')

local M = {}

-- =============================================================================
-- SCRIPT PALETTE REGISTRATION
-- =============================================================================
-- Scripts register palettes with the same structure as the main palette:
--   specific = { COLOR = snap/lerp }
--   values   = { VALUE = snap/lerp }

--- Registered script palette definitions
--- @type table<string, { specific: table, values: table }>
M.script_palettes = {}

--- Cache for computed script palettes
local palette_cache = {}

--- Round t to 3 decimal places to avoid float comparison issues
local function round_t(t)
  return math.floor(t * 1000 + 0.5) / 1000
end

--- Clear the script palette cache (called when theme changes)
function M.clear_cache()
  palette_cache = {}
end

--- Register a script's theme-reactive palette
--- @param script_name string Name of the script
--- @param palette table Palette with { specific = {}, values = {} }
function M.register_palette(script_name, palette)
  if type(script_name) ~= "string" or type(palette) ~= "table" then
    return
  end
  M.script_palettes[script_name] = {
    specific = palette.specific or {},
    values = palette.values or {},
  }
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

  -- Check cache
  local cached = palette_cache[script_name]
  if cached and cached._t == t_key then
    return cached
  end

  -- Compute palette for current theme
  local computed = { _t = t_key }

  -- Specific colors (resolve to hex, convert to RGBA)
  for key, def in pairs(palette_def.specific) do
    local hex = Engine.resolve_value(def, current_t)
    computed[key] = Colors.hexrgb(hex .. "FF")
  end

  -- Values (resolve to number/string)
  for key, def in pairs(palette_def.values) do
    computed[key] = Engine.resolve_value(def, current_t)
  end

  palette_cache[script_name] = computed
  return computed
end

--- Get all registered script palettes (definitions, not computed)
--- @return table<string, table>
function M.get_all_palettes()
  return M.script_palettes
end

return M
