-- @noindex
-- rearkitekt/defs/colors/init.lua
-- Color system entry point - loads theme + common colors

local Common = require('rearkitekt.defs.colors.common')
local Default = require('rearkitekt.defs.colors.default')
-- local Light = require('rearkitekt.defs.colors.light')

local M = {}

-- =============================================================================
-- CURRENT THEME
-- =============================================================================

-- TODO: Make this configurable via user settings
local current_theme = "default"

-- Load theme colors based on current theme
local function get_theme_colors()
  if current_theme == "light" then
    return require('rearkitekt.defs.colors.light')
  else
    return Default
  end
end

local Theme = get_theme_colors()

-- =============================================================================
-- EXPORT ALL COLORS
-- =============================================================================

-- Theme-specific colors
M.BASE = Theme.BASE
M.UI = Theme.UI
M.BUTTON = Theme.BUTTON
M.SCRIM = Theme.SCRIM

-- Theme-agnostic colors (from common)
M.PALETTE = Common.PALETTE
M.SEMANTIC = Common.SEMANTIC
M.OPERATIONS = Common.OPERATIONS

-- Helper functions from common
M.get_palette_colors = Common.get_palette_colors
M.get_color_by_name = Common.get_color_by_name

-- =============================================================================
-- THEME MANAGEMENT
-- =============================================================================

function M.set_theme(theme_name)
  current_theme = theme_name
  local new_theme = get_theme_colors()
  M.BASE = new_theme.BASE
  M.UI = new_theme.UI
  M.BUTTON = new_theme.BUTTON
  M.SCRIM = new_theme.SCRIM
end

function M.get_current_theme()
  return current_theme
end

-- =============================================================================
-- BACKWARD COMPATIBILITY
-- Re-export in old format for existing code
-- =============================================================================

-- Alias old paths for backward compatibility
M.success = Common.SEMANTIC.success
M.warning = Common.SEMANTIC.warning
M.error = Common.SEMANTIC.error
M.info = Common.SEMANTIC.info
M.ready = Common.SEMANTIC.ready
M.playing = Common.SEMANTIC.playing
M.idle = Common.SEMANTIC.idle

return M
