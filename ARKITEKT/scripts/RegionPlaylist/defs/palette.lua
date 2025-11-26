-- @noindex
-- RegionPlaylist/defs/palette.lua
-- Script-specific color definitions
--
-- Structure:
--   static   - fixed colors that don't change with theme (error states, etc.)
--   getters  - convenience functions that pull from Style.COLORS with fallbacks

local Style = require('arkitekt.gui.style')
local Colors = require('arkitekt.core.colors')

local M = {}

-- =============================================================================
-- STATIC COLORS (fixed, not theme-reactive)
-- =============================================================================

--- Circular dependency error state (semantic red - always visible as error)
M.CIRCULAR = {
  base       = Colors.hexrgb("#240C0CFF"),
  stripe     = Colors.with_opacity(Colors.hexrgb("#430D0DFF"), 0.2),
  border     = Colors.hexrgb("#240F0FFF"),
  text       = Colors.hexrgb("#901B1BFF"),
  lock       = Colors.hexrgb("#901B1BFF"),
  chip       = Colors.hexrgb("#901B1BFF"),
  badge_bg   = Colors.hexrgb("#240C0CFF"),
  badge_border = Colors.hexrgb("#652A2AFF"),
  -- Pattern dimensions
  stripe_width   = 8,
  stripe_spacing = 16,
}

--- Fallback colors when no color is assigned
M.FALLBACK = {
  chip = Colors.hexrgb("#FF5733FF"),  -- Orange-red default
}

-- =============================================================================
-- THEME-REACTIVE GETTERS
-- =============================================================================
-- These pull from Style.COLORS (set by ThemeManager) with fallbacks

--- Get badge colors
--- @return table { bg, text, border_opacity }
function M.get_badge()
  local S = Style.COLORS or {}
  return {
    bg = S.BADGE_BG or Colors.hexrgb("#14181CDD"),
    text = S.BADGE_TEXT or Colors.hexrgb("#FFFFFFDD"),
    border_opacity = S.BADGE_BORDER_OPACITY or 0.20,
  }
end

--- Get playlist tile colors
--- @return table { base, name, badge }
function M.get_playlist_tile()
  local S = Style.COLORS or {}
  return {
    base  = S.PLAYLIST_TILE_COLOR or Colors.hexrgb("#3A3A3AFF"),
    name  = S.PLAYLIST_NAME_COLOR or Colors.hexrgb("#CCCCCCFF"),
    badge = S.PLAYLIST_BADGE_COLOR or Colors.hexrgb("#999999FF"),
  }
end

return M
