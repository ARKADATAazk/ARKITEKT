-- @noindex
-- ThemeAdjuster/defs/constants.lua
-- Pure value constants: colors, dimensions, tabs

local Colors = require('arkitekt.core.colors')
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
-- THEME CATEGORY COLORS (Desaturated palette for consistent theming)
-- ============================================================================
M.THEME_CATEGORY_COLORS = {
  -- Track/Channel panels
  tcp_blue = hexrgb("#5C7CB8"),
  mcp_green = hexrgb("#6B9B7C"),
  envcp_purple = hexrgb("#9B7CB8"),
  -- Media items
  items_pink = hexrgb("#B85C8B"),
  midi_teal = hexrgb("#5C9B9B"),
  -- Transport/Toolbar
  transport_gold = hexrgb("#B8A55C"),
  toolbar_gold = hexrgb("#B89B5C"),
  -- Utility
  meter_cyan = hexrgb("#5C9BB8"),
  docker_brown = hexrgb("#9B8B6B"),
  fx_orange = hexrgb("#B87C5C"),
  menu_blue = hexrgb("#7C8BB8"),
  -- General
  global_gray = hexrgb("#8B8B8B"),
  other_slate = hexrgb("#6B6B8B"),
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
