-- @noindex
-- TemplateBrowser/ui/ui_constants.lua
-- UI layout constants to maintain consistency

local M = {}

-- Padding values
M.PADDING = {
  PANEL = 14,           -- Main panel padding
  PANEL_INNER = 8,      -- Inner panel padding
  SMALL = 4,            -- Small spacing
  SEPARATOR_SPACING = 10, -- Spacing around separators
}

-- Button dimensions
M.BUTTON = {
  WIDTH_SMALL = 24,     -- Small square buttons (+, V, etc)
  WIDTH_MEDIUM = 120,   -- Medium buttons (Force Reparse, etc)
  WIDTH_LARGE = 250,    -- Large modal buttons

  HEIGHT_DEFAULT = 24,  -- Default button height
  HEIGHT_ACTION = 28,   -- Action buttons (Apply, Insert)
  HEIGHT_MODAL = 32,    -- Modal action buttons

  SPACING = 4,          -- Space between adjacent buttons
}

-- Separator configuration
M.SEPARATOR = {
  THICKNESS = 8,        -- Draggable separator width
  MIN_PANEL_WIDTH = 150,-- Minimum width for any panel
}

-- Header heights
M.HEADER = {
  DEFAULT = 28,         -- Standard header height
  TABS = 24,            -- Tab bar height
  SEPARATOR_TEXT = 30,  -- SeparatorText + spacing
}

-- Status bar
M.STATUS_BAR = {
  HEIGHT = 24,          -- Status bar at bottom
}

-- Tile/Grid settings
M.TILE = {
  DEFAULT_WIDTH = 180,  -- Default tile width
  GAP = 8,              -- Gap between tiles

  -- Recent templates
  RECENT_HEIGHT = 80,
  RECENT_WIDTH = 140,
  RECENT_SECTION_HEIGHT = 120,
}

-- Panel ratios (used for initial layout)
M.PANEL_RATIOS = {
  LEFT_DEFAULT = 0.20,      -- 20% for left panel
  TEMPLATE_DEFAULT = 0.55,  -- 55% for template panel
  INFO_DEFAULT = 0.25,      -- 25% for info panel (calculated)
}

-- Tag/Chip dimensions
M.CHIP = {
  HEIGHT_SMALL = 20,    -- Small chip height
  HEIGHT_DEFAULT = 24,  -- Default chip height
  HEIGHT_LARGE = 28,    -- Large chip height (VSTs)

  DOT_SIZE = 8,         -- VST chip dot size
  DOT_SPACING = 10,     -- VST chip dot spacing
}

-- Color picker
M.COLOR_PICKER = {
  GRID_COLS = 4,        -- Color grid columns
  CHIP_SIZE = 20,       -- Color chip size
}

-- Input fields
M.FIELD = {
  RENAME_WIDTH = 300,   -- Rename modal input width
  RENAME_HEIGHT = 24,   -- Rename input height

  NOTES_HEIGHT = 200,   -- Notes/Markdown field height
}

-- Modal dimensions
M.MODAL = {
  CONFLICT_WIDTH = 250, -- Conflict modal button width
}

return M
