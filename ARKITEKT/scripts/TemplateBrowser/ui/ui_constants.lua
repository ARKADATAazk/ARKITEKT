-- @noindex
-- TemplateBrowser/ui/ui_constants.lua
-- UI layout constants (re-exports from defs for backward compatibility)

local Constants = require('TemplateBrowser.defs.constants')

local M = {}

-- Re-export all constants
M.PADDING = Constants.PADDING
M.BUTTON = Constants.BUTTON
M.SEPARATOR = Constants.SEPARATOR
M.HEADER = Constants.HEADER
M.STATUS_BAR = Constants.STATUS_BAR
M.TILE = Constants.TILE
M.PANEL_RATIOS = Constants.PANEL_RATIOS
M.CHIP = Constants.CHIP
M.COLOR_PICKER = Constants.COLOR_PICKER
M.FIELD = Constants.FIELD
M.MODAL = Constants.MODAL

return M
