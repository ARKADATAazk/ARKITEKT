-- @noindex
-- ItemPicker/defs/constants.lua
-- Centralized constants and configuration values
--
-- THEME INTEGRATION:
-- Colors now derive from Theme.COLORS (the same source used by titlebar context menu).
-- This ensures ItemPicker respects the persisted theme mode.

local Ark = require('arkitekt')
local M = {}

-- Lazy load Theme to avoid circular dependency issues
local _Theme
local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

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
-- COLORS (Theme-derived)
-- =============================================================================
-- Uses Theme.COLORS directly - same source as titlebar context menu theme picker.

-- Cache for computed colors
local _colors_cache = nil
local _cache_t = nil

--- Check if we're in light theme mode
local function is_light_theme()
  local Theme = get_theme()
  return Theme and Theme.get_t and Theme.get_t() > 0.5 or false
end

--- Get theme-derived colors (computed on demand)
--- @return table Colors table with theme-reactive values
function M.get_colors()
  local Theme = get_theme()
  local ThemeColors = Theme and Theme.COLORS or {}

  -- Get current t value for cache invalidation
  local current_t = Theme and Theme.get_t and Theme.get_t() or 0

  -- Return cache if t hasn't changed
  if _colors_cache and _cache_t == current_t then
    return _colors_cache
  end

  local is_light = is_light_theme()

  -- Build colors table using Theme.COLORS with fallbacks
  _colors_cache = {
    -- Hover overlay - invert for light theme
    HOVER_OVERLAY = is_light and 0x00000020 or 0xFFFFFF20,
    TEXT_SHADOW = is_light and 0xFFFFFF30 or 0x00000050,

    -- Default track color (when track has no color)
    DEFAULT_TRACK_COLOR = {85/256, 91/256, 91/256},

    -- Status bar colors
    LOADING = 0x4A9EFFFF,  -- Blue loading indicator (consistent)
    HINT = ThemeColors.TEXT_DIMMED or 0x888888FF,

    -- Panel colors (from Theme.COLORS)
    PANEL_BACKGROUND = ThemeColors.BG_CHROME or 0x0F0F0FFF,
    PANEL_BORDER = ThemeColors.BG_PANEL or 0x1A1A1AFF,
    PATTERN = ThemeColors.PATTERN_PRIMARY or 0x2A2A2AFF,

    -- Text colors
    MUTED_TEXT = 0xCC2222FF,  -- Red for muted (consistent)
    PRIMARY_TEXT = ThemeColors.TEXT_NORMAL or 0xFFFFFFFF,

    -- Backdrop/badge colors
    BADGE_BG = is_light and 0xE8ECF0FF or 0x14181CFF,
    DISABLED_BACKDROP = ThemeColors.BG_PANEL or 0x1A1A1AFF,

    -- Drag handler
    DEFAULT_DRAG_COLOR = 0x42E896FF,  -- Teal (consistent)

    -- Fallback track color
    FALLBACK_TRACK = 0x4A5A6AFF,

    -- Section header text color
    SECTION_HEADER_TEXT = ThemeColors.TEXT_NORMAL or 0xFFFFFFFF,
  }

  _cache_t = current_t
  return _colors_cache
end

--- Refresh colors cache (call when theme changes)
function M.refresh_colors()
  _colors_cache = nil
  _cache_t = nil
end

-- Legacy static access (uses cached theme colors)
M.COLORS = setmetatable({}, {
  __index = function(_, key)
    return M.get_colors()[key]
  end,
  __pairs = function(_)
    return pairs(M.get_colors())
  end,
})

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
-- Most values are static. Theme-reactive values use Theme.COLORS.

--- Get tile render config
--- @return table TILE_RENDER config
function M.get_tile_render()
  local Theme = get_theme()
  local ThemeColors = Theme and Theme.COLORS or {}
  local is_light = is_light_theme()

  return {
    -- Base tile fill
    base_fill = {
      saturation_factor = 0.9,
      brightness_factor = 0.6,
      compact_saturation_factor = 0.7,
      compact_brightness_factor = 0.4,
    },

    -- Hover effect
    hover = {
      brightness_boost = 0.20,
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
      border_saturation = 1.0,
      border_brightness = 3.5,
      ants_alpha = 0xFF,
      ants_thickness = 1,
      ants_inset = 0,
      ants_dash = 60,
      ants_gap = 35,
      ants_speed = 30,
      tile_brightness_boost = 0.35,
      -- Pulsing glow effect
      pulse_speed = 1.0,           -- Oscillations per second
      pulse_brightness_min = 0.15, -- Minimum brightness boost
      pulse_brightness_max = 0.30, -- Maximum brightness boost
    },

    -- Disabled state
    disabled = {
      desaturate = 0.10,
      brightness = 0.60,
      min_alpha = 0x44,
      fade_speed = 20.0,
      backdrop_color = ThemeColors.BG_PANEL or 0x1A1A1AFF,
      backdrop_alpha = 0x88,
    },

    -- Muted state
    muted = {
      text_color = 0xCC2222FF,
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
      text_shadow = is_light and 0xFFFFFF40 or 0x00000099,
    },

    -- Badges (use theme-derived badge colors)
    badges = {
      cycle = {
        padding_x = 5,
        padding_y = 0,
        margin = 4,
        rounding = 3,
        bg = is_light and 0xE8ECF0FF or 0x14181CFF,
        border_darken = 0.4,
        border_alpha = 0x66,
      },
      pool = {
        padding_x = 4,
        padding_y = 0,
        margin = 4,
        rounding = 3,
        bg = is_light and 0xE8ECF0FF or 0x14181CFF,
        border_darken = 0.4,
        border_alpha = 0x55,
      },
      favorite = {
        icon_size = 14,
        margin = 4,
        spacing = 4,
        rounding = 3,
        bg = is_light and 0xE8ECF0FF or 0x14181CFF,
        border_darken = 0.4,
        border_alpha = 0x66,
      },
    },

    -- Text
    text = {
      primary_color = ThemeColors.TEXT_NORMAL or 0xFFFFFFFF,
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
      ants_dash = 24,
      ants_gap = 11,
      ants_speed = 30,
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
      y_offset = 50,  -- Tiles rise from further below
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
      header_text_shadow = is_light and 0xFFFFFF40 or 0x00000099,
    },
  }
