-- @noindex
-- ItemPicker/core/config.lua
-- Centralized configuration

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Tile sizing
M.TILE = {
  MIN_WIDTH = 80,
  MAX_WIDTH = 300,
  DEFAULT_WIDTH = 120,
  WIDTH_STEP = 30,

  MIN_HEIGHT = 60,
  MAX_HEIGHT = 400,
  DEFAULT_HEIGHT = 140,
  HEIGHT_STEP = 30,

  GAP = 8,
  ROUNDING = 0,
}

-- Layout
M.LAYOUT = {
  MIDI_SECTION_RATIO = 0.35,
  AUDIO_SECTION_RATIO = 0.65,

  CONTENT_START_Y = 0.15,
  CONTENT_HEIGHT = 0.8,

  SECTION_SPACING = 60,
  HEADER_HEIGHT = 30,
  PADDING = 10,

  SEARCH_WIDTH_RATIO = 0.2,
}

-- Separator (draggable divider between MIDI and Audio sections)
M.SEPARATOR = {
  thickness = 20,
  gap = 8,
  min_midi_height = 100,
  min_audio_height = 150,
  default_midi_height = 300,  -- Will be used on first load or double-click reset
}

-- Cache
M.CACHE = {
  MAX_ENTRIES = 200,
}

-- Colors
M.COLORS = {
  HOVER_OVERLAY = hexrgb("#FFFFFF20"),
  TEXT_SHADOW = hexrgb("#00000050"),
  DEFAULT_TRACK_COLOR = {85/256, 91/256, 91/256},
}

-- Grid animations
M.GRID = {
  ANIMATION_ENABLED = true,
  SPAWN_DURATION = 0.28,
  DESTROY_DURATION = 0.10,
}

-- Tile rendering config
M.TILE_RENDER = {
  -- Disabled state
  disabled = {
    desaturate = 0.8,
    brightness = 0.4,
    min_alpha = 0x33,
    fade_speed = 20.0,
  },

  -- Header
  header = {
    height_ratio = 0.15,
    min_height = 22,
    saturation_factor = 1.1,
    brightness_factor = 0.7,
    alpha = 0xDD,
    text_shadow = hexrgb("#00000099"),
  },

  -- Badge
  badge = {
    padding_x = 6,
    padding_y = -1,  -- Reduced by 4 per side (8 pixels total height reduction from original)
    margin = 6,
    rounding = 4,
    bg = hexrgb("#14181C"),
    border_alpha = 0x33,
  },

  -- Text
  text = {
    primary_color = hexrgb("#FFFFFF"),
    padding_left = 6,
    padding_top = 4,
    margin_right = 6,
  },

  -- Waveform & MIDI Visualization Colors
  waveform = {
    -- Color computation: HSV transformation from base tile color
    -- These multipliers are applied to derive visualization colors (used in visualization.lua)
    saturation_multiplier = 0.64,  -- Multiply tile saturation by this (0-1)
    brightness_multiplier = 0.35,  -- Multiply tile brightness/value by this (0-1)

    -- Display appearance: Fixed HSV values (used in base renderer for display)
    saturation = 0.3,      -- Fixed saturation for waveform display
    brightness = 0.15,     -- Fixed brightness for waveform display
    line_alpha = 0.8,      -- Alpha transparency for waveform/MIDI lines
    zero_line_alpha = 0.3, -- Alpha transparency for zero line
  },

  -- Tile FX
  tile_fx = {
    fill_opacity = 0.65,
    fill_saturation = 0.75,
    fill_brightness = 0.6,

    border_opacity = 0.0,
    border_saturation = 0.8,
    border_brightness = 1.4,
    border_thickness = 1.0,

    gradient_intensity = 0.2,
    gradient_opacity = 0.08,

    specular_strength = 0.12,
    specular_coverage = 0.25,

    inner_shadow_strength = 0.25,

    ants_enabled = true,
    ants_replace_border = false,
    ants_thickness = 1,
    ants_dash = 8,
    ants_gap = 6,
    ants_speed = 20,
    ants_inset = 0,
    ants_alpha = 0xFF,

    glow_strength = 0.4,
    glow_layers = 3,

    hover_fill_boost = 0.08,
    hover_specular_boost = 0.6,
  },

  animation_speed_hover = 12.0,

  -- Cascade animation
  cascade = {
    stagger_delay = 0.03,
    scale_from = 0.85,
    y_offset = 20,
    rotation_degrees = 3,
  },

  -- Responsive
  responsive = {
    hide_text_below = 35,
    hide_badge_below = 25,
  },
}

function M.validate()
  assert(M.TILE.MIN_WIDTH <= M.TILE.DEFAULT_WIDTH, "MIN_WIDTH must be <= DEFAULT_WIDTH")
  assert(M.TILE.DEFAULT_WIDTH <= M.TILE.MAX_WIDTH, "DEFAULT_WIDTH must be <= MAX_WIDTH")
  assert(M.TILE.MIN_HEIGHT <= M.TILE.DEFAULT_HEIGHT, "MIN_HEIGHT must be <= DEFAULT_HEIGHT")
  assert(M.TILE.DEFAULT_HEIGHT <= M.TILE.MAX_HEIGHT, "DEFAULT_HEIGHT must be <= MAX_HEIGHT")
  assert(M.LAYOUT.MIDI_SECTION_RATIO + M.LAYOUT.AUDIO_SECTION_RATIO <= 1.0, "Section ratios must sum to <= 1.0")
end

M.validate()

return M
