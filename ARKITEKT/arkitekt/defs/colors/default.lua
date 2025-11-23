-- @noindex
-- arkitekt/defs/colors/default.lua
-- Dark theme color definitions

local M = {}

-- =============================================================================
-- BASE PALETTE (gray scale)
-- =============================================================================

M.BASE = {
  black = "#000000FF",
  white = "#FFFFFFFF",

  -- Grays (dark to light)
  gray_50 = "#0A0A0AFF",
  gray_100 = "#1A1A1AFF",
  gray_200 = "#252525FF",
  gray_300 = "#333333FF",
  gray_400 = "#404040FF",
  gray_500 = "#666666FF",
  gray_600 = "#888888FF",
  gray_700 = "#AAAAAAFF",
  gray_800 = "#CCCCCCFF",
  gray_900 = "#E5E5E5FF",
}

-- =============================================================================
-- UI ROLES (semantic mappings for dark theme)
-- =============================================================================

M.UI = {
  -- Text
  text_primary = "#CCCCCCFF",
  text_secondary = "#888888FF",
  text_disabled = "#666666FF",
  text_bright = "#FFFFFFFF",

  -- Backgrounds
  bg_deep = "#131313FF",
  bg_base = "#1A1A1AFF",
  bg_panel = "#252525FF",
  bg_elevated = "#333333FF",
  bg_hover = "#404040FF",
  bg_selected = "#2A5599FF",

  -- Borders
  border = "#333333FF",
  border_light = "#404040FF",
  divider = "#2A2A2AFF",

  -- Interactive
  primary = "#5588FFFF",
  primary_hover = "#6699FFFF",
  primary_active = "#4477EEFF",

  -- Overlays
  overlay_light = "#FFFFFF20",
  overlay_dark = "#00000050",
  shadow = "#00000099",

  -- Badge/chip backgrounds
  badge_bg = "#14181CFF",
}

-- =============================================================================
-- BUTTON COLORS
-- =============================================================================

M.BUTTON = {
  -- Close button
  close_normal = "#00000000",
  close_hover = "#CC3333FF",
  close_active = "#FF1111FF",

  -- Maximize button
  maximize_normal = "#00000000",
  maximize_hover = "#57C290FF",
  maximize_active = "#60FFFFFF",
}

-- =============================================================================
-- SCRIM/MODAL COLORS
-- =============================================================================

M.SCRIM = {
  color = "#121212FF",
  default_opacity = 0.99,
}

return M
