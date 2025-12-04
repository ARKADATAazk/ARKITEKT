-- @noindex
-- ThemeAdjuster/defs/constants.lua
-- Pure value constants: colors, dimensions, tabs

local Ark = require('arkitekt')
local M = {}

-- ============================================================================
-- STATUS COLORS
-- ============================================================================
M.STATUS = {
  READY = 0x41E0A3FF,
  WARNING = 0xE0B341FF,
  ERROR = 0xE04141FF,
  INFO = 0xCCCCCCFF,
}

-- ============================================================================
-- THEME CATEGORY COLORS (Desaturated palette for consistent theming)
-- ============================================================================
M.THEME_CATEGORY_COLORS = {
  -- Track/Channel panels
  tcp_blue = 0x5C7CB8FF,
  mcp_green = 0x6B9B7CFF,
  envcp_purple = 0x9B7CB8FF,
  -- Media items
  items_pink = 0xB85C8BFF,
  midi_teal = 0x5C9B9BFF,
  -- Transport/Toolbar
  transport_gold = 0xB8A55CFF,
  toolbar_gold = 0xB89B5CFF,
  -- Utility
  meter_cyan = 0x5C9BB8FF,
  docker_brown = 0x9B8B6BFF,
  fx_orange = 0xB87C5CFF,
  menu_blue = 0x7C8BB8FF,
  -- General
  global_gray = 0x8B8B8BFF,
  other_slate = 0x6B6B8BFF,
}

-- ============================================================================
-- PACKAGE GRID DIMENSIONS
-- ============================================================================
M.PACKAGE_GRID = {
  min_col_width = 220,
  max_tile_height = 200,
  gap = 12,
  base_tile_height = 200,
}

-- ============================================================================
-- TAB DEFINITIONS
-- ============================================================================
M.TABS = {
  { id = 'GLOBAL', label = 'Global' },
  { id = 'ASSEMBLER', label = 'Assembler' },
  { id = 'TCP', label = 'TCP' },
  { id = 'MCP', label = 'MCP' },
  { id = 'COLORS', label = 'Colors' },
  { id = 'ENVELOPES', label = 'Envelopes' },
  { id = 'TRANSPORT', label = 'Transport' },
  { id = 'DEBUG', label = 'Debug' },
}

-- ============================================================================
-- HEADER DIMENSIONS
-- ============================================================================
M.HEADER = {
  height = 32,
  demo_button_width = 60,
  search_width = 200,
  filters_width = 80,
}

return M
