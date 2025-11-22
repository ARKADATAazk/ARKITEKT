-- @noindex
-- ThemeAdjuster/defs/constants.lua
-- Pure value constants: colors, dimensions, tabs

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- STATUS COLORS
-- ============================================================================
M.STATUS = {
  READY = hexrgb("#41E0A3"),
  WARNING = hexrgb("#E0B341"),
  ERROR = hexrgb("#E04141"),
  INFO = hexrgb("#CCCCCC"),
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
  { id = "GLOBAL", label = "Global" },
  { id = "ASSEMBLER", label = "Assembler" },
  { id = "TCP", label = "TCP" },
  { id = "MCP", label = "MCP" },
  { id = "COLORS", label = "Colors" },
  { id = "ENVELOPES", label = "Envelopes" },
  { id = "TRANSPORT", label = "Transport" },
  { id = "DEBUG", label = "Debug" },
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
