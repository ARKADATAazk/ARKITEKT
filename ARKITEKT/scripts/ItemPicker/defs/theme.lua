-- @noindex
-- ItemPicker/defs/theme.lua
-- Theme-reactive palette for ItemPicker
--
-- Registers with the Theme Manager to provide consistent colors
-- across dark/light themes for the ItemPicker overlay.

local Theme = require('arkitekt.core.theme')
local snap = Theme.snap
local lerp = Theme.lerp
local offset = Theme.offset

local M = {}

-- =============================================================================
-- PALETTE DEFINITION
-- =============================================================================
-- Uses Theme Manager DSL:
--   snap(dark, light)   - discrete switch at t=0.5
--   lerp(dark, light)   - smooth interpolation
--   offset(dark, light) - delta from BG_BASE

M.palette = {
  -- Panel colors
  PANEL_BACKGROUND = offset(-0.08, -0.12),   -- Darker than chrome
  PANEL_BORDER     = offset(-0.04, -0.08),
  PATTERN          = offset(-0.02, -0.04),

  -- Text colors
  TEXT_PRIMARY = snap("#FFFFFF", "#1A1A1A"),
  TEXT_MUTED   = snap("#CC2222", "#B91C1C"),  -- Red for muted items
  TEXT_HINT    = snap("#888888", "#666666"),

  -- Status colors
  LOADING = snap("#4A9EFF", "#2563EB"),       -- Blue loading indicator

  -- Badge colors
  BADGE_BG = snap("#14181C", "#E8ECF0"),
  BADGE_BORDER_DARKEN = lerp(0.4, 0.3),
  BADGE_BORDER_ALPHA = lerp(0.4, 0.3),        -- 0x66/255 ≈ 0.4

  -- Disabled state
  DISABLED_BACKDROP = offset(-0.04, -0.06),
  DISABLED_BACKDROP_ALPHA = lerp(0.53, 0.45), -- 0x88/255 ≈ 0.53

  -- Drag handler
  DRAG_COLOR = snap("#42E896", "#2DD881"),    -- Teal/green for drag feedback

  -- Hover overlay
  HOVER_OVERLAY = snap("#FFFFFF20", "#00000020"),

  -- Text shadow
  TEXT_SHADOW = snap("#00000050", "#FFFFFF30"),

  -- Default track color (when track has no color)
  DEFAULT_TRACK_COLOR_R = lerp(85/256, 100/256),
  DEFAULT_TRACK_COLOR_G = lerp(91/256, 105/256),
  DEFAULT_TRACK_COLOR_B = lerp(91/256, 105/256),

  -- Fallback track color (for missing data)
  FALLBACK_TRACK = snap("#4A5A6A", "#8090A0"),

  -- Tile rendering adjustments
  TILE_MIN_LIGHTNESS = lerp(0.20, 0.30),

  -- Duration text
  DURATION_DARK_THRESHOLD = lerp(0.80, 0.50),
  DURATION_LIGHT_SATURATION = lerp(0.2, 0.3),
  DURATION_LIGHT_VALUE = lerp(4.2, 3.5),
  DURATION_DARK_SATURATION = lerp(0.4, 0.5),
  DURATION_DARK_VALUE = lerp(0.18, 0.25),

  -- Selection (marching ants)
  SELECTION_BORDER_SATURATION = lerp(1.0, 0.9),
  SELECTION_BORDER_BRIGHTNESS = lerp(3.5, 2.5),
  SELECTION_TILE_BRIGHTNESS_BOOST = lerp(0.35, 0.25),

  -- Disabled state adjustments
  DISABLED_DESATURATE = lerp(0.10, 0.15),
  DISABLED_BRIGHTNESS = lerp(0.60, 0.70),
  DISABLED_MIN_ALPHA = lerp(0.27, 0.35),     -- 0x44/255 ≈ 0.27

  -- Muted state adjustments
  MUTED_DESATURATE = lerp(0.25, 0.30),
  MUTED_BRIGHTNESS = lerp(0.70, 0.75),
  MUTED_ALPHA_FACTOR = lerp(0.85, 0.80),

  -- Header
  HEADER_ALPHA = lerp(0.87, 0.80),           -- 0xDD/255 ≈ 0.87
  HEADER_TEXT_SHADOW = snap("#00000099", "#FFFFFF40"),

  -- Base tile fill
  BASE_SATURATION_FACTOR = lerp(0.9, 0.85),
  BASE_BRIGHTNESS_FACTOR = lerp(0.6, 0.7),
  COMPACT_SATURATION_FACTOR = lerp(0.7, 0.65),
  COMPACT_BRIGHTNESS_FACTOR = lerp(0.4, 0.5),

  -- Hover effect
  HOVER_BRIGHTNESS_BOOST = lerp(0.50, 0.40),

  -- Waveform visualization
  WAVEFORM_SATURATION = lerp(0.3, 0.35),
  WAVEFORM_BRIGHTNESS = lerp(0.1, 0.15),
  WAVEFORM_LINE_ALPHA = lerp(0.95, 0.90),
  WAVEFORM_ZERO_LINE_ALPHA = lerp(0.3, 0.35),

  -- Tile FX
  TILE_FX_FILL_OPACITY = lerp(0.65, 0.70),
  TILE_FX_FILL_SATURATION = lerp(0.75, 0.70),
  TILE_FX_FILL_BRIGHTNESS = lerp(0.6, 0.7),
  TILE_FX_GRADIENT_INTENSITY = lerp(0.2, 0.15),
  TILE_FX_GRADIENT_OPACITY = lerp(0.08, 0.06),
  TILE_FX_SPECULAR_STRENGTH = lerp(0.12, 0.08),
  TILE_FX_INNER_SHADOW_STRENGTH = lerp(0.25, 0.20),
  TILE_FX_GLOW_STRENGTH = lerp(0.4, 0.30),
  TILE_FX_HOVER_FILL_BOOST = lerp(0.16, 0.12),
  TILE_FX_HOVER_SPECULAR_BOOST = lerp(1.2, 1.0),

  -- Region tags
  REGION_CHIP_BG = snap("#14181C", "#E8ECF0"),
  REGION_TEXT_MIN_LIGHTNESS = lerp(0.35, 0.40),

  -- Small tile display
  SMALL_TILE_VISUALIZATION_ALPHA = lerp(0.1, 0.15),
  SMALL_TILE_HEADER_SATURATION = lerp(0.6, 0.55),
  SMALL_TILE_HEADER_BRIGHTNESS = lerp(0.7, 0.75),
}

-- =============================================================================
-- REGISTRATION
-- =============================================================================

local SCRIPT_NAME = "ItemPicker"

--- Initialize and register palette with Theme Manager
function M.init()
  Theme.register_script_palette(SCRIPT_NAME, M.palette)
end

--- Get computed palette for current theme
--- @return table Palette with resolved color values
function M.get()
  local computed = Theme.get_script_palette(SCRIPT_NAME)
  if not computed then
    -- Fallback: register and try again
    M.init()
    computed = Theme.get_script_palette(SCRIPT_NAME)
  end
  return computed or {}
end

--- Unregister palette (cleanup)
function M.cleanup()
  Theme.unregister_script_palette(SCRIPT_NAME)
end

return M
