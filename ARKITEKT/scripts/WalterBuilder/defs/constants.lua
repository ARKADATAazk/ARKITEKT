-- @noindex
-- WalterBuilder/defs/constants.lua
-- Pure value constants: modes, states, dimensions, timing

local Ark = require('arkitekt')
local Lookup = require('arkitekt.core.lookup')
local hexrgb = Ark.Colors.Hexrgb

local M = {}

-- ============================================================================
-- VIEW MODES
-- ============================================================================
M.VIEW_MODES = {
  SINGLE = 'single',    -- Single track/element view
  TRACKS = 'tracks',    -- Multiple tracks stacked vertically
}

M.VIEW_MODES_REVERSE = Lookup.build_reverse(M.VIEW_MODES)

-- ============================================================================
-- CONTEXT TYPES (TCP, MCP, etc.)
-- ============================================================================
M.CONTEXTS = {
  TCP = 'tcp',      -- Track Control Panel
  MCP = 'mcp',      -- Mixer Control Panel
  ENVCP = 'envcp',  -- Envelope Control Panel
  TRANS = 'trans',  -- Transport
}

M.CONTEXTS_REVERSE = Lookup.build_reverse(M.CONTEXTS)

-- Context display names for UI
M.CONTEXT_LABELS = {
  tcp = 'TCP',
  mcp = 'MCP',
  envcp = 'EnvCP',
  trans = 'Trans',
}

-- ============================================================================
-- FOLDER STATES (REAPER track folder hierarchy)
-- ============================================================================
M.FOLDER_STATES = {
  NONE = 0,      -- Not a folder
  OPEN = 1,      -- Open folder (children visible)
  CLOSED = -1,   -- Closed folder (children hidden)
  LAST = -2,     -- Last track in folder
}

M.FOLDER_STATE_LABELS = {
  [0] = 'None',
  [1] = 'Open',
  [-1] = 'Closed',
  [-2] = 'Last',
}

-- ============================================================================
-- TRACK HEIGHT PRESETS (from rtconfig tcp_heights)
-- ============================================================================
M.TRACK_HEIGHTS = {
  SUPERCOLLAPSED = 25,
  COLLAPSED = 50,
  SMALL = 64,
  NORMAL = 90,
  LARGE = 120,
}

-- Preset definitions for UI
M.HEIGHT_PRESETS = {
  { name = 'Super', height = M.TRACK_HEIGHTS.SUPERCOLLAPSED },
  { name = 'Collapsed', height = M.TRACK_HEIGHTS.COLLAPSED },
  { name = 'Small', height = M.TRACK_HEIGHTS.SMALL },
  { name = 'Normal', height = M.TRACK_HEIGHTS.NORMAL },
  { name = 'Large', height = M.TRACK_HEIGHTS.LARGE },
}

-- ============================================================================
-- ATTACHMENT BEHAVIOR TYPES
-- ============================================================================
M.BEHAVIORS = {
  FIXED = 'fixed',              -- Element doesn't move or stretch
  MOVE = 'move',                -- Element moves but keeps size
  STRETCH_START = 'stretch_start',  -- Stretches from start edge
  STRETCH_END = 'stretch_end',      -- Stretches from end edge
}

-- ============================================================================
-- ELEMENT CATEGORIES
-- ============================================================================
M.CATEGORIES = {
  SIZE = 'size',
  BUTTON = 'button',
  FADER = 'fader',
  LABEL = 'label',
  METER = 'meter',
  INPUT = 'input',
  CONTAINER = 'container',
  OTHER = 'other',
}

-- ============================================================================
-- DIMENSIONS
-- ============================================================================
M.CANVAS = {
  MIN_PARENT_W = 150,
  MAX_PARENT_W = 800,
  MIN_PARENT_H = 60,
  MAX_PARENT_H = 600,
  DEFAULT_PARENT_W = 300,
  DEFAULT_PARENT_H = 90,
  GRID_SIZE = 10,
  HANDLE_SIZE = 8,
}

M.TRACK = {
  MIN_HEIGHT = 25,
  MAX_HEIGHT = 200,
  DEFAULT_HEIGHT = 90,
  FOLDER_INDENT = 18,
}

M.PANEL = {
  LEFT_WIDTH = 200,
  RIGHT_WIDTH = 280,
}

-- ============================================================================
-- ANIMATION / TIMING
-- ============================================================================
M.ANIMATION = {
  HOVER_SPEED = 12.0,
  FADE_SPEED = 8.0,
}

M.TIMEOUTS = {
  status_message = 4.0,
  error_message = 6.0,
}

-- ============================================================================
-- STATUS TYPES
-- ============================================================================
M.STATUS = {
  INFO = 'info',
  SUCCESS = 'success',
  WARNING = 'warning',
  ERROR = 'error',
}

M.STATUS_COLORS = {
  info = hexrgb('#CCCCCC'),
  success = hexrgb('#41E0A3'),
  warning = hexrgb('#E0B341'),
  error = hexrgb('#E04141'),
}

-- ============================================================================
-- UNDO ACTION TYPES
-- ============================================================================
M.UNDO_ACTIONS = {
  ADD_ELEMENT = 'add_element',
  REMOVE_ELEMENT = 'remove_element',
  UPDATE_ELEMENT = 'update_element',
  ADD_TRACK = 'add_track',
  REMOVE_TRACK = 'remove_track',
  UPDATE_TRACK = 'update_track',
  REORDER_TRACKS = 'reorder_tracks',
  CLEAR_ALL = 'clear_all',
  LOAD_DEFAULTS = 'load_defaults',
}

return M
