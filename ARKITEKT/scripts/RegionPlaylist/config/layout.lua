-- @noindex
-- RegionPlaylist/config/layout.lua
-- Layout configuration: dimensions, spacing, responsive breakpoints

local M = {}

-- ============================================================================
-- ANIMATION TIMING
-- ============================================================================
M.ANIMATION = {
  -- General hover animations
  hover_speed = 12.0,

  -- Fade transitions
  fade_in_speed = 8.0,
  fade_out_speed = 6.25,  -- ~2 second fade out

  -- Selector/chip animations
  selector_speed = 10.0,
}

-- ============================================================================
-- TRANSPORT DISPLAY LAYOUT
-- ============================================================================
M.TRANSPORT_DISPLAY = {
  -- Global positioning
  global_offset_y = -5,

  -- Padding
  padding = 48,
  padding_top = 8,

  -- Spacing
  spacing_horizontal = 12,
  spacing_progress = 8,

  -- Progress bar
  progress_height = 3,
  progress_bottom_offset = 12,
  progress_padding_left = 56,
  progress_padding_right = 56,

  -- Playlist chip (color indicator)
  playlist_chip_size = 8,
  playlist_chip_offset_x = 4,
  playlist_chip_offset_y = 2,
  playlist_name_offset_x = 12,
  playlist_name_offset_y = 2,

  -- Time display
  time_offset_x = 0,
  time_offset_y = 0,

  -- Region labels
  region_label_spacing = 4,
  current_region_offset_x = 0,
  current_region_offset_y = 0,
  next_region_offset_x = 0,
  next_region_offset_y = 0,

  -- Content positioning
  content_vertical_offset = -2,

  -- Responsive breakpoints
  hide_playlist_width = 500,
  truncate_region_width = 450,
  hide_region_width = 300,
  region_name_max_chars = 15,
  region_name_min_chars = 8,
}

-- ============================================================================
-- TRANSPORT BUTTONS
-- ============================================================================
M.TRANSPORT_BUTTONS = {
  -- Default button dimensions
  default_height = 30,
  icon_size = 16,

  -- Corner button styling
  rounding = 4,
  inner_rounding_offset = 2,  -- inner_rounding = rounding - offset
}

-- ============================================================================
-- QUANTIZE SLIDER
-- ============================================================================
M.QUANTIZE_SLIDER = {
  -- Lookahead range (milliseconds)
  min_ms = 250,
  max_ms = 1000,

  -- Style overrides
  grab_min_size = 14,
  frame_padding_x = 4,
  frame_padding_y = 6,
  grab_rounding = 0,
}

-- ============================================================================
-- TILE RENDERER (Active Grid)
-- ============================================================================
M.TILE_ACTIVE = {
  -- Responsive thresholds (tile height in pixels)
  hide_length_below = 50,
  hide_badge_below = 25,
  hide_text_below = 15,

  -- Badge styling
  badge_rounding = 4,
  badge_padding_x = 6,
  badge_padding_y = 3,
  badge_margin = 6,
  badge_nudge_x = 0,
  badge_nudge_y = 0,
  badge_text_nudge_x = -1,
  badge_text_nudge_y = -1,

  -- Text margins
  text_margin_right = 6,

  -- Warning badge gap
  warning_badge_gap = 4,
}

-- ============================================================================
-- PLAYLIST SELECTOR
-- ============================================================================
M.SELECTOR = {
  chip_width = 110,
  chip_height = 30,
  gap = 10,
  border_thickness = 1.5,
  rounding = 4,
}

-- ============================================================================
-- UTILITIES
-- ============================================================================
M.UTILITIES = {
  -- Floating point rounding tolerance for bar length formatting
  rounding_tolerance = 0.005,
}

return M
