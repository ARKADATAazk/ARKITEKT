-- @noindex
-- ItemPicker/defs/constants.lua
-- Centralized constants and configuration values

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- =============================================================================
-- TILE CONFIGURATION
-- =============================================================================

M.TILE = {
  MIN_WIDTH = 80,
  MAX_WIDTH = 300,
  DEFAULT_WIDTH = 120,
  WIDTH_STEP = 30,

  MIN_HEIGHT = 30,
  MAX_HEIGHT = 150,
  DEFAULT_HEIGHT = 140,
  HEIGHT_STEP = 30,

  GAP = 8,
  ROUNDING = 2,
}

-- =============================================================================
-- LAYOUT CONFIGURATION
-- =============================================================================

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

-- =============================================================================
-- SEPARATOR (draggable divider between MIDI and Audio sections)
-- =============================================================================

M.SEPARATOR = {
  thickness = 20,
  gap = 8,
  min_midi_height = 100,
  min_audio_height = 150,
  default_midi_height = 300,
}

-- =============================================================================
-- CACHE
-- =============================================================================

M.CACHE = {
  MAX_ENTRIES = 200,
}

-- =============================================================================
-- COLORS
-- =============================================================================

M.COLORS = {
  HOVER_OVERLAY = hexrgb("#FFFFFF20"),
  TEXT_SHADOW = hexrgb("#00000050"),
  DEFAULT_TRACK_COLOR = {85/256, 91/256, 91/256},

  -- Status bar colors
  LOADING = hexrgb("#4A9EFF"),
  HINT = hexrgb("#888888"),

  -- Panel colors
  PANEL_BACKGROUND = hexrgb("#0F0F0F"),
  PANEL_BORDER = hexrgb("#1A1A1A"),
  PATTERN = hexrgb("#2A2A2A"),

  -- Text colors
  MUTED_TEXT = hexrgb("#CC2222"),
  PRIMARY_TEXT = hexrgb("#FFFFFF"),

  -- Backdrop/badge colors
  BADGE_BG = hexrgb("#14181C"),
  DISABLED_BACKDROP = hexrgb("#1A1A1A"),

  -- Drag handler
  DEFAULT_DRAG_COLOR = hexrgb("#42E896FF"),

  -- Fallback
  FALLBACK_TRACK = 0x4A5A6AFF,
}

-- =============================================================================
-- GRID ANIMATIONS
-- =============================================================================

M.GRID = {
  ANIMATION_ENABLED = true,
  SPAWN_DURATION = 0.28,
  DESTROY_DURATION = 0.10,
}

-- =============================================================================
-- TILE RENDERING
-- =============================================================================

M.TILE_RENDER = {
  -- Base tile fill
  base_fill = {
    saturation_factor = 0.9,
    brightness_factor = 0.6,
    compact_saturation_factor = 0.7,
    compact_brightness_factor = 0.4,
  },

  -- Hover effect
  hover = {
    brightness_boost = 0.50,
  },

  -- Minimum lightness
  min_lightness = 0.20,

  -- Duration text
  duration_text = {
    margin_x = 4,
    margin_y = 3,
    dark_tile_threshold = 0.80,
    light_saturation = 0.2,
    light_value = 4.2,
    dark_saturation = 0.4,
    dark_value = 0.18,
  },

  -- Selection (marching ants)
  selection = {
    border_saturation = 0.8,
    border_brightness = 1.4,
    ants_alpha = 0xFF,
    ants_thickness = 1,
    ants_inset = 0,
    ants_dash = 8,
    ants_gap = 6,
    ants_speed = 20,
  },

  -- Disabled state
  disabled = {
    desaturate = 0.15,
    brightness = 0.65,
    min_alpha = 0x33,
    fade_speed = 20.0,
    backdrop_color = hexrgb("#1A1A1A"),
    backdrop_alpha = 0xCC,
  },

  -- Muted state
  muted = {
    text_color = hexrgb("#CC2222"),
    desaturate = 0.25,
    brightness = 0.70,
    alpha_factor = 0.85,
    fade_speed = 20.0,
  },

  -- Header
  header = {
    height_ratio = 0.15,
    min_height = 21,
    rounding_offset = 2,
    saturation_factor = 0.7,
    brightness_factor = 1,
    alpha = 0xDD,
    text_shadow = hexrgb("#00000099"),
  },

  -- Badges
  badges = {
    cycle = {
      padding_x = 5,
      padding_y = 0,
      margin = 4,
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_darken = 0.4,
      border_alpha = 0x66,
    },
    pool = {
      padding_x = 4,
      padding_y = 0,
      margin = 4,
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_darken = 0.4,
      border_alpha = 0x55,
    },
    favorite = {
      icon_size = 14,
      margin = 4,
      spacing = 4,
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_darken = 0.4,
      border_alpha = 0x66,
    },
  },

  -- Text
  text = {
    primary_color = hexrgb("#FFFFFF"),
    padding_left = 4,
    padding_top = 3,
    margin_right = 6,
  },

  -- Waveform & MIDI
  waveform = {
    saturation_multiplier = 0.0,
    brightness_multiplier = 1.0,
    saturation = 0.3,
    brightness = 0.1,
    line_alpha = 0.95,
    zero_line_alpha = 0.3,
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
    hover_fill_boost = 0.16,
    hover_specular_boost = 1.2,
  },

  -- Animation speeds
  animation_speed_hover = 12.0,
  animation_speed_header_transition = 25.0,

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
    small_tile_height = 50,
  },

  -- Small tile display
  small_tile = {
    header_covers_tile = true,
    hide_pool_count = true,
    disable_header_fill = true,
    visualization_alpha = 0.1,
    header_saturation_factor = 0.6,
    header_brightness_factor = 0.7,
    header_alpha = 0.0,
    header_text_shadow = hexrgb("#00000099"),
  },
}

