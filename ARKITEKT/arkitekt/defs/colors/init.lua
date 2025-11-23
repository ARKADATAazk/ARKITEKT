-- @noindex
-- arkitekt/defs/colors/init.lua
-- Color system entry point - exports theme colors + common colors

local Common = require('arkitekt.defs.colors.common')
local Theme = require('arkitekt.defs.colors.default')

local M = {}

-- =============================================================================
-- EXPORT THEME COLORS
-- =============================================================================

M.BASE = Theme.BASE
M.UI = Theme.UI
M.BUTTON = Theme.BUTTON
M.SCRIM = Theme.SCRIM

-- =============================================================================
-- EXPORT COMMON COLORS (theme-agnostic)
-- =============================================================================

M.PALETTE = Common.PALETTE
M.SEMANTIC = Common.SEMANTIC
M.OPERATIONS = Common.OPERATIONS

-- Helper functions from common
M.get_palette_colors = Common.get_palette_colors
M.get_color_by_name = Common.get_color_by_name

-- =============================================================================
-- BACKWARD COMPATIBILITY
-- =============================================================================

M.success = Common.SEMANTIC.success
M.warning = Common.SEMANTIC.warning
M.error = Common.SEMANTIC.error
M.info = Common.SEMANTIC.info
M.ready = Common.SEMANTIC.ready
M.playing = Common.SEMANTIC.playing
M.idle = Common.SEMANTIC.idle

return M