end

-- Cache for tile render config
local _tile_render_cache = nil
local _tile_render_cache_t = nil

-- Legacy static access (uses cached theme config)
M.TILE_RENDER = setmetatable({}, {
  __index = function(_, key)
    local Theme = get_theme()
    local current_t = Theme and Theme.get_t and Theme.get_t() or 0
    if not _tile_render_cache or _tile_render_cache_t ~= current_t then
      _tile_render_cache = M.get_tile_render()
      _tile_render_cache_t = current_t
    end
    return _tile_render_cache[key]
  end,
  __pairs = function(_)
    local Theme = get_theme()
    local current_t = Theme and Theme.get_t and Theme.get_t() or 0
    if not _tile_render_cache or _tile_render_cache_t ~= current_t then
      _tile_render_cache = M.get_tile_render()
      _tile_render_cache_t = current_t
    end
    return pairs(_tile_render_cache)
  end,
})

-- =============================================================================
-- REGION TAGS
-- =============================================================================

--- Get region tags config
function M.get_region_tags()
  local is_light = is_light_theme()

  return {
    enabled = false,

    chip = {
      height = 16,
      padding_x = 5,
      padding_y = 2,
      margin_x = 3,
      margin_bottom = 4,
      margin_left = 4,
      rounding = 0,
      bg_color = is_light and 0xE8ECF0FF or 0x14181CFF,
      alpha = 0xFF,
      text_min_lightness = 0.35,
    },

    min_tile_height = 50,
    max_chips_per_tile = 3,
  }
end

-- Cache for region tags config
local _region_tags_cache = nil
local _region_tags_cache_t = nil

M.REGION_TAGS = setmetatable({}, {
  __index = function(_, key)
    local Theme = get_theme()
    local current_t = Theme and Theme.get_t and Theme.get_t() or 0
    if not _region_tags_cache or _region_tags_cache_t ~= current_t then
      _region_tags_cache = M.get_region_tags()
      _region_tags_cache_t = current_t
    end
    return _region_tags_cache[key]
  end,
  __pairs = function(_)
    local Theme = get_theme()
    local current_t = Theme and Theme.get_t and Theme.get_t() or 0
    if not _region_tags_cache or _region_tags_cache_t ~= current_t then
      _region_tags_cache = M.get_region_tags()
      _region_tags_cache_t = current_t
    end
    return pairs(_region_tags_cache)
  end,
})

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
    max_height = 200,
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
-- TRACK FILTER MODAL
-- =============================================================================

M.TRACK_FILTER = {
  -- Track tile sizing
  tile_height = 18,
  indent = 16,

  -- Alpha values
  alpha_selected = 0xCC,
  alpha_hovered = 0x66,
  alpha_default = 0x33,
  bar_alpha_selected = 0xFF,
  bar_alpha_default = 0x88,
  arrow_alpha = 0x88,
  text_alpha_unselected = 0xAA,

  -- Layout
  arrow_size = 6,
  text_offset_after_arrow = 10,
  indicator_size = 6,
  arrow_hover_width = 12,

  -- Modal dimensions
  modal_padding = 16,
  modal_width = 320,
  modal_top_offset = 80,
  max_content_ratio = 0.6,

  -- Slider
  slider_area_height = 32,
  slider_handle_height = 20,
  slider_spacing_right = 30,

  -- Scrolling
  scroll_pixels_per_tick = 40,

  -- Tooltip
  tooltip_x_offset = 12,
  tooltip_y_offset = 18,
  tooltip_bg = 0x1A1A1AFF,
  tooltip_border = 0x505050FF,
  tooltip_text = 0xCCCCCCFF,

  -- Button
  button_height = 28,

  -- Default track color
  default_track_color = 0x555B5BFF,
}

