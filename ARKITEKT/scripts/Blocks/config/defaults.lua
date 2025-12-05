-- @noindex
-- Blocks/config/defaults.lua
-- Default values and configuration

return {
  WINDOW = {
    TITLE = 'Production Panel',
    WIDTH = 1200,
    HEIGHT = 700,
    MIN_WIDTH = 800,
    MIN_HEIGHT = 500,
  },

  MACROS = {
    COUNT = 8,
    DEFAULT_NAME = 'Macro',
    MIN_VALUE = 0.0,
    MAX_VALUE = 1.0,
    DEFAULT_VALUE = 0.0,
  },

  DRUM_RACK = {
    PADS = 16,
    ROWS = 4,
    COLS = 4,
    PAD_SIZE = 80,
    PAD_SPACING = 8,
  },

  UI = {
    SECTION_PADDING = 12,
    KNOB_SIZE = 64,
    KNOB_SPACING = 16,
    TAB_HEIGHT = 32,
  },
}
