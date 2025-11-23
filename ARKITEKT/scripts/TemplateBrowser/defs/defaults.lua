-- @noindex
-- TemplateBrowser/defs/defaults.lua
-- Default configuration values

local Constants = require('TemplateBrowser.defs.constants')

local M = {}

-- ============================================================================
-- TILE SIZE DEFAULTS
-- ============================================================================
M.TILE = {
  grid_width = Constants.TILE.GRID_DEFAULT_WIDTH,
  list_width = Constants.TILE.LIST_DEFAULT_WIDTH,
}

-- ============================================================================
-- SEPARATOR DEFAULTS
-- ============================================================================
M.SEPARATOR = {
  quick_access_position = 350,
  explorer_height_ratio = 0.6,
}

-- ============================================================================
-- TOOLTIP CONFIG
-- ============================================================================
M.TOOLTIP = {
  delay = 0.5,
  wrap_width = 300,
  bg_color = 0x1E1E1EFF,
  border_color = 0x4A4A4AFF,
  text_color = 0xFFFFFFFF,
  padding = 8,
}

-- ============================================================================
-- UNDO CONFIG
-- ============================================================================
M.UNDO = {
  max_stack_size = 50,
}

-- ============================================================================
-- ANIMATION
-- ============================================================================
M.ANIMATION = {
  tile_speed = 16.0,
}

-- ============================================================================
-- VST DISPLAY
-- ============================================================================
M.VST = {
  -- VSTs to hide from tile preview (still shown in FX chain views)
  -- These are typically utility plugins that aren't the "main" instrument
  tile_blacklist = {
    "ReaControlMIDI",
    "ReaInsert",
  },
}

return M
