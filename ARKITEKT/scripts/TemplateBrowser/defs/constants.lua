-- @noindex
-- TemplateBrowser/defs/constants.lua
-- Pure value constants: colors, dimensions

local Colors = require('arkitekt.core.colors')
local ColorDefs = require('arkitekt.defs.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- COLORS
-- ============================================================================
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

-- Status bar message colors
M.STATUS = {
  ERROR = hexrgb("#FF4444"),
  WARNING = hexrgb("#FFA500"),
  SUCCESS = hexrgb("#4AFF4A"),
  INFO = hexrgb("#FFFFFF"),
}

-- Tag color palette (from centralized palette)
M.TAG_COLORS = {}
for i, color in ipairs(ColorDefs.PALETTE) do
  M.TAG_COLORS[i] = hexrgb(color.hex)
end

-- Default tag color (Blue from palette)
M.DEFAULT_TAG_COLOR = hexrgb(ColorDefs.PALETTE[1].hex)

-- ============================================================================
-- PANEL LAYOUT
-- ============================================================================
M.PANEL = {
  SPACING = 12,
  PADDING = 16,
  ROUNDING = 6,
}

-- Panel width ratios
M.PANEL_RATIOS = {
  LEFT_DEFAULT = 0.20,
  TEMPLATE_DEFAULT = 0.55,
  INFO_DEFAULT = 0.25,
}

-- ============================================================================
-- PADDING
-- ============================================================================
M.PADDING = {
  PANEL = 14,
  PANEL_INNER = 8,
  SMALL = 4,
  SEPARATOR_SPACING = 10,
}

-- ============================================================================
-- BUTTON DIMENSIONS
-- ============================================================================
M.BUTTON = {
  WIDTH_SMALL = 24,
  WIDTH_MEDIUM = 120,
  WIDTH_LARGE = 250,
  HEIGHT_DEFAULT = 24,
  HEIGHT_ACTION = 28,
  HEIGHT_MODAL = 32,
  SPACING = 4,
}

-- ============================================================================
-- SEPARATOR
-- ============================================================================
M.SEPARATOR = {
  THICKNESS = 8,
  MIN_PANEL_WIDTH = 150,
}

-- ============================================================================
-- HEADER HEIGHTS
-- ============================================================================
M.HEADER = {
  DEFAULT = 28,
  TABS = 24,
  SEPARATOR_TEXT = 30,
}

-- ============================================================================
-- STATUS BAR
-- ============================================================================
M.STATUS_BAR = {
  HEIGHT = 24,
  AUTO_CLEAR_TIMEOUT = 10,
}

-- ============================================================================
-- TILE/GRID
-- ============================================================================
M.TILE = {
  -- Grid mode
  GRID_MIN_WIDTH = 120,
  GRID_MAX_WIDTH = 300,
  GRID_DEFAULT_WIDTH = 180,
  GRID_WIDTH_STEP = 20,

  -- List mode
  LIST_MIN_WIDTH = 300,
  LIST_MAX_WIDTH = 800,
  LIST_DEFAULT_WIDTH = 450,
  LIST_WIDTH_STEP = 50,

  -- Common
  GAP = 8,

  -- Recent templates
  RECENT_HEIGHT = 80,
  RECENT_WIDTH = 140,
  RECENT_SECTION_HEIGHT = 120,
}

-- ============================================================================
-- CHIP/TAG DIMENSIONS
-- ============================================================================
M.CHIP = {
  HEIGHT_SMALL = 20,
  HEIGHT_DEFAULT = 24,
  HEIGHT_LARGE = 28,
  DOT_SIZE = 8,
  DOT_SPACING = 10,
}

-- ============================================================================
-- COLOR PICKER
-- ============================================================================
M.COLOR_PICKER = {
  GRID_COLS = 4,
  CHIP_SIZE = 20,
}

-- ============================================================================
-- ITEM HEIGHTS
-- ============================================================================
M.ITEM = {
  TEMPLATE_HEIGHT = 32,
  FOLDER_HEIGHT = 28,
}

-- ============================================================================
-- INPUT FIELDS
-- ============================================================================
M.FIELD = {
  RENAME_WIDTH = 300,
  RENAME_HEIGHT = 24,
  NOTES_HEIGHT = 200,
}

-- ============================================================================
-- MODAL
-- ============================================================================
M.MODAL = {
  CONFLICT_WIDTH = 250,
}

-- ============================================================================
-- DRAG AND DROP TYPES
-- ============================================================================
M.DRAG_TYPES = {
  TAG = "tb_tag",
  TEMPLATE = "tb_template",
  FOLDER = "tb_folder",
}

return M
