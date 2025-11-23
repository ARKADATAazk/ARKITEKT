-- @noindex
-- TemplateBrowser/core/config.lua
-- Configuration settings (re-exports from defs for backward compatibility)

local Constants = require('TemplateBrowser.defs.constants')

local M = {}

-- Re-export constants for backward compatibility
M.PANEL_SPACING = Constants.PANEL.SPACING
M.PANEL_PADDING = Constants.PANEL.PADDING
M.PANEL_ROUNDING = Constants.PANEL.ROUNDING

M.FOLDERS_PANEL_WIDTH_RATIO = Constants.PANEL_RATIOS.LEFT_DEFAULT
M.TEMPLATES_PANEL_WIDTH_RATIO = Constants.PANEL_RATIOS.TEMPLATE_DEFAULT
M.TAGS_PANEL_WIDTH_RATIO = Constants.PANEL_RATIOS.INFO_DEFAULT

M.COLORS = Constants.COLORS
M.TAG_COLORS = Constants.TAG_COLORS

M.TEMPLATE_ITEM_HEIGHT = Constants.ITEM.TEMPLATE_HEIGHT
M.FOLDER_ITEM_HEIGHT = Constants.ITEM.FOLDER_HEIGHT

M.TILE = {
  GRID_MIN_WIDTH = Constants.TILE.GRID_MIN_WIDTH,
  GRID_MAX_WIDTH = Constants.TILE.GRID_MAX_WIDTH,
  GRID_DEFAULT_WIDTH = Constants.TILE.GRID_DEFAULT_WIDTH,
  GRID_WIDTH_STEP = Constants.TILE.GRID_WIDTH_STEP,
  LIST_MIN_WIDTH = Constants.TILE.LIST_MIN_WIDTH,
  LIST_MAX_WIDTH = Constants.TILE.LIST_MAX_WIDTH,
  LIST_DEFAULT_WIDTH = Constants.TILE.LIST_DEFAULT_WIDTH,
  LIST_WIDTH_STEP = Constants.TILE.LIST_WIDTH_STEP,
}

return M
