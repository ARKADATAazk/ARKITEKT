-- @noindex
-- rearkitekt/defs/colors/light.lua
-- Light theme color definitions (stub for future implementation)

local M = {}

-- =============================================================================
-- BASE PALETTE (gray scale - inverted for light theme)
-- =============================================================================

M.BASE = {
  black = "#000000FF",
  white = "#FFFFFFFF",

  -- Grays (light to dark for light theme)
  gray_50 = "#FAFAFAFF",
  gray_100 = "#F5F5F5FF",
  gray_200 = "#E5E5E5FF",
  gray_300 = "#D4D4D4FF",
  gray_400 = "#A3A3A3FF",
  gray_500 = "#737373FF",
  gray_600 = "#525252FF",
  gray_700 = "#404040FF",
  gray_800 = "#262626FF",
  gray_900 = "#171717FF",
}

-- =============================================================================
-- UI ROLES (semantic mappings for light theme)
-- =============================================================================

M.UI = {
  -- Text
  text_primary = "#171717FF",
  text_secondary = "#525252FF",
  text_disabled = "#A3A3A3FF",
  text_bright = "#000000FF",

  -- Backgrounds
  bg_base = "#FFFFFFFF",
  bg_panel = "#FAFAFAFF",
  bg_elevated = "#F5F5F5FF",
  bg_hover = "#E5E5E5FF",
  bg_selected = "#DBEAFEFF",

  -- Borders
  border = "#E5E5E5FF",
  border_light = "#D4D4D4FF",
  divider = "#F5F5F5FF",

  -- Interactive
  primary = "#2563EBFF",
  primary_hover = "#1D4ED8FF",
  primary_active = "#1E40AFFF",

  -- Overlays
  overlay_light = "#00000010",
  overlay_dark = "#00000020",
  shadow = "#00000033",

  -- Badge/chip backgrounds
  badge_bg = "#F3F4F6FF",
}

-- =============================================================================
-- BUTTON COLORS
-- =============================================================================

M.BUTTON = {
  -- Close button
  close_normal = "#00000000",
  close_hover = "#FEE2E2FF",
  close_active = "#FECACAFF",

  -- Maximize button
  maximize_normal = "#00000000",
  maximize_hover = "#D1FAE5FF",
  maximize_active = "#A7F3D0FF",
}

-- =============================================================================
-- SCRIM/MODAL COLORS
-- =============================================================================

M.SCRIM = {
  color = "#000000FF",
  default_opacity = 0.5,
}

return M
