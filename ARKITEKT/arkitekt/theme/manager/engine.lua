-- @noindex
-- arkitekt/core/theme_manager/engine.lua
-- Palette generation engine
--
-- Computes colors from the palette definition based on theme lightness.
-- Processes flat palette structure with type inference.

local Colors = require('arkitekt.core.colors')
local Palette = require('arkitekt.config.colors')

local M = {}

-- Helper: Check if a number is a byte color (vs a small numeric value like opacity)
-- Byte colors are large numbers like 0xRRGGBBAA (> 255)
local function is_byte_color(val)
  return type(val) == 'number' and val > 255
end

-- =============================================================================
-- NORMALIZED VALUE TRANSFORMS
-- =============================================================================
-- Converts intuitive 0-1 scale to actual operational values:
--   0.0 = minimum (off/black/grayscale)
--   0.5 = neutral (no change from original)
--   1.0 = maximum (full bright/saturated)
--
-- This makes palette tuning intuitive and consistent across all scripts.

--- Patterns for keys that should use normalized transforms (case-insensitive)
local NORMALIZE_PATTERNS = {
  '_[Bb][Rr][Ii][Gg][Hh][Tt][Nn][Ee][Ss][Ss]$',   -- _brightness (any case)
  '_[Ss][Aa][Tt][Uu][Rr][Aa][Tt][Ii][Oo][Nn]$',   -- _saturation (any case)
  '[Bb][Rr][Ii][Gg][Hh][Tt][Nn][Ee][Ss][Ss]$',    -- BRIGHTNESS (any case, no underscore)
  '[Ss][Aa][Tt][Uu][Rr][Aa][Tt][Ii][Oo][Nn]$',    -- SATURATION (any case, no underscore)
}

--- Check if a key should use normalized transform
--- @param key string Palette key name
--- @return boolean
local function should_normalize(key)
  if not key then return false end
  for _, pattern in ipairs(NORMALIZE_PATTERNS) do
    if key:match(pattern) then
      return true
    end
  end
  return false
end

--- Transform normalized value (0-1 intuitive scale) to operational multiplier
--- Input:  0.0 = off, 0.5 = neutral (1.0x), 1.0 = maximum
--- Output: multiplier for HSV operations
---
--- The transform uses exponential scaling centered at 0.5:
---   0.0 → 0.0 (completely off)
---   0.5 → 1.0 (no change / neutral)
---   1.0 → 2.0 (double / maximum boost)
---
--- @param normalized number Value in 0-1 intuitive scale
--- @return number Operational multiplier
function M.normalize_to_multiplier(normalized)
  -- Clamp input to valid range
  normalized = math.max(0, math.min(1, normalized))

  -- Linear transform: 0→0, 0.5→1, 1→2
  -- This gives intuitive control where 0.5 is 'default/unchanged'
  return normalized * 2
end

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
  if type(def) ~= 'table' then
    return def  -- Raw value
  end

  if not def.mode then
    return def  -- Not a wrapper
  end

  local mode = def.mode

  -- snap2/offset2: discrete switch at midpoint (t=0.5)
  if mode == 'offset2' or mode == 'snap2' then
    return t < 0.5 and def.dark or def.light

  -- snap3/offset3: discrete 3-zone switch (t=0.33, 0.67)
  elseif mode == 'offset3' or mode == 'snap3' then
    if t < 0.33 then
      return def.dark
    elseif t < 0.67 then
      return def.mid
    else
      return def.light
    end

  -- lerp2: smooth interpolation
  elseif mode == 'lerp2' then
    local dark_val, light_val = def.dark, def.light

    -- Byte colors: use Colors.Lerp for proper RGBA interpolation
    if is_byte_color(dark_val) and is_byte_color(light_val) then
      return Colors.Lerp(dark_val, light_val, t)

    -- Small numbers: linear interpolation (opacity, brightness, etc.)
    elseif type(dark_val) == 'number' and type(light_val) == 'number' then
      return dark_val + (light_val - dark_val) * t

    else
      return t < 0.5 and dark_val or light_val
    end

  -- lerp3: piecewise interpolation (0.0-0.33 dark→mid, 0.33-0.67 mid→light, 0.67-1.0 light)
  elseif mode == 'lerp3' then
    local dark_val, mid_val, light_val = def.dark, def.mid, def.light
    local val_a, val_b, local_t

    -- Determine segment and compute local t
    if t < 0.33 then
      val_a, val_b = dark_val, mid_val
      local_t = t / 0.33
    elseif t < 0.67 then
      val_a, val_b = mid_val, light_val
      local_t = (t - 0.33) / 0.34
    else
      return light_val  -- Past 0.67, stay at light value
    end

    -- Interpolate based on type
    -- Byte colors: use Colors.Lerp for proper RGBA interpolation
    if is_byte_color(val_a) and is_byte_color(val_b) then
      return Colors.Lerp(val_a, val_b, local_t)

    -- Small numbers: linear interpolation (opacity, brightness, etc.)
    elseif type(val_a) == 'number' and type(val_b) == 'number' then
      return val_a + (val_b - val_a) * local_t

    else
      return local_t < 0.5 and val_a or val_b
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
  if type(def) ~= 'table' or not def.mode then
    return def
  end

  local mode = def.mode

  -- BG: Use BG_BASE directly (passthrough)
  if mode == 'bg' then
    return base_bg
  end

  -- OFFSET2/OFFSET3: Apply delta to BG_BASE
  if mode == 'offset2' or mode == 'offset3' then
    local delta = resolve_value(def, t)
    -- Clamp delta to valid range
    delta = math.max(-1, math.min(1, delta))
    return Colors.AdjustLightness(base_bg, delta)
  end

  -- SNAP/SNAP3/LERP/LERP3: Check value type
  local resolved = resolve_value(def, t)

  if is_byte_color(resolved) then
    -- Byte color → return directly
    return resolved

  elseif type(resolved) == 'number' then
    -- Small number → apply normalization if key matches pattern
    if should_normalize(key) then
      resolved = M.normalize_to_multiplier(resolved)
    end
    -- Clamp to valid range for key type
    return Palette.clamp_value(key, resolved)

  else
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
  local _, _, bg_lightness = Colors.RgbToHsl(base_bg)
  local t = M.compute_t(bg_lightness)

  local result = {}

  for key, def in pairs(Palette.colors) do
    result[key] = derive_entry(base_bg, key, def, t)
  end

  return result
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
--- @param key string|nil Optional key for value clamping
--- @return any Computed value
function M.derive_entry(base_bg, def, t, key)
  return derive_entry(base_bg, key, def, t)
end

return M
