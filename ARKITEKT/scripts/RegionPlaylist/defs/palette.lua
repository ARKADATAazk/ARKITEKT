-- @noindex
-- RegionPlaylist/defs/palette.lua
-- Script-specific theme-reactive palette
--
-- Uses ThemeManager's DSL (snap/lerp/offset) for theme-reactive colors.
-- Register at load time, access computed values via get_colors().

local Ark = require('arkitekt')
local ThemeManager = require('arkitekt.core.theme_manager')

-- DSL wrappers (short names)
local snap = ThemeManager.snap
local lerp = ThemeManager.lerp
local offset = ThemeManager.offset

local M = {}

-- =============================================================================
-- REGISTER THEME-REACTIVE PALETTE (flat structure)
-- =============================================================================
-- Colors adapt to dark/light theme while preserving semantic meaning.

ThemeManager.register_script_palette('RegionPlaylist', {
  -- === CIRCULAR DEPENDENCY (error state) ===
  CIRCULAR_BASE         = snap('#240C0C', '#FFDDDD'),  -- dark red / light pink
  CIRCULAR_STRIPE       = snap('#430D0D', '#FFCCCC'),
  CIRCULAR_BORDER       = snap('#240F0F', '#FFCCCC'),
  CIRCULAR_TEXT         = snap('#901B1B', '#CC0000'),  -- muted red / vivid red
  CIRCULAR_LOCK         = snap('#901B1B', '#CC0000'),
  CIRCULAR_CHIP         = snap('#901B1B', '#CC0000'),
  CIRCULAR_BADGE_BG     = snap('#240C0C', '#FFE0E0'),
  CIRCULAR_BADGE_BORDER = snap('#652A2A', '#CC8888'),

  -- === CIRCULAR VALUES ===
  CIRCULAR_STRIPE_OPACITY = lerp(0.20, 0.30),
  CIRCULAR_STRIPE_WIDTH   = lerp(8, 8),      -- constant
  CIRCULAR_STRIPE_SPACING = lerp(16, 16),    -- constant

  -- === FALLBACK ===
  FALLBACK_CHIP = snap('#FF5733', '#E64A19'),  -- orange-red

  -- === CUSTOM PANEL (example of offset) ===
  -- CUSTOM_PANEL_BG = offset(-0.06),  -- Would derive from BG_BASE
})

-- =============================================================================
-- COMPUTED PALETTE ACCESS
-- =============================================================================

--- Get computed circular dependency colors (theme-reactive)
--- @return table Colors ready for ImGui drawing
function M.get_circular()
  local p = ThemeManager.get_script_palette('RegionPlaylist')
  if not p then
    -- Fallback if not registered
    return {
      base = Ark.Colors.hexrgb('#240C0CFF'),
      stripe = Ark.Colors.hexrgb('#430D0D33'),
      border = Ark.Colors.hexrgb('#240F0FFF'),
      text = Ark.Colors.hexrgb('#901B1BFF'),
      lock = Ark.Colors.hexrgb('#901B1BFF'),
      chip = Ark.Colors.hexrgb('#901B1BFF'),
      badge_bg = Ark.Colors.hexrgb('#240C0CFF'),
      badge_border = Ark.Colors.hexrgb('#652A2AFF'),
      stripe_width = 8,
      stripe_spacing = 16,
    }
  end

  return {
    base         = p.CIRCULAR_BASE,
    stripe       = Ark.Colors.with_opacity(p.CIRCULAR_STRIPE, p.CIRCULAR_STRIPE_OPACITY),
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
  local p = ThemeManager.get_script_palette('RegionPlaylist')
  if not p then
    return Ark.Colors.hexrgb('#FF5733FF')
  end
  return p.FALLBACK_CHIP
end

-- =============================================================================
-- STYLE.COLORS GETTERS (from main palette)
-- =============================================================================
-- These pull from Ark.Style.COLORS (set by ThemeManager) with fallbacks.

--- Get badge colors
--- @return table { bg, text, border_opacity }
function M.get_badge()
  local S = Ark.Style.COLORS or {}
  return {
    bg = S.BADGE_BG or Ark.Colors.hexrgb('#14181CDD'),
    text = S.BADGE_TEXT or Ark.Colors.hexrgb('#FFFFFFDD'),
    border_opacity = S.BADGE_BORDER_OPACITY or 0.20,
  }
end

--- Get playlist tile colors
--- @return table { base, name, badge }
function M.get_playlist_tile()
  local S = Ark.Style.COLORS or {}
  return {
    base  = S.PLAYLIST_TILE_COLOR or Ark.Colors.hexrgb('#3A3A3AFF'),
    name  = S.PLAYLIST_NAME_COLOR or Ark.Colors.hexrgb('#CCCCCCFF'),
    badge = S.PLAYLIST_BADGE_COLOR or Ark.Colors.hexrgb('#999999FF'),
  }
end

return M
