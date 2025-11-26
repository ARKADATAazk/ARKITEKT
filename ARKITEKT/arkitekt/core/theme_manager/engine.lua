-- @noindex
-- arkitekt/core/theme_manager/engine.lua
-- Palette generation engine
--
-- Computes colors from the palette definition based on theme lightness.
-- Processes flat palette structure with type inference.

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')
local Palette = require('arkitekt.defs.palette')

local M = {}

-- =============================================================================
-- T COMPUTATION
-- =============================================================================

--- Compute interpolation factor 't' from lightness
--- Uses anchors derived from presets (single source of truth)
--- @param lightness number Background lightness (0.0-1.0)
--- @return number t value (0.0 at dark preset, 1.0 at light preset)
function M.compute_t(lightness)
  local range = Palette.anchors.light - Palette.anchors.dark
  if range <= 0 then return 0 end
  local t = (lightness - Palette.anchors.dark) / range
  return math.max(0, math.min(1, t))
end

-- =============================================================================
-- VALUE RESOLUTION
-- =============================================================================

--- Resolve a wrapped value based on current t
--- @param def table Wrapper from palette definition
--- @param t number Interpolation factor (0.0-1.0)
--- @return any Resolved value
local function resolve_value(def, t)
  if type(def) ~= "table" then
    return def  -- Raw value
  end

  if not def.mode then
    return def  -- Not a wrapper
  end

  local mode = def.mode
  local threshold = def.threshold or 0.5

  if mode == "offset" or mode == "snap" then
    return t < threshold and def.dark or def.light

  elseif mode == "lerp" then
    local dark_val, light_val = def.dark, def.light
    if type(dark_val) == "number" and type(light_val) == "number" then
      return dark_val + (light_val - dark_val) * t
    elseif type(dark_val) == "string" and type(light_val) == "string" then
      -- RGB color lerp
      local color_a = Colors.hexrgb(dark_val .. (#dark_val == 7 and "FF" or ""))
      local color_b = Colors.hexrgb(light_val .. (#light_val == 7 and "FF" or ""))
      local lerped = Colors.lerp(color_a, color_b, t)
      local r, g, b = Colors.rgba_to_components(lerped)
      return string.format("#%02X%02X%02X", r, g, b)
    else
      return t < 0.5 and dark_val or light_val
    end
  end

  return def.dark  -- Fallback
end

-- =============================================================================
-- COLOR DERIVATION (unified)
-- =============================================================================

--- Derive a single palette entry based on its definition
--- @param base_bg number Background color in RGBA format
--- @param key string Palette key name
--- @param def any Definition (string, table with mode, or raw value)
--- @param t number Interpolation factor
--- @return any Computed value (RGBA color or number)
local function derive_entry(base_bg, key, def, t)
  -- Raw value (not a table)
  if type(def) ~= "table" or not def.mode then
    return def
  end

  local mode = def.mode

  -- BG: Use BG_BASE directly (passthrough)
  if mode == "bg" then
    return base_bg
  end

  -- OFFSET: Apply delta to BG_BASE
  if mode == "offset" then
    local delta = resolve_value(def, t)
    return Colors.adjust_lightness(base_bg, delta)
  end

  -- SNAP or LERP: Check value type
  local resolved = resolve_value(def, t)

  if type(resolved) == "string" then
    -- Hex string → convert to RGBA
    return Colors.hexrgb(resolved .. "FF")
  else
    -- Number → return as-is
    return resolved
  end
end

-- =============================================================================
-- PALETTE GENERATION
-- =============================================================================

--- Generate complete palette from base background color
--- Uses flat M.palette structure with type inference
--- @param base_bg number Background color in RGBA format
--- @return table Color palette
function M.generate_palette(base_bg)
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)
  local t = M.compute_t(bg_lightness)

  local result = {}

  for key, def in pairs(Palette.colors) do
    result[key] = derive_entry(base_bg, key, def, t)
  end

  return result
end

--- Apply a color palette to Style.COLORS
--- @param palette table Color palette from generate_palette()
function M.apply_palette(palette)
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end
end

--- Generate palette from base color and apply to Style.COLORS
--- @param base_bg number Background color
function M.generate_and_apply(base_bg)
  local palette = M.generate_palette(base_bg)
  M.apply_palette(palette)
end

--- Get current color values (for transitions)
--- @return table Copy of current Style.COLORS
function M.get_current_colors()
  local current = {}
  for key, value in pairs(Style.COLORS) do
    current[key] = value
  end
  return current
end

--- Resolve a wrapped value based on current t (exported for registry)
--- @param def table Wrapper from palette definition
--- @param t number Interpolation factor (0.0-1.0)
--- @return any Resolved value
function M.resolve_value(def, t)
  return resolve_value(def, t)
end

--- Derive an entry with BG_BASE (exported for registry offset support)
--- @param base_bg number Background color in RGBA format
--- @param def any Definition
--- @param t number Interpolation factor
--- @return any Computed value
function M.derive_entry(base_bg, def, t)
  return derive_entry(base_bg, nil, def, t)
end

return M
