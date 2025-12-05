-- @noindex
-- ItemPicker/defs/defaults.lua
-- Default settings and mode options

local Lookup = require('arkitekt.core.lookup')

local M = {}

-- =============================================================================
-- SETTINGS DEFAULTS
-- =============================================================================

M.SETTINGS = {
  play_item_through_track = false,
  show_muted_tracks = false,
  show_muted_items = false,
  show_disabled_items = false,
  show_favorites_only = false,
  show_audio = true,
  show_midi = true,
  split_midi_by_track = false,
  group_items_by_name = true,
  focus_keyboard_on_init = true,
  search_string = '',
  tile_width = nil,
  tile_height = nil,
  separator_position = nil,
  separator_position_horizontal = nil,
  sort_mode = 'none',
  sort_reverse = false,
  waveform_quality = 0.2,
  show_duration = true,
  enable_tile_fx = true,
  layout_mode = 'vertical',
  show_region_tags = false,
  region_filter_mode = 'or',  -- 'or' = any match, 'and' = all must match
  auto_preview_on_hover = false,
  auto_preview_delay = 0.3,  -- seconds before preview starts
}

-- =============================================================================
-- MODE OPTIONS
-- =============================================================================

-- Sort modes
M.SORT_MODES = {
  'none',
  'recent',
  'color',
  'name',
  'pool',
  'length',
}

-- Layout modes
M.LAYOUT_MODES = {
  'vertical',
  'horizontal',
}

-- View modes
M.VIEW_MODES = {
  'MIXED',
  'MIDI',
  'AUDIO',
}

-- Search modes
M.SEARCH_MODES = {
  {value = 'items', label = 'Items'},
  {value = 'tracks', label = 'Tracks'},
  {value = 'regions', label = 'Regions'},
  {value = 'mixed', label = 'Mixed'},
}

-- Reverse lookups for O(1) access
M.SEARCH_MODE_BY_LABEL = Lookup.build_reverse_lookup(M.SEARCH_MODES, 'label', 'value')
M.SEARCH_MODE_BY_VALUE = Lookup.build_reverse_lookup(M.SEARCH_MODES, 'value', 'label')
M.SEARCH_MODE_INDEX = Lookup.build_index(M.SEARCH_MODES, 'value')

-- =============================================================================
-- ANIMATION DEFAULTS
-- =============================================================================

M.ANIMATION = {
  -- Spinner animation speed (frames * multiplier)
  spinner_speed = 8,
}

-- =============================================================================
-- TOOLTIP DEFAULTS
-- =============================================================================

M.TOOLTIP = {
  wrap_width = 300,
  delay_normal = true,
}

return M