-- =============================================================================
-- REGION TAGS
-- =============================================================================

M.REGION_TAGS = {
  enabled = false,

  chip = {
    height = 16,
    padding_x = 5,
    padding_y = 2,
    margin_x = 3,
    margin_bottom = 4,
    margin_left = 4,
    rounding = 0,
    bg_color = hexrgb("#14181C"),
    alpha = 0xFF,
    text_min_lightness = 0.35,
  },

  min_tile_height = 50,
  max_chips_per_tile = 3,
}

-- =============================================================================
-- UI PANELS
-- =============================================================================

M.UI_PANELS = {
  search = {
    top_padding = 18,
  },

  settings = {
    max_height = 70,
    trigger_above_search = 10,
    close_below_search = 50,
    slide_speed = 0.15,
  },

  filter = {
    max_height = 200,  -- Increased to support many lines of region chips with long names
    trigger_into_panels = 10,
    spacing_below_search = 8,
  },

  header = {
    height = 28,
    title_offset_down = 5,
    fade_on_scroll = true,
    fade_scroll_threshold = 10,
    fade_scroll_distance = 30,
  },
}

-- =============================================================================
-- VISUALIZATION
-- =============================================================================

M.VISUALIZATION = {
  WAVEFORM_RESOLUTION = 2000,
  MIDI_CACHE_WIDTH = 400,
  MIDI_CACHE_HEIGHT = 200,
}

-- =============================================================================
-- DRAG HANDLER
-- =============================================================================

M.DRAG = {
  stacking_offset = 8,
  max_stacked_items = 4,
  opacity_levels = {0.85, 0.70, 0.50, 0.35},
  opacity_levels_alt = {1.0, 0.75, 0.55, 0.40},
  shadow_layers = 5,
  preview_desaturate = 0.3,
  preview_brightness = 0.7,
}

-- =============================================================================
-- COORDINATOR / ANIMATOR
-- =============================================================================

M.ANIMATOR = {
  speed = 12.0,
}

-- =============================================================================
-- MAIN WINDOW / LOADING
-- =============================================================================

M.LOADING = {
  jobs_per_frame_loading = 20,
  jobs_per_frame_normal = 5,
  batch_size = 100,
}

-- =============================================================================
-- SEARCH
-- =============================================================================

M.SEARCH = {
  dropdown_width = 85,
  overlap = -1,
}

-- =============================================================================
-- REGION FILTER BAR
-- =============================================================================

M.CHIP = {
  alpha_full = 0xFF,
  alpha_unselected = 0x66,
  alpha_hovered = 0x99,
}

-- =============================================================================
-- LAYOUT VIEW
-- =============================================================================

M.LAYOUT_VIEW = {
  ui_fade_start = 0.15,
  ui_fade_end = 0.85,
  search_fade_start = 0.05,
  search_fade_end = 0.95,
  checkbox_padding = 14,
  checkbox_spacing = 20,
}

-- =============================================================================
-- BASE RENDERER
-- =============================================================================

M.RENDERER = {
  easing_c1 = 1.70158,
  cascade_grid_cell = 150,
  placeholder_rotation_period = 2.0,
  arc_length = math.pi * 1.5,
}

-- =============================================================================
-- VALIDATION
-- =============================================================================

function M.validate()
  assert(M.TILE.MIN_WIDTH <= M.TILE.DEFAULT_WIDTH, "MIN_WIDTH must be <= DEFAULT_WIDTH")
  assert(M.TILE.DEFAULT_WIDTH <= M.TILE.MAX_WIDTH, "DEFAULT_WIDTH must be <= MAX_WIDTH")
  assert(M.TILE.MIN_HEIGHT <= M.TILE.DEFAULT_HEIGHT, "MIN_HEIGHT must be <= DEFAULT_HEIGHT")
  assert(M.TILE.DEFAULT_HEIGHT <= M.TILE.MAX_HEIGHT, "DEFAULT_HEIGHT must be <= MAX_HEIGHT")
  assert(M.LAYOUT.MIDI_SECTION_RATIO + M.LAYOUT.AUDIO_SECTION_RATIO <= 1.0, "Section ratios must sum to <= 1.0")
end

M.validate()

return M
