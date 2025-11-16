-- @noindex
-- TemplateBrowser/core/config.lua
-- Configuration settings

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
  panel_bg = 0x1a1a1aFF,
  panel_border = 0x333333FF,
  header_bg = 0x252525FF,
  selected_bg = 0x2a5599FF,
  hover_bg = 0x2a2a2aFF,
  text = 0xffffffFF,
  text_dim = 0x888888FF,
  separator = 0x404040FF,
}

-- Template display
M.TEMPLATE_ITEM_HEIGHT = 32
M.FOLDER_ITEM_HEIGHT = 28

-- Tags
M.TAG_COLORS = {
  0x3b82f6FF, -- Blue
  0x10b981FF, -- Green
  0xf59e0bFF, -- Amber
  0xef4444FF, -- Red
  0x8b5cf6FF, -- Purple
  0xec4899FF, -- Pink
  0x14b8a6FF, -- Teal
  0xf97316FF, -- Orange
}

return M
