-- @noindex
-- RegionPlaylist/defs/palette.lua
-- Script-specific theme-reactive palette
--
-- Uses ThemeManager's DSL (snap/lerp) for theme-reactive colors.
-- Register at load time, access computed values via get_colors().

local Style = require('arkitekt.gui.style')
local Colors = require('arkitekt.core.colors')
local ThemeManager = require('arkitekt.core.theme_manager')

-- DSL wrappers
local snap = ThemeManager.snapAtMidpoint
local lerp = ThemeManager.lerpDarkLight

local M = {}

-- =============================================================================
-- REGISTER THEME-REACTIVE PALETTE
-- =============================================================================
-- Colors adapt to dark/light theme while preserving semantic meaning.

ThemeManager.register_script_palette("RegionPlaylist", {
  specific = {
    -- Circular dependency (error state - red, but adjusted for visibility)
    CIRCULAR_BASE         = snap("#240C0C", "#FFDDDD"),  -- dark red / light pink
    CIRCULAR_STRIPE       = snap("#430D0D", "#FFCCCC"),
    CIRCULAR_BORDER       = snap("#240F0F", "#FFCCCC"),
    CIRCULAR_TEXT         = snap("#901B1B", "#CC0000"),  -- muted red / vivid red
    CIRCULAR_LOCK         = snap("#901B1B", "#CC0000"),
    CIRCULAR_CHIP         = snap("#901B1B", "#CC0000"),
    CIRCULAR_BADGE_BG     = snap("#240C0C", "#FFE0E0"),
    CIRCULAR_BADGE_BORDER = snap("#652A2A", "#CC8888"),

    -- Fallback chip color
    FALLBACK_CHIP = snap("#FF5733", "#E64A19"),  -- orange-red
  },
  values = {
    -- Circular stripe pattern
    CIRCULAR_STRIPE_OPACITY = lerp(0.20, 0.30),
    CIRCULAR_STRIPE_WIDTH   = lerp(8, 8),      -- constant
    CIRCULAR_STRIPE_SPACING = lerp(16, 16),    -- constant
  },
})

-- =============================================================================
-- COMPUTED PALETTE ACCESS
-- =============================================================================

--- Get computed circular dependency colors (theme-reactive)
--- @return table Colors ready for ImGui drawing
function M.get_circular()
  local p = ThemeManager.get_script_palette("RegionPlaylist")
  if not p then
    -- Fallback if not registered
    return {
      base = Colors.hexrgb("#240C0CFF"),
      stripe = Colors.hexrgb("#430D0D33"),
      border = Colors.hexrgb("#240F0FFF"),
      text = Colors.hexrgb("#901B1BFF"),
      lock = Colors.hexrgb("#901B1BFF"),
      chip = Colors.hexrgb("#901B1BFF"),
      badge_bg = Colors.hexrgb("#240C0CFF"),
      badge_border = Colors.hexrgb("#652A2AFF"),
      stripe_width = 8,
      stripe_spacing = 16,
    }
  end

  return {
    base         = p.CIRCULAR_BASE,
    stripe       = Colors.with_opacity(p.CIRCULAR_STRIPE, p.CIRCULAR_STRIPE_OPACITY),
    border       = p.CIRCULAR_BORDER,
    text         = p.CIRCULAR_TEXT,
    lock         = p.CIRCULAR_LOCK,
    chip         = p.CIRCULAR_CHIP,
    badge_bg     = p.CIRCULAR_BADGE_BG,
    badge_border = p.CIRCULAR_BADGE_BORDER,
    stripe_width   = p.CIRCULAR_STRIPE_WIDTH,
    stripe_spacing = p.CIRCULAR_STRIPE_SPACING,
  }
end

--- Get fallback chip color (theme-reactive)
--- @return number RGBA color
function M.get_fallback_chip()
  local p = ThemeManager.get_script_palette("RegionPlaylist")
  if not p then
    return Colors.hexrgb("#FF5733FF")
  end
  return p.FALLBACK_CHIP
end

-- =============================================================================
-- STYLE.COLORS GETTERS (from main palette)
-- =============================================================================
-- These pull from Style.COLORS (set by ThemeManager) with fallbacks.

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
