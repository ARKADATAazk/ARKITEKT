-- @noindex
-- ItemPicker/core/config.lua
-- Centralized configuration (re-exports from defs for backward compatibility)

local Constants = require('ItemPicker.defs.constants')

local M = {}

-- Re-export all constants from defs
M.TILE = Constants.TILE
M.LAYOUT = Constants.LAYOUT
M.SEPARATOR = Constants.SEPARATOR
M.CACHE = Constants.CACHE
M.COLORS = Constants.COLORS
M.GRID = Constants.GRID
M.TILE_RENDER = Constants.TILE_RENDER
M.REGION_TAGS = Constants.REGION_TAGS
M.UI_PANELS = Constants.UI_PANELS

-- Re-export validation
M.validate = Constants.validate

return M
