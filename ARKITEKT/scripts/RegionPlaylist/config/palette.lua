-- @noindex
-- RegionPlaylist/defs/palette.lua
-- Script-specific theme-reactive palette
--
-- Uses ThemeManager's DSL (snap2/lerp2/offset2) for theme-reactive colors.
-- Register at load time, access computed values via get_colors().

local Ark = require('arkitekt')
local ThemeManager = require('arkitekt.theme.manager')

-- DSL wrappers (short names)
local snap2 = ThemeManager.snap2
local lerp2 = ThemeManager.lerp2
local offset2 = ThemeManager.offset2

local M = {}

-- =============================================================================
-- REGISTER THEME-REACTIVE PALETTE (flat structure)
-- =============================================================================
-- Colors adapt to dark/light theme while preserving semantic meaning.

ThemeManager.register_script_palette('RegionPlaylist', {
  -- === CIRCULAR DEPENDENCY (error state) ===
  CIRCULAR_BASE         = snap2(0x240C0CFF, 0xFFDDDDFF),  -- dark red / light pink
  CIRCULAR_STRIPE       = snap2(0x430D0DFF, 0xFFCCCCFF),
  CIRCULAR_BORDER       = snap2(0x240F0FFF, 0xFFCCCCFF),
  CIRCULAR_TEXT         = snap2(0x901B1BFF, 0xCC0000FF),  -- muted red / vivid red
  CIRCULAR_LOCK         = snap2(0x901B1BFF, 0xCC0000FF),
  CIRCULAR_CHIP         = snap2(0x901B1BFF, 0xCC0000FF),
  CIRCULAR_BADGE_BG     = snap2(0x240C0CFF, 0xFFE0E0FF),
  CIRCULAR_BADGE_BORDER = snap2(0x652A2AFF, 0xCC8888FF),

  -- === CIRCULAR VALUES ===
  CIRCULAR_STRIPE_OPACITY = lerp2(0.20, 0.30),
  CIRCULAR_STRIPE_WIDTH   = lerp2(8, 8),      -- constant
  CIRCULAR_STRIPE_SPACING = lerp2(16, 16),    -- constant

  -- === FALLBACK ===
  FALLBACK_CHIP = snap2(0xFF5733FF, 0xE64A19FF),  -- orange-red

  -- === CUSTOM PANEL (example of offset) ===
  -- CUSTOM_PANEL_BG = offset2(-0.06),  -- Would derive from BG_BASE
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
      base = 0x240C0CFF,
      stripe = 0x430D0D33,
      border = 0x240F0FFF,
      text = 0x901B1BFF,
      lock = 0x901B1BFF,
      chip = 0x901B1BFF,
      badge_bg = 0x240C0CFF,
      badge_border = 0x652A2AFF,
      stripe_width = 8,
      stripe_spacing = 16,
    }
  end

  return {
    base         = p.CIRCULAR_BASE,
    stripe       = Ark.Colors.WithOpacity(p.CIRCULAR_STRIPE, p.CIRCULAR_STRIPE_OPACITY),
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
    return 0xFF5733FF
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
    bg = S.BADGE_BG or 0x14181CDD,
    text = S.BADGE_TEXT or 0xFFFFFFDD,
    border_opacity = S.BADGE_BORDER_OPACITY or 0.20,
  }
end

--- Get playlist tile colors
--- @return table { base, name, badge }
function M.get_playlist_tile()
  local S = Ark.Style.COLORS or {}
  return {
    base  = S.PLAYLIST_TILE_COLOR or 0x3A3A3AFF,
    name  = S.PLAYLIST_NAME_COLOR or 0xCCCCCCFF,
    badge = S.PLAYLIST_BADGE_COLOR or 0x999999FF,
  }
end

return M
