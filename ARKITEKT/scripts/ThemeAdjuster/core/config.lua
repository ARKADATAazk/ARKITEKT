-- @noindex
-- ThemeAdjuster/core/config.lua
-- Configuration and constants

local M = {}

M.PACKAGE_GRID = {
  min_col_width = 220,
  max_tile_height = 200,
  gap = 12,
  default_filters = {
    TCP = true,
    MCP = true,
    Transport = true,
    Global = true,
  },
}

M.PANEL = {
  header_height = 42,
  padding = 8,
}

M.DEMO = {
  enabled = true,  -- Start with demo enabled
  package_count = 8,
}

return M
