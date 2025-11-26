-- @noindex
-- RegionPlaylist/defs/constants.lua
-- Pure value constants: colors, dimensions, timing, modes

local ColorDefs = require('arkitekt.defs.colors')
local ark = require('arkitekt')
local Unicode = require('arkitekt.core.unicode')
local Lookup = require('arkitekt.core.lookup')
local hexrgb = ark.Colors.hexrgb
local utf8 = Unicode.utf8

local M = {}

-- ============================================================================
-- ANIMATION SPEEDS
-- ============================================================================
M.ANIMATION = {
  HOVER_SPEED = 12.0,
  FADE_SPEED = 8.0,
}

-- ============================================================================
-- COLORS
-- ============================================================================

-- Semantic operation colors (move/copy/delete visual feedback)
-- Using centralized colors from framework
M.ACCENT = {
  MOVE = hexrgb(ColorDefs.OPERATIONS.move),    -- White - move operation
  COPY = hexrgb(ColorDefs.OPERATIONS.copy),    -- Teal - copy operation
  DELETE = hexrgb(ColorDefs.OPERATIONS.delete), -- Red - delete operation
}

-- Dimmed tile appearance
M.DIM = {
  FILL = hexrgb("#00000088"),
  STROKE = hexrgb("#FFFFFF33"),
}

-- Status bar colors
M.STATUS = {
  ERROR = hexrgb("#E04141"),
  WARNING = hexrgb("#E0B341"),
  INFO = hexrgb("#CCCCCC"),
  PLAYING = hexrgb("#CCCCCC"),
  READY = hexrgb("#CCCCCC"),
  IDLE = hexrgb("#888888"),
}

-- ============================================================================
-- MODE CONSTANTS
-- ============================================================================
M.POOL_MODES = {
  REGIONS = "regions",
  PLAYLISTS = "playlists",
  MIXED = "mixed",
}

-- Reverse lookup: value → key (e.g., "regions" → "REGIONS")
M.POOL_MODES_REVERSE = Lookup.build_reverse(M.POOL_MODES)

M.LAYOUT_MODES = {
  HORIZONTAL = "horizontal",
  VERTICAL = "vertical",
}

-- Reverse lookup: value → key
M.LAYOUT_MODES_REVERSE = Lookup.build_reverse(M.LAYOUT_MODES)

M.SORT_DIRECTIONS = {
  ASC = "asc",
  DESC = "desc",
}

-- Reverse lookup: value → key
M.SORT_DIRECTIONS_REVERSE = Lookup.build_reverse(M.SORT_DIRECTIONS)

-- ============================================================================
-- TIMING / TIMEOUTS
-- ============================================================================
M.TIMEOUTS = {
  circular_dependency_error = 6.0,
  state_change_notification = 4.0,
}

-- ============================================================================
-- DIMENSIONS
-- ============================================================================

-- Separator dimensions
M.SEPARATOR = {
  horizontal = {
    default_position = 180,
    min_active_height = 100,
    min_pool_height = 100,
    gap = 8,
    thickness = 6,
  },
  vertical = {
    default_position = 280,
    min_active_width = 200,
    min_pool_width = 200,
    gap = 8,
    thickness = 6,
  },
}

-- Responsive breakpoints for transport layout
M.TRANSPORT_LAYOUT = {
  ultra_compact_width = 250,
  compact_width = 400,
}

-- ============================================================================
-- TRANSPORT BUTTONS
-- ============================================================================

-- Button layout priorities (lower = more important)
M.TRANSPORT_BUTTONS = {
  play = { priority = 1, width = 34 },
  jump = { priority = 2, width = 46 },
  quantize = { priority = 3, width = 71 },  -- Reduced from 85
  playback = { priority = 4, width_dropdown = 90, width_buttons = 120 },
  loop = { priority = 5, width = 34 },
  pause = { priority = 6, width = 34 },
  stop = { priority = 7, width = 34 },
}

-- ============================================================================
-- ICONS
-- ============================================================================

-- Remix icon unicode values (UTF-8 encoding)
M.REMIX_ICONS = {
  shuffle = utf8(0xF124),
  hijack_transport = utf8(0xF3B4),
  follow_viewport = utf8(0xF301),
}

-- ============================================================================
-- QUANTIZE OPTIONS
-- ============================================================================
M.QUANTIZE_OPTIONS = {
  { value = "4bar", label = "4 Bars" },
  { value = "2bar", label = "2 Bars" },
  { value = "measure", label = "1 Bar" },
  { value = "beat", label = "Beat" },
  { value = 1, label = "1/1" },
  { value = 0.5, label = "1/2" },
  { value = 0.25, label = "1/4" },
  { value = 0.125, label = "1/8" },
  { value = 0.0625, label = "1/16" },
  { value = 0.03125, label = "1/32" },
}

-- Reverse lookups for O(1) access
M.QUANTIZE_BY_LABEL = Lookup.build_reverse_lookup(M.QUANTIZE_OPTIONS, "label", "value")
M.QUANTIZE_BY_VALUE = Lookup.build_reverse_lookup(M.QUANTIZE_OPTIONS, "value", "label")
M.QUANTIZE_INDEX = Lookup.build_index(M.QUANTIZE_OPTIONS, "value")

return M
