-- @noindex
-- arkitekt/defs/colors/theme.lua
-- Theme-reactive color definitions (DSL)
--
-- Single source of truth for:
--   - Presets (dark/light base colors)
--   - Anchors (lightness values)
--   - All theme-reactive color definitions

local Colors = require('arkitekt.core.colors')

local M = {}

-- =============================================================================
-- PRESETS
-- =============================================================================
-- Base colors for dark/light themes. Anchors are auto-computed from these.

M.presets = {
  dark = 0x242424FF,  -- t=0 anchor
  grey = 0x333333FF,
  light_grey = 0x505050FF,
  light = 0xE0E0E0FF,  -- t=1 anchor
}

-- =============================================================================
-- VALIDATION
-- =============================================================================

--- Validate byte color format (0xRRGGBBAA)
--- @param color number Byte color value
--- @param name string Variable name for error messages
--- @return boolean valid, string|nil error_message
local function validate_byte_color(color, name)
  if type(color) ~= 'number' then
    return false, string.format('%s: expected number, got %s', name, type(color))
  end
  -- Byte colors are 32-bit RGBA values (> 255)
  if color <= 255 then
    return false, string.format('%s: value too small for byte color (%d)', name, color)
  end
  if color > 0xFFFFFFFF then
    return false, string.format('%s: value exceeds max byte color (0x%X)', name, color)
  end
  return true
end

--- Compute contrast ratio between two colors (WCAG formula)
--- @param color1 number RGBA color
--- @param color2 number RGBA color
--- @return number Contrast ratio (1.0 to 21.0)
local function contrast_ratio(color1, color2)
  local l1 = Colors.Luminance(color1)
  local l2 = Colors.Luminance(color2)
  local lighter = math.max(l1, l2)
  local darker = math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
end

--- Warn if contrast ratio is too low for text readability
--- @param fg number Foreground byte color (0xRRGGBBAA)
--- @param bg number Background byte color (0xRRGGBBAA)
--- @param name string Variable name for warning
--- @param min_ratio number Minimum contrast ratio (default 4.5 for WCAG AA)
local function warn_low_contrast(fg, bg, name, min_ratio)
  min_ratio = min_ratio or 4.5
  local ratio = contrast_ratio(fg, bg)
  if ratio < min_ratio then
    reaper.ShowConsoleMsg(string.format(
      '[Theme] Warning: %s has low contrast (%.1f:1, need %.1f:1)\n',
      name, ratio, min_ratio
    ))
  end
end

-- Validate presets on load
for name, color in pairs(M.presets) do
  local valid, err = validate_byte_color(color, 'presets.' .. name)
  if not valid then
    reaper.ShowConsoleMsg('[Theme] ' .. err .. '\n')
  end
end

-- =============================================================================
-- ANCHORS (auto-computed from presets)
-- =============================================================================

local function compute_lightness(color)
  local _, _, l = Colors.RgbToHsl(color)
  return l
end

M.anchors = {
  dark  = compute_lightness(M.presets.dark),
  light = compute_lightness(M.presets.light),
}

-- =============================================================================
-- VALUE RANGES (for clamping)
-- =============================================================================
-- Define valid ranges for value types inferred from key names

M.value_ranges = {
  OPACITY    = { min = 0, max = 1 },
  BRIGHTNESS = { min = 0, max = 2 },
  SATURATION = { min = 0, max = 2 },
  -- offset deltas (lightness adjustments)
  OFFSET     = { min = -1, max = 1 },

  -- Base background constraints (prevents extreme themes)
  BG_LIGHTNESS  = { min = 0.10, max = 0.92 },  -- Clamps pure black/white backgrounds
  BG_SATURATION = { min = 0.00, max = 0.12 },  -- Clamps overly colored backgrounds
}

--- Infer value range from key name (case-insensitive)
--- @param key string Palette key name
--- @return table|nil Range with min/max, or nil for no clamping
local function get_range_for_key(key)
  if not key then return nil end
  local lower = key:lower()
  if lower:match('opacity') then return M.value_ranges.OPACITY end
  if lower:match('brightness') then return M.value_ranges.BRIGHTNESS end
  if lower:match('saturation') then return M.value_ranges.SATURATION end
  return nil
end

--- Clamp a value to its valid range based on key name
--- @param key string Palette key name
--- @param value number Value to clamp
--- @return number Clamped value
local function clamp_value(key, value)
  if type(value) ~= 'number' then return value end
  local range = get_range_for_key(key)
  if not range then return value end
  return math.max(range.min, math.min(range.max, value))
end

-- Export for engine use
M.get_range_for_key = get_range_for_key
M.clamp_value = clamp_value

