-- @noindex
-- arkitekt/defs/palette.lua
-- Theme palette definition
--
-- Single source of truth for:
--   - Presets (dark/light base colors)
--   - Anchors (lightness values)
--   - All color definitions with inline values

local M = {}

-- =============================================================================
-- PRESETS
-- =============================================================================
-- Base colors for dark/light themes. Anchors are computed from these.

M.presets = {
  dark       = "#242424",  -- ~14% lightness (t=0)
  grey       = "#333333",  -- ~31% lightness
  light_grey = "#505050",  -- ~56% lightness
  light      = "#E0E0E0",  -- ~88% lightness (t=1)
}

-- Anchors: lightness values for dark/light presets
-- These match the preset hex values above
M.anchors = {
  dark  = 0.14,  -- #242424
  light = 0.88,  -- #E0E0E0
}

-- =============================================================================
-- DSL WRAPPERS
-- =============================================================================
-- offsetFromBase(dark, light) - snap between deltas at t=0.5
-- lerpDarkLight(dark, light)  - smooth interpolation
-- snapAtMidpoint(dark, light) - snap between values at t=0.5
-- snapAt(t, dark, light)      - snap at custom threshold

local function offsetFromBase(dark_delta, light_delta)
  if light_delta == nil then
    return { mode = "offset", dark = dark_delta, light = dark_delta, threshold = 0.5 }
  end
  return { mode = "offset", dark = dark_delta, light = light_delta, threshold = 0.5 }
end

local function lerpDarkLight(dark_val, light_val)
  return { mode = "lerp", dark = dark_val, light = light_val }
end

local function snapAtMidpoint(dark_val, light_val)
  return { mode = "snap", dark = dark_val, light = light_val, threshold = 0.5 }
end

local function snapAt(threshold, dark_val, light_val)
  return { mode = "snap", dark = dark_val, light = light_val, threshold = threshold }
end

-- Shortcuts
local offset = offsetFromBase
local lerp = lerpDarkLight
local snap = snapAtMidpoint

-- Export wrappers for external use
M.offsetFromBase = offsetFromBase
M.lerpDarkLight = lerpDarkLight
M.snapAtMidpoint = snapAtMidpoint
M.snapAt = snapAt

-- =============================================================================
-- FROM BG (derived from base background color)
-- =============================================================================

M.from_bg = {
  -- Backgrounds
  BG_BASE         = "base",
  BG_HOVER        = offset(0.03, -0.04),
  BG_ACTIVE       = offset(0.05, -0.07),
  BG_HEADER       = offset(-0.024, -0.06),
  BG_PANEL        = offset(-0.04),
  BG_CHROME       = offset(-0.08, -0.15),
  BG_TRANSPARENT  = { mode = "opacity", value = 0 },

  -- Borders (from bg)
  BORDER_INNER    = offset(0.05, -0.03),
  BORDER_HOVER    = offset(0.10, -0.08),
  BORDER_ACTIVE   = offset(0.15, -0.12),
  BORDER_FOCUS    = offset(0.20, -0.15),

  -- Accents (from bg)
  ACCENT_PRIMARY       = offset(0.15, -0.12),
  ACCENT_TEAL          = offset(0.15, -0.12),
  ACCENT_TEAL_BRIGHT   = offset(0.25, -0.20),
  ACCENT_WHITE         = { mode = "set_light", lightness = lerp(0.25, 0.55) },
  ACCENT_WHITE_BRIGHT  = { mode = "set_light", lightness = lerp(0.35, 0.45) },
  ACCENT_TRANSPARENT   = { mode = "lightness_opacity", delta = offset(0.15, -0.12), opacity = 0.67 },

  -- Patterns (from bg, includes panel offset)
  PATTERN_PRIMARY   = offset(-0.064, -0.10),
  PATTERN_SECONDARY = offset(-0.044, -0.06),
}

-- =============================================================================
-- SPECIFIC (standalone colors using snap/lerp)
-- =============================================================================

M.specific = {
  -- Text colors (explicit snap - no auto-derivation magic)
  TEXT_NORMAL = snap("#FFFFFF", "#000000"),
  TEXT_HOVER  = snap("#F0F0F0", "#1A1A1A"),
  TEXT_ACTIVE = snap("#E8E8E8", "#222222"),
  TEXT_DIMMED = snap("#A0A0A0", "#606060"),
  TEXT_DARK   = snap("#808080", "#808080"),
  TEXT_BRIGHT = snap("#FFFFFF", "#000000"),

  -- Border outer (hex + opacity)
  BORDER_OUTER = { mode = "alpha", color = snap("#000000", "#404040"), opacity = lerp(0.87, 0.60) },

  -- Status colors
  ACCENT_SUCCESS = lerp("#4CAF50", "#2E7D32"),
  ACCENT_WARNING = lerp("#FFA726", "#F57C00"),
  ACCENT_DANGER  = lerp("#EF5350", "#C62828"),

  -- Tiles
  TILE_NAME_COLOR = snap("#DDE3E9", "#1A1A1A"),

  -- Badges
  BADGE_BG   = { mode = "alpha", color = snap("#14181C", "#E8ECF0"), opacity = lerp(0.85, 0.90) },
  BADGE_TEXT = snap("#FFFFFF", "#1A1A1A"),

  -- Playlist
  PLAYLIST_TILE_COLOR  = snap("#3A3A3A", "#D0D0D0"),
  PLAYLIST_NAME_COLOR  = snap("#CCCCCC", "#2A2A2A"),
  PLAYLIST_BADGE_COLOR = snap("#999999", "#666666"),
}

-- =============================================================================
-- VALUES (non-color values)
-- =============================================================================

M.values = {
  -- Tile rendering
  TILE_FILL_BRIGHTNESS = lerp(0.5, 1.4),
  TILE_FILL_SATURATION = lerp(0.4, 0.5),
  TILE_FILL_OPACITY    = lerp(0.4, 0.5),

  -- Badge border
  BADGE_BORDER_OPACITY = lerp(0.20, 0.15),

  -- System
  REAPER_SYNC_OFFSET = offset(-0.012),
}

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Get all color keys across all sections
function M.get_all_keys()
  local keys = {}
  for key in pairs(M.from_bg) do keys[#keys + 1] = key end
  for key in pairs(M.specific) do keys[#keys + 1] = key end
  for key in pairs(M.values) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end

return M