-- =============================================================================
-- CONTENT PANELS (Audio/MIDI split view)
-- =============================================================================

M.CONTENT_PANELS = {
  -- Padding and rounding
  padding = 4,
  rounding = 6,

  -- Title font sizes
  midi_title_size = 14,
  audio_title_size = 15,

  -- Opacity
  background_opacity = 0.6,
  border_opacity = 0.67,

  -- Horizontal layout minimums
  min_midi_width_h = 200,
  min_audio_width_h = 300,
  default_midi_width_h = 400,

  -- Resize constraints
  min_midi_width_resize = 100,
  min_audio_width_resize = 150,
  min_midi_height_resize = 50,
  min_audio_height_resize = 50,
}

-- =============================================================================
-- VISUALIZATION
-- =============================================================================

M.VISUALIZATION = {
  WAVEFORM_RESOLUTION = 2000,
  MIDI_CACHE_WIDTH = 400,
  MIDI_CACHE_HEIGHT = 200,

  -- Waveform rendering
  waveform_height_ratio = 0.95,

  -- MIDI rendering
  midi_min_range = 10,           -- Minimum note range for display
  midi_min_note_width = 1.0,     -- Minimum note width in pixels
  midi_min_note_height = 1.0,    -- Minimum note height in pixels
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

  -- Guide crosshairs
  crosshair_thickness = 2,
  crosshair_color = 0x808080FF,
  window_height_offset = 17,

  -- Preview visualization HSV adjustments
  viz_saturation = 0.3,
  viz_brightness = 0.15,

  -- Fallback colors
  fallback_grey = 0xB1B4B4CC,
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
  jobs_per_frame_max = 8,        -- Max jobs/frame after load ramp-up
  batch_size = 100,
  items_per_chunk = 200,         -- Items processed per frame during chunked load
  deferred_load_delay = 0.5,     -- Seconds before deferred load (pool counts, regions)
}

-- =============================================================================
-- ANIMATION
-- =============================================================================

M.ANIMATION = {
  fade_in_duration = 0.25,       -- Return-from-drag fade duration (seconds)
  job_ramp_up_duration = 2.0,    -- Time to ramp up job processing after load
  delta_time = 0.016,            -- Animation update delta (~60fps)
  spawn_duration_override = 0.4, -- Grid spawn animation override
}

-- =============================================================================
-- AUTO RELOAD
-- =============================================================================

M.AUTO_RELOAD = {
  check_interval_frames = 60,    -- Check every ~1 second at 60fps
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
  -- UI fade animation
  ui_fade_start = 0.15,
  ui_fade_end = 0.85,
  ui_y_offset_max = 15,          -- Y offset during fade animation

  -- Search fade animation
  search_fade_start = 0.05,
  search_fade_end = 0.95,
  search_y_offset_max = 25,      -- Y offset during search fade
  search_height = 28,            -- Search bar height

  -- Checkboxes
  checkbox_padding = 14,
  checkbox_spacing = 20,

  -- Settings panel
  settings_offset = 11,          -- Offset from search bar
  settings_retract_delay = 1.5,  -- Seconds before auto-retract

  -- Trigger zones
  trigger_extension_down = 100,  -- Extension below trigger zone

  -- Background pattern
  pattern_spacing = 16,
  pattern_dot_size = 1.5,
  pattern_overlay_alpha = 180,   -- 0-255
}

-- =============================================================================
-- BASE RENDERER
-- =============================================================================

M.RENDERER = {
  easing_c1 = 1.70158,
  cascade_grid_cell = 150,
  placeholder_rotation_period = 2.0,
  arc_length = math.pi * 1.5,
  char_width_estimate = 12,      -- Characters for text width estimation
}

-- =============================================================================
-- PROFILER
-- =============================================================================

M.PROFILER = {
  report_interval_seconds = 1.0,
  enabled = false,               -- Set to true to enable profiling output
}

-- =============================================================================
-- VALIDATION
-- =============================================================================

function M.validate()
  assert(M.TILE.MIN_WIDTH <= M.TILE.DEFAULT_WIDTH, 'MIN_WIDTH must be <= DEFAULT_WIDTH')
  assert(M.TILE.DEFAULT_WIDTH <= M.TILE.MAX_WIDTH, 'DEFAULT_WIDTH must be <= MAX_WIDTH')
  assert(M.TILE.MIN_HEIGHT <= M.TILE.DEFAULT_HEIGHT, 'MIN_HEIGHT must be <= DEFAULT_HEIGHT')
  assert(M.TILE.DEFAULT_HEIGHT <= M.TILE.MAX_HEIGHT, 'DEFAULT_HEIGHT must be <= MAX_HEIGHT')
  assert(M.LAYOUT.MIDI_SECTION_RATIO + M.LAYOUT.AUDIO_SECTION_RATIO <= 1.0, 'Section ratios must sum to <= 1.0')
end

M.validate()

return M
