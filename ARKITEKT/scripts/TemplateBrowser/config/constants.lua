-- @noindex
-- TemplateBrowser/defs/constants.lua
-- Pure value constants: colors, dimensions

local ColorDefs = require('arkitekt.config.colors')
local Ark = require('arkitekt')
local M = {}

-- ============================================================================
-- COLORS
-- ============================================================================
M.COLORS = {
  panel_bg = 0x1A1A1AFF,
  panel_border = 0x333333FF,
  header_bg = 0x252525FF,
  selected_bg = 0x2A5599FF,
  hover_bg = 0x2A2A2AFF,
  text = 0xFFFFFFFF,
  text_dim = 0x888888FF,
  separator = 0x404040FF,
}

-- Status bar message colors
M.STATUS = {
  ERROR = 0xFF4444FF,
  WARNING = 0xFFA500FF,
  SUCCESS = 0x4AFF4AFF,
  INFO = 0xFFFFFFFF,
}

-- Tag color palette (from centralized palette)
M.TAG_COLORS = {}
for i, color in ipairs(ColorDefs.PALETTE) do
  M.TAG_COLORS[i] = color.hex  -- .hex is now a byte value
end

-- Default tag color (Blue from palette)
M.DEFAULT_TAG_COLOR = ColorDefs.PALETTE[1].hex

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
-- TITLE
-- ============================================================================
M.TITLE = {
  Y_OFFSET = -15,  -- Negative offset to move title up for tighter layout
  SPACING_AFTER = 30,  -- Space below title before content
}

-- ============================================================================
-- SEARCH TOOLBAR
-- ============================================================================
M.SEARCH = {
  HEIGHT = 28,
  WIDTH = 400,
  CLEAR_BUTTON_SIZE = 16,
  SPACING_AFTER = 8,
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
  TAG = 'tb_tag',
  TEMPLATE = 'tb_template',
  FOLDER = 'tb_folder',
}

-- ============================================================================
-- SPECIAL FOLDERS
-- ============================================================================
M.FOLDERS = {
  INBOX = '_Inbox',     -- Unsorted templates, pinned at top
  ARCHIVE = '_Archive', -- Deleted templates
}

-- ============================================================================
-- BATCH PROCESSING
-- ============================================================================
M.FX_QUEUE = {
  BATCH_SIZE = 5,  -- Templates per frame for FX parsing
}

M.SCANNER = {
  BATCH_SIZE = 50,  -- Files per frame during template scanning
}

-- ============================================================================
-- TOOLTIP CONFIG
-- ============================================================================
M.TOOLTIP = {
  delay = 0.5,
  wrap_width = 300,
  bg_color = 0x1E1E1EFF,
  border_color = 0x4A4A4AFF,
  text_color = 0xFFFFFFFF,
  padding = 8,
}

-- ============================================================================
-- UNDO CONFIG
-- ============================================================================
M.UNDO = {
  max_stack_size = 50,
}

-- ============================================================================
-- ANIMATION
-- ============================================================================
M.ANIMATION = {
  tile_speed = 16.0,
}

-- ============================================================================
-- VST DISPLAY
-- ============================================================================
M.VST = {
  -- VSTs to hide from tile preview (still shown in FX chain views)
  -- These are typically utility plugins that aren't the 'main' instrument
  tile_blacklist = {
    'ReaControlMIDI',
    'ReaInsert',
  },
}

return M
