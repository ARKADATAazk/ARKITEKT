-- @noindex
-- arkitekt/defs/palette.lua
-- Palette structure definition
--
-- Defines WHAT colors exist in the UI palette and HOW each is derived.
-- All derivation uses rules - no hardcoded logic here.
--
-- Derivation types:
--   "base"       - The input color itself
--   "text"       - Auto text color (white on dark, black on light)
--   "lightness"  - adjust_lightness(source, rule)
--   "set_light"  - set_lightness(source, rule)
--   "opacity"    - with_opacity(source, rule)
--   "alpha"      - with_alpha(hex_rule, opacity_rule)
--   "hex"        - hexrgb(rule)
--   "value"      - raw rule value (for non-color data)

local M = {}

-- =============================================================================
-- PALETTE DEFINITION
-- =============================================================================
-- Each entry: { source, derivation_type, rule_key(s) }
-- source: "bg" | "text" | "accent" | "chrome" | "panel" | color_key
-- This is the single source of truth for palette structure.

M.definition = {
  -- ============ BACKGROUNDS ============
  BG_BASE         = { "bg", "base" },
  BG_HOVER        = { "bg", "lightness", "bg_hover_delta" },
  BG_ACTIVE       = { "bg", "lightness", "bg_active_delta" },
  BG_HEADER       = { "bg", "lightness", "bg_header_delta" },
  BG_PANEL        = { "bg", "lightness", "bg_panel_delta" },
  BG_CHROME       = { "bg", "lightness", "bg_chrome_delta" },
  BG_TRANSPARENT  = { "bg", "opacity", 0 },

  -- ============ BORDERS ============
  BORDER_OUTER    = { nil, "alpha", "border_outer_color", "border_outer_opacity" },
  BORDER_INNER    = { "bg", "lightness", "border_inner_delta" },
  BORDER_HOVER    = { "bg", "lightness", "border_hover_delta" },
  BORDER_ACTIVE   = { "bg", "lightness", "border_active_delta" },
  BORDER_FOCUS    = { "bg", "lightness", "border_focus_delta" },

  -- ============ TEXT ============
  TEXT_NORMAL     = { "text", "base" },
  TEXT_HOVER      = { "text", "lightness", "text_hover_delta" },
  TEXT_ACTIVE     = { "text", "lightness", "text_hover_delta" },
  TEXT_DIMMED     = { "text", "lightness", "text_dimmed_delta" },
  TEXT_DARK       = { "text", "lightness", "text_dark_delta" },
  TEXT_BRIGHT     = { "text", "lightness", "text_bright_delta" },

  -- ============ ACCENTS ============
  ACCENT_PRIMARY       = { "accent", "base" },
  ACCENT_TEAL          = { "accent", "base" },
  ACCENT_TEAL_BRIGHT   = { "accent", "lightness", "accent_bright_delta" },
  ACCENT_WHITE         = { "bg", "set_light", "accent_white_lightness" },
  ACCENT_WHITE_BRIGHT  = { "bg", "set_light", "accent_white_bright_lightness" },
  ACCENT_TRANSPARENT   = { "accent", "opacity", 0.67 },
  ACCENT_SUCCESS       = { nil, "hex", "status_success" },
  ACCENT_WARNING       = { nil, "hex", "status_warning" },
  ACCENT_DANGER        = { nil, "hex", "status_danger" },

  -- ============ PATTERNS ============
  PATTERN_PRIMARY   = { "panel", "lightness", "pattern_primary_delta" },
  PATTERN_SECONDARY = { "panel", "lightness", "pattern_secondary_delta" },

  -- ============ TILES ============
  TILE_FILL_BRIGHTNESS = { nil, "value", "tile_fill_brightness" },
  TILE_FILL_SATURATION = { nil, "value", "tile_fill_saturation" },
  TILE_FILL_OPACITY    = { nil, "value", "tile_fill_opacity" },
  TILE_NAME_COLOR      = { nil, "hex", "tile_name_color" },

  -- ============ BADGES ============
  BADGE_BG             = { nil, "alpha", "badge_bg_color", "badge_bg_opacity" },
  BADGE_TEXT           = { nil, "hex", "badge_text_color" },
  BADGE_BORDER_OPACITY = { nil, "value", "badge_border_opacity" },

  -- ============ PLAYLIST TILES ============
  PLAYLIST_TILE_COLOR  = { nil, "hex", "playlist_tile_color" },
  PLAYLIST_NAME_COLOR  = { nil, "hex", "playlist_name_color" },
  PLAYLIST_BADGE_COLOR = { nil, "hex", "playlist_badge_color" },
}

-- =============================================================================
-- DERIVED SOURCES
-- =============================================================================
-- These are computed once from base_bg, then used as sources for other colors.

M.derived_sources = {
  "text",    -- auto_text_color(bg)
  "accent",  -- adjust_lightness(bg, accent_bright_delta)
  "panel",   -- adjust_lightness(bg, bg_panel_delta) -- same as BG_PANEL
}

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Get all color keys in the palette
--- @return table Array of color key names
function M.get_keys()
  local keys = {}
  for key in pairs(M.definition) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

--- Get derivation info for a color
--- @param key string Color key name
--- @return table|nil Derivation definition
function M.get_derivation(key)
  return M.definition[key]
end

return M
