-- @noindex
-- TemplateBrowser/core/config.lua
-- Configuration settings

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- UI Layout
M.PANEL_SPACING = 12
M.PANEL_PADDING = 16
M.PANEL_ROUNDING = 6

-- Panel widths (proportions)
M.FOLDERS_PANEL_WIDTH_RATIO = 0.22   -- 22% for folder navigation
M.TEMPLATES_PANEL_WIDTH_RATIO = 0.50 -- 50% for template list
M.TAGS_PANEL_WIDTH_RATIO = 0.22      -- 22% for tags panel

-- Colors (placeholder - can be themed later)
M.COLORS = {
  panel_bg = hexrgb("#1A1A1A"),
  panel_border = hexrgb("#333333"),
  header_bg = hexrgb("#252525"),
  selected_bg = hexrgb("#2A5599"),
  hover_bg = hexrgb("#2A2A2A"),
  text = hexrgb("#FFFFFF"),
  text_dim = hexrgb("#888888"),
  separator = hexrgb("#404040"),
}

-- Template display
M.TEMPLATE_ITEM_HEIGHT = 32
M.FOLDER_ITEM_HEIGHT = 28

-- Tags
M.TAG_COLORS = {
  hexrgb("#3B82F6"), -- Blue
  hexrgb("#10B981"), -- Green
  hexrgb("#F59E0B"), -- Amber
  hexrgb("#EF4444"), -- Red
  hexrgb("#8B5CF6"), -- Purple
  hexrgb("#EC4899"), -- Pink
  hexrgb("#14B8A6"), -- Teal
  hexrgb("#F97316"), -- Orange
}

return M
