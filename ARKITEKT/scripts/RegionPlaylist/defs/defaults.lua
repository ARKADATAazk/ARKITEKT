-- @noindex
-- RegionPlaylist/defs/defaults.lua
-- Default configuration values

local ColorDefs = require('arkitekt.defs.colors')
local Ark = require('arkitekt')
local Constants = require('RegionPlaylist.defs.constants')
local hexrgb = Ark.Colors.Hexrgb

-- Helper for glow colors
local function glow_color(base_hex, alpha)
  return hexrgb(base_hex:sub(1, 7) .. alpha)
end

local M = {}

-- ============================================================================
-- QUANTIZE DEFAULTS
-- ============================================================================
M.QUANTIZE = {
  default_mode = 'measure',
  default_lookahead = 0.30,
  min_lookahead = 0.20,
  max_lookahead = 1.0,
}

-- ============================================================================
-- TRANSPORT DEFAULTS
-- ============================================================================
M.TRANSPORT = {
  height = 72,
  padding = 12,
  spacing = 12,
  -- panel_bg_color: Transparent - Transport uses TransportFX for dynamic themed background
  panel_bg_color = hexrgb('#00000000'),

  corner_buttons = {
    size = 30,
    margin = 8,
    inner_rounding = 7,
  },

  -- display: All colors now use nil to fall back to dynamic Style.COLORS
  -- This enables proper theme reactivity (light/dark themes)
  display = {
    -- bg_color: nil falls back to Style.COLORS.BG_PANEL
    -- border_inner: nil falls back to Style.COLORS.BORDER_INNER
    -- border_outer: nil falls back to Style.COLORS.BORDER_OUTER
    rounding = 6,
    -- time_color: nil falls back to Style.COLORS.TEXT_NORMAL
    -- time_playing_color: nil falls back to Style.COLORS.TEXT_BRIGHT
    -- status_color: nil falls back to Style.COLORS.TEXT_DIM
    -- region_color: nil falls back to Style.COLORS.TEXT_NORMAL
    -- track_color: nil falls back to Style.COLORS.BG_HOVER
    fill_color = hexrgb('#41E0A3'),  -- Accent color (keep explicit)
    progress_height = 3,
  },

  fx = {
    rounding = 8,
    specular = { height = 40, strength = 0.02 },
    inner_glow = { size = 20, strength = 0.08 },
    border = { thickness = 1 },  -- color: Uses Style.COLORS.BORDER_OUTER dynamically
    hover = { specular_boost = 1.5, glow_boost = 1.3, transition_speed = 6.0 },
    gradient = {
      fade_speed = 8.0,
      -- ready_color: Uses Style.COLORS.BG_PANEL dynamically for theme reactivity
      fill_opacity = 0.3,
      fill_saturation = 0.8,
      fill_brightness = 0.8,
    },
    jump_flash = {
      fade_speed = 3.0,
      max_opacity = 0.85,
    },
    progress = { height = 3 },  -- track_color: Uses Style.COLORS.BG_PANEL dynamically
  },

  -- background_pattern: Colors nil to fall back to dynamic Style.COLORS.PATTERN_*
  -- This enables theme reactivity for the dot/grid patterns
  background_pattern = {
    primary = { type = 'dots', spacing = 50, dot_size = 2.5 },  -- color: Style.COLORS.PATTERN_PRIMARY
    secondary = { enabled = true, type = 'dots', spacing = 5, dot_size = 1.5 },  -- color: Style.COLORS.PATTERN_SECONDARY
  },

  jump = {
    height = 28,
  },
}

-- ============================================================================
-- CONTAINER DEFAULTS
-- ============================================================================
M.CONTAINER = {
  active = {
    header_height = 23,
    corner_button_size = 24,
    corner_button_margin = 8,
    corner_button_inner_rounding = 12,
    tab = {
      spacing = 0,
      min_width = 60,
      max_width = 150,
      padding_x = 8,
      chip_radius = 4,
    },
  },
  pool = {
    header_height = 30,
    corner_button_size = 24,
    corner_button_margin = 8,
    corner_button_inner_rounding = 12,
    mode_toggle_width = 100,
    search_width = 200,
    sort_width = 136,  -- Increased from 120 to fit 'Alphabetical'
  },
}