-- =============================================================================
-- DSL WRAPPERS
-- =============================================================================
-- Simple DSL - all snap/offset at midpoint (t=0.5):
--   snap(dark, light)        - discrete snap at midpoint
--   lerp(dark, light)        - smooth interpolation
--   offset(dark, [light])    - delta from BG_BASE (light defaults to dark)
--   bg()                     - use BG_BASE directly
--
-- 3-Zone DSL - transitions at t=0.33 and t=0.67 (fixed thirds):
--   snap3(dark, mid, light)  - discrete zones: dark < 0.33 < mid < 0.67 < light
--   lerp3(dark, mid, light)  - piecewise interpolation with mid-point
--   offset3(dark, mid, light) - delta from BG_BASE with 3 zones

local function snap(dark_val, light_val)
  return { mode = 'snap', dark = dark_val, light = light_val }
end

local function lerp(dark_val, light_val)
  return { mode = 'lerp', dark = dark_val, light = light_val }
end

local function offset(dark_delta, light_delta)
  return { mode = 'offset', dark = dark_delta, light = light_delta or dark_delta }
end

local function bg()
  return { mode = 'bg' }
end

-- 3-Zone variants (fixed thirds: 0.33, 0.67)
local function snap3(dark_val, mid_val, light_val)
  return { mode = 'snap3', dark = dark_val, mid = mid_val, light = light_val }
end

local function lerp3(dark_val, mid_val, light_val)
  return { mode = 'lerp3', dark = dark_val, mid = mid_val, light = light_val }
end

local function offset3(dark_delta, mid_delta, light_delta)
  return { mode = 'offset3', dark = dark_delta, mid = mid_delta, light = light_delta }
end

-- Export wrappers
M.snap = snap
M.lerp = lerp
M.offset = offset
M.bg = bg
M.snap3 = snap3
M.lerp3 = lerp3
M.offset3 = offset3

-- =============================================================================
-- COLORS (flat structure)
-- =============================================================================
-- The mode determines processing:
--   bg      → use input BG directly
--   offset  → BG-derived (apply delta to BG_BASE)
--   snap    → hex strings = color, numbers = value
--   lerp    → hex strings = color, numbers = value

