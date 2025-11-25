-- @noindex
-- RegionPlaylist/defs/colors.lua
-- Script-specific color definitions
--
-- Pattern:
--   nil = derive from Style.COLORS (theme-reactive)
--   explicit value = stays fixed regardless of theme

local ark = require('arkitekt')
local Style = require('arkitekt.gui.style')
local hexrgb = ark.Colors.hexrgb

local M = {}

-- ============================================================================
-- CIRCULAR DEPENDENCY (error state for nested playlists)
-- ============================================================================
-- These are semantic "error" colors - red variants that stay red regardless
-- of theme. They signal a problem state, not normal UI chrome.

M.CIRCULAR = {
  -- Tile appearance
  base_color = "#240C0C",           -- Dark red background
  stripe_color = "#430D0D",         -- Diagonal stripe color
  stripe_opacity = 0x33,            -- Stripe transparency
  border_color = "#240F0F",         -- Tile border
  text_color = "#901B1B",           -- Warning text
  lock_color = "#901B1B",           -- Lock icon color

  -- Playlist chip on circular tile
  chip_color = "#901B1B",

  -- Badge styling
  badge_bg = "#240C0C",
  badge_border_color = "#652A2A",

  -- Pattern dimensions
  stripe_width = 8,
  stripe_spacing = 16,
}

--- Get circular dependency colors as RGBA values
--- @return table Colors ready for ImGui drawing
function M.get_circular()
  return {
    base_color = hexrgb(M.CIRCULAR.base_color .. "FF"),
    stripe_color = ark.Colors.with_alpha(
      hexrgb(M.CIRCULAR.stripe_color .. "FF"),
      M.CIRCULAR.stripe_opacity
    ),
    border_color = hexrgb(M.CIRCULAR.border_color .. "FF"),
    text_color = hexrgb(M.CIRCULAR.text_color .. "FF"),
    lock_color = hexrgb(M.CIRCULAR.lock_color .. "FF"),
    chip_color = hexrgb(M.CIRCULAR.chip_color .. "FF"),
    badge_bg = hexrgb(M.CIRCULAR.badge_bg .. "FF"),
    badge_border_color = hexrgb(M.CIRCULAR.badge_border_color .. "FF"),
    stripe_width = M.CIRCULAR.stripe_width,
    stripe_spacing = M.CIRCULAR.stripe_spacing,
  }
end

-- ============================================================================
-- FALLBACK COLORS
-- ============================================================================
-- Default chip color when playlist/region has none assigned

M.FALLBACK = {
  chip_color = "#FF5733",  -- Orange-red default
}

--- Get fallback chip color
--- @return number RGBA color
function M.get_fallback_chip()
  return hexrgb(M.FALLBACK.chip_color .. "FF")
end

-- ============================================================================
-- BADGE COLORS (from Style.COLORS when available)
-- ============================================================================
-- These pull from the theme system but can be overridden per-script

--- Get badge colors, falling back to Style.COLORS
--- @return table Badge color values
function M.get_badge()
  local S = Style.COLORS
  return {
    bg = S.BADGE_BG or hexrgb("#14181CDD"),
    text = S.BADGE_TEXT or hexrgb("#FFFFFFDD"),
    border_opacity = S.BADGE_BORDER_OPACITY or 0.20,
  }
end

--- Get playlist tile colors, falling back to Style.COLORS
--- @return table Playlist tile color values
function M.get_playlist_tile()
  local S = Style.COLORS
  return {
    base_color = S.PLAYLIST_TILE_COLOR or hexrgb("#3A3A3AFF"),
    name_color = S.PLAYLIST_NAME_COLOR or hexrgb("#CCCCCCFF"),
    badge_color = S.PLAYLIST_BADGE_COLOR or hexrgb("#999999FF"),
  }
end

return M