-- ============================================================================
-- REGION TILES DEFAULTS
-- ============================================================================
M.REGION_TILES = {
  tile = {
    border_thickness = 0.5,
    rounding = 6,
  },

  container = {
    border_thickness = 1,
    rounding = 8,
    padding = 8,
    scroll = {
      flags = 0,
      custom_scrollbar = false,
    },
    anti_jitter = {
      enabled = true,
      track_scrollbar = true,
      height_threshold = 5,
    },
    background_pattern = {
      enabled = true,
      primary = {
        type = 'grid',
        spacing = 50,
        line_thickness = 1.5,
      },
      secondary = {
        enabled = true,
        type = 'grid',
        spacing = 5,
        line_thickness = 0.5,
      },
    },
  },

  responsive = {
    enabled = true,
    min_tile_height = 29,  -- Reduced by 1
    base_tile_height_active = 72,
    base_tile_height_pool = 72,
    scrollbar_buffer = 24,
    height_hysteresis = 12,
    stable_frames_required = 2,
    round_to_multiple = 1,
    gap_scaling = {
      enabled = true,
      min_gap = 3,
      max_gap = 12,
    },
  },

  hover = {
    animation_speed = Constants.ANIMATION.HOVER_SPEED,
    brightness_factor = 1.5,
    border_lerp = 0.5,
    base_fill_desaturation = 0.4,
    base_fill_brightness = 0.4,
    base_fill_alpha = hexrgb('#00000066'),
  },

  dim = {
    fill_color = Constants.DIM.FILL,
    stroke_color = Constants.DIM.STROKE,
    stroke_thickness = 1.5,
    rounding = 6,
  },

  drop = {
    move_mode = {
      line = {
        width = 2,
        color = Constants.ACCENT.MOVE,
        glow_width = 12,
        glow_color = glow_color(ColorDefs.OPERATIONS.move, '33'),
      },
      caps = {
        width = 8,
        height = 3,
        color = Constants.ACCENT.MOVE,
        rounding = 0,
        glow_size = 3,
        glow_color = glow_color(ColorDefs.OPERATIONS.move, '44'),
      },
    },
    copy_mode = {
      line = {
        width = 2,
        color = Constants.ACCENT.COPY,
        glow_width = 12,
        glow_color = glow_color(ColorDefs.OPERATIONS.copy, '33'),
      },
      caps = {
        width = 8,
        height = 3,
        color = Constants.ACCENT.COPY,
        rounding = 0,
        glow_size = 3,
        glow_color = glow_color(ColorDefs.OPERATIONS.copy, '44'),
      },
    },
    pulse_speed = 2.5,
  },

  ghost = {
    tile = {
      width = 60,
      height = 40,
      stroke_thickness = 1.5,
      rounding = 4,
      global_opacity = 0.70,
    },
    stack = {
      max_visible = 3,
      offset_x = 3,
      offset_y = 3,
      scale_factor = 0.94,
      opacity_falloff = 0.70,
    },
    badge = {
      border_thickness = 1,
      rounding = 6,
      padding_x = 6,
      padding_y = 3,
      offset_x = 35,
      offset_y = -35,
      min_width = 20,
      min_height = 18,
      shadow = {
        enabled = true,
        offset = 2,
      },
    },
    copy_mode = {
      stroke_color = Constants.ACCENT.COPY,
      glow_color = glow_color(ColorDefs.OPERATIONS.copy, '33'),
      badge_accent = Constants.ACCENT.COPY,
      indicator_text = '+',
      indicator_color = Constants.ACCENT.COPY,
    },
    move_mode = {
      stroke_color = Constants.ACCENT.MOVE,
      glow_color = glow_color(ColorDefs.OPERATIONS.move, '33'),
      badge_accent = Constants.ACCENT.MOVE,
    },
    delete_mode = {
      stroke_color = Constants.ACCENT.DELETE,
      glow_color = glow_color(ColorDefs.OPERATIONS.delete, '33'),
      badge_accent = Constants.ACCENT.DELETE,
      indicator_text = '-',
      indicator_color = Constants.ACCENT.DELETE,
    },
  },

  wheel = {
    step = 1,
  },
}

return M