M.colors = {
  -- === BACKGROUNDS (from BG_BASE) ===
  BG_BASE         = bg(),
  BG_HOVER        = offset(0.03, -0.06),   -- Light: more contrast (was -0.04)
  BG_ACTIVE       = offset(0.05, -0.10),   -- Light: more contrast (was -0.07)
  BG_HEADER       = offset(-0.024, -0.06),
  BG_PANEL        = offset(-0.04),
  BG_CHROME       = offset(-0.08, -0.15),

  -- === BORDERS (from BG_BASE) ===
  -- Increased offsets for more visible contrast (matching older visual style)
  BORDER_INNER    = offset(0.05, -0.03),
  BORDER_HOVER    = offset(0.18, -0.14),   -- was 0.10/-0.08, increased for visible pop
  BORDER_ACTIVE   = offset(0.30, -0.22),   -- was 0.15/-0.12, much brighter on click
  BORDER_FOCUS    = offset(0.25, -0.18),   -- was 0.20/-0.15
  BORDER_OUTER    = snap(0x000000FF, 0x404040FF),
  BORDER_OUTER_OPACITY = lerp(0.87, 0.60),

  -- === ACCENTS (from BG_BASE) ===
  ACCENT_PRIMARY       = offset(0.15, -0.12),
  ACCENT_TEAL          = offset(0.15, -0.12),
  ACCENT_TEAL_BRIGHT   = offset(0.25, -0.20),
  ACCENT_TRANSPARENT   = offset(0.15, -0.12),
  ACCENT_TRANSPARENT_OPACITY = lerp(0.67, 0.67),

  -- === ACCENTS (standalone) ===
  -- Changed from lerp to offset to guarantee visible contrast from BG_BASE
  -- (lerp created a 'dead zone' in mid-range themes like light_grey)
  ACCENT_WHITE        = offset(0.12, -0.15),
  ACCENT_WHITE_BRIGHT = offset(0.20, -0.22),
  ACCENT_SUCCESS = lerp(0x4CAF50FF, 0x2E7D32FF),
  ACCENT_WARNING = lerp(0xFFA726FF, 0xF57C00FF),
  ACCENT_DANGER  = lerp(0xEF5350FF, 0xC62828FF),

  -- === TEXT ===
  TEXT_NORMAL = snap(0xFFFFFFFF, 0x000000FF),
  TEXT_HOVER  = snap(0xF0F0F0FF, 0x1A1A1AFF),
  TEXT_ACTIVE = snap(0xE8E8E8FF, 0x222222FF),
  TEXT_DIMMED = snap(0xA0A0A0FF, 0x606060FF),
  TEXT_DARK   = snap(0x808080FF, 0x808080FF),
  TEXT_BRIGHT = snap(0xFFFFFFFF, 0x000000FF),

  -- === PATTERNS (from BG_BASE, includes panel offset) ===
  PATTERN_PRIMARY   = offset(-0.064, -0.10),
  PATTERN_SECONDARY = offset(-0.044, -0.06),

  -- === TILES ===
  -- BRIGHTNESS/SATURATION use normalized scale: 0=off, 0.5=neutral, 1=max (2x)
  TILE_NAME_COLOR      = snap(0xDDE3E9FF, 0x1A1A1AFF),
  TILE_FILL_BRIGHTNESS = lerp(0.25, 0.35), -- Normalized: 0.5=1x, so 0.25→0.5x, 0.35→0.7x
  TILE_FILL_SATURATION = lerp(0.20, 0.35), -- Normalized: 0.5=1x, so 0.20→0.4x, 0.35→0.7x
  TILE_FILL_OPACITY    = lerp(0.4, 0.6),   -- Light: slightly more opaque (was 0.5)

  -- === BADGES ===
  BADGE_BG             = snap(0x14181CFF, 0xE8ECF0FF),
  BADGE_TEXT           = snap(0xFFFFFFFF, 0x1A1A1AFF),
  BADGE_BG_OPACITY     = lerp(0.85, 0.90),
  BADGE_BORDER_OPACITY = lerp(0.20, 0.15),

  -- === PLAYLIST ===
  PLAYLIST_TILE_COLOR  = snap(0x3A3A3AFF, 0xA0A0A0FF),  -- Light: darker for contrast (was #D0D0D0)
  PLAYLIST_NAME_COLOR  = snap(0xCCCCCCFF, 0x2A2A2AFF),
  PLAYLIST_BADGE_COLOR = snap(0x999999FF, 0x666666FF),

  -- === OPERATIONS (drag/drop feedback) ===
  OP_MOVE   = snap(0xCCCCCCFF, 0x444444FF),  -- Gray - move operation
  OP_COPY   = snap(0x06B6D4FF, 0x0891B2FF),  -- Cyan - copy operation
  OP_DELETE = snap(0xE84A4AFF, 0xDC2626FF),  -- Red - delete operation
  OP_LINK   = snap(0x4A9EFFFF, 0x2563EBFF),  -- Blue - link/reference

  -- === COLORED BUTTONS ===
  -- Each variant: BG (base), HOVER (+lightness), ACTIVE (-lightness), TEXT (auto contrast)

  -- Danger (red)
  BUTTON_DANGER_BG     = lerp(0xB91C1CFF, 0xFCA5A5FF),
  BUTTON_DANGER_HOVER  = lerp(0xDC2626FF, 0xFEE2E2FF),
  BUTTON_DANGER_ACTIVE = lerp(0x991B1BFF, 0xF87171FF),
  BUTTON_DANGER_TEXT   = snap(0xFFFFFFFF, 0x7F1D1DFF),

  -- Success (green)
  BUTTON_SUCCESS_BG     = lerp(0x15803DFF, 0x86EFACFF),
  BUTTON_SUCCESS_HOVER  = lerp(0x16A34AFF, 0xBBF7D0FF),
  BUTTON_SUCCESS_ACTIVE = lerp(0x166534FF, 0x4ADE80FF),
  BUTTON_SUCCESS_TEXT   = snap(0xFFFFFFFF, 0x14532DFF),

  -- Warning (amber/orange)
  BUTTON_WARNING_BG     = lerp(0xB45309FF, 0xFCD34DFF),
  BUTTON_WARNING_HOVER  = lerp(0xD97706FF, 0xFDE68AFF),
  BUTTON_WARNING_ACTIVE = lerp(0x92400EFF, 0xFBBF24FF),
  BUTTON_WARNING_TEXT   = snap(0xFFFFFFFF, 0x78350FFF),

  -- Info (blue)
  BUTTON_INFO_BG     = lerp(0x1D4ED8FF, 0x93C5FDFF),
  BUTTON_INFO_HOVER  = lerp(0x2563EBFF, 0xBFDBFEFF),
  BUTTON_INFO_ACTIVE = lerp(0x1E40AFFF, 0x60A5FAFF),
  BUTTON_INFO_TEXT   = snap(0xFFFFFFFF, 0x1E3A8AFF),
}

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Get all color keys
function M.get_all_keys()
  local keys = {}
  for key in pairs(M.colors) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- Export validation utilities
M.validate_byte_color = validate_byte_color
M.contrast_ratio = contrast_ratio
M.warn_low_contrast = warn_low_contrast

return M
