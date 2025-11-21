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

  MIN_HEIGHT = 30,
  MAX_HEIGHT = 150,
  DEFAULT_HEIGHT = 140,
  HEIGHT_STEP = 30,

  GAP = 8,
  ROUNDING = 2,
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
  -- === TILE COLOR PARAMETERS ===

  -- Base tile fill (color adjustments applied to tile background)
  base_fill = {
    -- Normal mode
    saturation_factor = 0.9,  -- Multiply saturation (0.0-1.0, lower = more desaturated)
    brightness_factor = 0.6, -- Multiply brightness (0.0-1.0, lower = darker)

    -- Compact mode (small tiles)
    compact_saturation_factor = 0.7,  -- Multiply saturation in compact mode
    compact_brightness_factor = 0.4, -- Multiply brightness in compact mode
  },

  -- Hover effect (applied to base fill)
  hover = {
    brightness_boost = 0.50,  -- Add to brightness on hover (0.0-1.0)
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

  -- Disabled state (20% opacity with colorful appearance)
  disabled = {
    desaturate = 0.3,    -- Desaturate by 30% (0.0-1.0, lower = more colorful)
    brightness = 0.65,   -- Brighten to 65% (0.0-1.0, higher = brighter/more visible)
    min_alpha = 0x33,    -- Minimum alpha/opacity (0x33 = ~20% opacity)
    fade_speed = 20.0,   -- Animation speed for fade in/out
  },

  -- Header (Normal tile mode)
  header = {
    -- Sizing
    height_ratio = 0.15,
    min_height = 22,
    rounding_offset = 2,      -- Subtract from TILE.ROUNDING for tighter corner alignment

    -- Color controls (HSV transformation from base tile color)
    saturation_factor = 0.7,  -- Multiply tile saturation by this
    brightness_factor = 1,  -- Multiply tile brightness by this
    alpha = 0xDD,             -- Base alpha/opacity (0x00-0xFF)

    -- Overlay
    text_shadow = hexrgb("#00000099"),  -- Shadow overlay color
  },

  -- Badges (unified configuration for all badge types)
  badges = {
    -- Cycle badge (index/total in header)
    cycle = {
      padding_x = 5,
      padding_y = 1,
      margin = 6,
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_darken = 0.4,  -- Darken tile color by this amount for border
      border_alpha = 0x66,
    },

    -- Pool count badge (bottom right)
    pool = {
      padding_x = 4,
      padding_y = 0,  -- Smaller vertically
      margin = 4,
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_darken = 0.4,
      border_alpha = 0x55,
    },

    -- Favorite star
    favorite = {
      size = 16,  -- Smaller star
      padding = 3,
    },
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
    saturation_multiplier = 0.0,  -- Multiply tile saturation by this (0-1)
    brightness_multiplier = 1.0,  -- Multiply tile brightness/value by this (0-1)

    -- Display appearance: Fixed HSV values (used in base renderer for display)
    saturation = 0.3,      -- Fixed saturation for waveform display
    brightness = 0.1,     -- Fixed brightness for waveform display
    line_alpha = 0.95,      -- Alpha transparency for waveform/MIDI lines
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

    hover_fill_boost = 0.16,  -- 2x increase for more noticeable hover effect
    hover_specular_boost = 1.2,  -- 2x increase for more noticeable hover effect
  },

  animation_speed_hover = 12.0,
  animation_speed_header_transition = 25.0,  -- Fast and smooth header size/fade transition between compact/normal modes

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
    small_tile_height = 50,  -- Below this height, use compact display mode
  },

  -- Small tile display mode (when tile height < responsive.small_tile_height)
  small_tile = {
    -- Behavior
    header_covers_tile = true,  -- Header extends to cover entire tile
    hide_pool_count = true,     -- Hide pool count badge in small mode
    disable_header_fill = true, -- Don't fill header background, only render text shadow

    -- Visualization
    visualization_alpha = 0.1,  -- Very low opacity for waveform/MIDI in compact mode

    -- Header color controls (HSV transformation from base tile color)
    -- Note: These only apply when disable_header_fill is false
    header_saturation_factor = 0.6,  -- Multiply tile saturation by this
    header_brightness_factor = 0.7,  -- Multiply tile brightness by this
    header_alpha = 0.0,              -- Transparency multiplier (0.0-1.0), applied to base header alpha

    -- Overlay
    header_text_shadow = hexrgb("#00000099"),  -- Shadow overlay color
  },
}

-- Region tags
M.REGION_TAGS = {
  enabled = false,  -- Toggle for showing region tags (also controls processing)

  -- Chip styling
  chip = {
    height = 16,
    padding_x = 5,
    padding_y = 2,
    margin_x = 3,         -- Spacing between chips
    margin_bottom = 4,    -- Margin from bottom of tile
    margin_left = 4,      -- Margin from left edge
    rounding = 0,         -- No rounding (square chips)
    bg_color = hexrgb("#14181C"),  -- Dark grey background (same as pool badge)
    alpha = 0xFF,         -- Fully opaque
    text_min_lightness = 0.35,  -- Minimum lightness for text (0-1), ensures readability
  },

  -- Behavior
  min_tile_height = 50,  -- Only show on tiles taller than this (not in compact mode)
  max_chips_per_tile = 3,  -- Maximum number of region chips to show per tile
}

-- UI Panels (responsive hover behavior)
M.UI_PANELS = {
  -- Search bar
  search = {
    top_padding = 18,  -- Extra padding on top for easier trigger zones
  },

  -- Settings panel (slides down from above search)
  settings = {
    max_height = 70,  -- Maximum height when fully expanded
    trigger_above_search = 10,  -- Pixels above search field before triggering
    close_below_search = 50,  -- Pixels below search before closing (larger = stays visible longer)
    slide_speed = 0.15,  -- Interpolation speed for smooth animation
  },

  -- Filter bar (slides down below search)
  filter = {
    max_height = 30,  -- Maximum height when visible
    trigger_into_panels = 10,  -- Pixels into panel area before triggering (larger = opens later)
    spacing_below_search = 8,  -- Spacing between search and filter bar
  },

  -- Panel headers (MIDI Items / Audio Items titles)
  header = {
    height = 28,  -- Used for extend_input_area to enable selection on header
    title_offset_down = 5,  -- Additional pixels to move title down from padding
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
