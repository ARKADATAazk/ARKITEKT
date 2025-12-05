-- @noindex
-- MediaContainer/config/constants.lua
-- Application constants and configuration values

local M = {}

-- =============================================================================
-- POLLING
-- =============================================================================

M.POLL_INTERVAL = 100  -- ms between sync checks

-- =============================================================================
-- UI DIMENSIONS
-- =============================================================================

M.BUTTON_WIDTH = 80
M.CONTAINER_LIST_HEIGHT = 120

-- =============================================================================
-- COLORS
-- =============================================================================

M.COLORS = {
  delete_button = 0x662222FF,
  delete_button_hover = 0x883333FF,
  default_container = 0xFF6600FF,
}

-- =============================================================================
-- CONTAINER DEFAULTS
-- =============================================================================

M.CONTAINER = {
  -- HSL ranges for random color generation
  saturation_min = 0.65,
  saturation_range = 0.25,
  lightness_min = 0.50,
  lightness_range = 0.15,
}

-- =============================================================================
-- OVERLAY
-- =============================================================================

M.OVERLAY = {
  label_height = 20,
  fill_alpha_master = 0.20,
  fill_alpha_linked = 0.15,
  fill_alpha_dragging = 0.10,  -- Added to base alpha when dragging
  border_alpha_master = 0.8,
  border_alpha_linked = 0.6,
  border_thickness_master = 2,
  border_thickness_linked = 1,
  border_thickness_dragging = 3,
  dash_length = 6,
  gap_length = 4,
  label_padding = 4,
  label_bg_alpha = 0.6,
  label_bg_hover_alpha = 0.8,
}

return M
