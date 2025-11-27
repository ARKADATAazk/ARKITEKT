-- @noindex
-- ItemPicker/defs/constants.lua
-- Centralized constants and configuration values
--
-- THEME INTEGRATION:
-- Colors are now derived from the Theme Manager for dark/light theme support.
-- Call M.refresh_colors() when theme changes, or use M.get_colors() for
-- dynamic color access.
--
-- Note: Theme initialization is lazy to support loading before Shell.run()

local ark = require('arkitekt')
local hexrgb = ark.Colors.hexrgb

local M = {}

-- Lazy load Theme and ItemPickerTheme to avoid requiring before Theme.init()
local _Theme
local _ItemPickerTheme
local _theme_initialized = false

local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.core.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

local function get_item_picker_theme()
  if not _ItemPickerTheme then
    local ok, theme = pcall(require, 'scripts.ItemPicker.defs.theme')
    if ok then _ItemPickerTheme = theme end
  end
  return _ItemPickerTheme
end

--- Ensure theme is initialized (call after Shell.run() starts)
local function ensure_theme_initialized()
  if _theme_initialized then return end

  local ItemPickerTheme = get_item_picker_theme()
  if ItemPickerTheme and ItemPickerTheme.init then
    ItemPickerTheme.init()
    _theme_initialized = true
  end
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
-- Colors are now computed from Theme Manager for dark/light theme support.
-- Use M.get_colors() for dynamic access or M.COLORS for cached values.

-- Cache for computed colors
local _colors_cache = nil
local _cache_t = nil

--- Get theme-derived colors (computed on demand)
--- @return table Colors table with theme-reactive values
function M.get_colors()
  ensure_theme_initialized()

  local Theme = get_theme()
  local ItemPickerTheme = get_item_picker_theme()

  -- Get current t value (default to 0 for dark theme if Theme not available)
  local current_t = Theme and Theme.get_t and Theme.get_t() or 0

  -- Return cache if t hasn't changed
  if _colors_cache and _cache_t == current_t then
    return _colors_cache
  end

  -- Get computed palette from theme (or empty table if not available)
  local palette = ItemPickerTheme and ItemPickerTheme.get() or {}

  -- Get Theme.COLORS (or empty table if not available)
  local ThemeColors = Theme and Theme.COLORS or {}

  -- Build colors table with theme values, falling back to defaults
  _colors_cache = {
    HOVER_OVERLAY = palette.HOVER_OVERLAY or hexrgb("#FFFFFF20"),
    TEXT_SHADOW = palette.TEXT_SHADOW or hexrgb("#00000050"),
    DEFAULT_TRACK_COLOR = {
      palette.DEFAULT_TRACK_COLOR_R or 85/256,
      palette.DEFAULT_TRACK_COLOR_G or 91/256,
      palette.DEFAULT_TRACK_COLOR_B or 91/256,
    },

    -- Status bar colors
    LOADING = palette.LOADING or hexrgb("#4A9EFF"),
    HINT = palette.TEXT_HINT or hexrgb("#888888"),

    -- Panel colors (use Theme.COLORS for BG-derived values)
    PANEL_BACKGROUND = ThemeColors.BG_CHROME or hexrgb("#0F0F0F"),
    PANEL_BORDER = ThemeColors.BG_PANEL or hexrgb("#1A1A1A"),
    PATTERN = ThemeColors.PATTERN_PRIMARY or hexrgb("#2A2A2A"),

    -- Text colors
    MUTED_TEXT = palette.TEXT_MUTED or hexrgb("#CC2222"),
    PRIMARY_TEXT = palette.TEXT_PRIMARY or hexrgb("#FFFFFF"),

    -- Backdrop/badge colors
    BADGE_BG = palette.BADGE_BG or hexrgb("#14181C"),
    DISABLED_BACKDROP = ThemeColors.BG_PANEL or hexrgb("#1A1A1A"),

    -- Drag handler
    DEFAULT_DRAG_COLOR = palette.DRAG_COLOR or hexrgb("#42E896FF"),

    -- Fallback
    FALLBACK_TRACK = palette.FALLBACK_TRACK or 0x4A5A6AFF,
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
-- Note: For dynamic theming, prefer M.get_colors()
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
-- TILE RENDERING (Theme-reactive)
-- =============================================================================
-- Some values are computed from theme palette for dark/light support.

--- Get theme-reactive tile render config
--- @return table TILE_RENDER config with theme-derived values
function M.get_tile_render()
  ensure_theme_initialized()

  local Theme = get_theme()
  local ItemPickerTheme = get_item_picker_theme()
  local palette = ItemPickerTheme and ItemPickerTheme.get() or {}
  local ThemeColors = Theme and Theme.COLORS or {}

  return {
    -- Base tile fill
    base_fill = {
      saturation_factor = palette.BASE_SATURATION_FACTOR or 0.9,
      brightness_factor = palette.BASE_BRIGHTNESS_FACTOR or 0.6,
      compact_saturation_factor = palette.COMPACT_SATURATION_FACTOR or 0.7,
      compact_brightness_factor = palette.COMPACT_BRIGHTNESS_FACTOR or 0.4,
    },

    -- Hover effect
    hover = {
      brightness_boost = palette.HOVER_BRIGHTNESS_BOOST or 0.50,
    },

    -- Minimum lightness
    min_lightness = palette.TILE_MIN_LIGHTNESS or 0.20,

    -- Duration text
    duration_text = {
      margin_x = 4,
      margin_y = 3,
      dark_tile_threshold = palette.DURATION_DARK_THRESHOLD or 0.80,
      light_saturation = palette.DURATION_LIGHT_SATURATION or 0.2,
      light_value = palette.DURATION_LIGHT_VALUE or 4.2,
      dark_saturation = palette.DURATION_DARK_SATURATION or 0.4,
      dark_value = palette.DURATION_DARK_VALUE or 0.18,
    },

    -- Selection (marching ants)
    selection = {
      border_saturation = palette.SELECTION_BORDER_SATURATION or 1.0,
      border_brightness = palette.SELECTION_BORDER_BRIGHTNESS or 3.5,
      ants_alpha = 0xFF,
      ants_thickness = 1,
      ants_inset = 0,
      ants_dash = 24,
      ants_gap = 11,
      ants_speed = 30,
      tile_brightness_boost = palette.SELECTION_TILE_BRIGHTNESS_BOOST or 0.35,
    },

    -- Disabled state
    disabled = {
      desaturate = palette.DISABLED_DESATURATE or 0.10,
      brightness = palette.DISABLED_BRIGHTNESS or 0.60,
      min_alpha = math.floor((palette.DISABLED_MIN_ALPHA or 0.27) * 255),
      fade_speed = 20.0,
      backdrop_color = ThemeColors.BG_PANEL or hexrgb("#1A1A1A"),
      backdrop_alpha = math.floor((palette.DISABLED_BACKDROP_ALPHA or 0.53) * 255),
    },

    -- Muted state
    muted = {
      text_color = palette.TEXT_MUTED or hexrgb("#CC2222"),
      desaturate = palette.MUTED_DESATURATE or 0.25,
      brightness = palette.MUTED_BRIGHTNESS or 0.70,
      alpha_factor = palette.MUTED_ALPHA_FACTOR or 0.85,
      fade_speed = 20.0,
    },

    -- Header
    header = {
      height_ratio = 0.15,
      min_height = 21,
      rounding_offset = 2,
      saturation_factor = 0.7,
      brightness_factor = 1,
      alpha = math.floor((palette.HEADER_ALPHA or 0.87) * 255),
      text_shadow = palette.HEADER_TEXT_SHADOW or hexrgb("#00000099"),
    },

    -- Badges (use theme-derived badge colors)
    badges = {
      cycle = {
        padding_x = 5,
        padding_y = 0,
        margin = 4,
        rounding = 3,
        bg = palette.BADGE_BG or hexrgb("#14181C"),
        border_darken = palette.BADGE_BORDER_DARKEN or 0.4,
        border_alpha = math.floor((palette.BADGE_BORDER_ALPHA or 0.4) * 255),
      },
      pool = {
        padding_x = 4,
        padding_y = 0,
        margin = 4,
        rounding = 3,
        bg = palette.BADGE_BG or hexrgb("#14181C"),
        border_darken = palette.BADGE_BORDER_DARKEN or 0.4,
        border_alpha = math.floor((palette.BADGE_BORDER_ALPHA or 0.33) * 255),
      },
      favorite = {
        icon_size = 14,
        margin = 4,
        spacing = 4,
        rounding = 3,
        bg = palette.BADGE_BG or hexrgb("#14181C"),
        border_darken = palette.BADGE_BORDER_DARKEN or 0.4,
        border_alpha = math.floor((palette.BADGE_BORDER_ALPHA or 0.4) * 255),
      },
    },

    -- Text
    text = {
      primary_color = palette.TEXT_PRIMARY or hexrgb("#FFFFFF"),
      padding_left = 4,
      padding_top = 3,
      margin_right = 6,
    },

    -- Waveform & MIDI
    waveform = {
      saturation_multiplier = 0.0,
      brightness_multiplier = 1.0,
      saturation = palette.WAVEFORM_SATURATION or 0.3,
      brightness = palette.WAVEFORM_BRIGHTNESS or 0.1,
      line_alpha = palette.WAVEFORM_LINE_ALPHA or 0.95,
      zero_line_alpha = palette.WAVEFORM_ZERO_LINE_ALPHA or 0.3,
    },

    -- Tile FX
    tile_fx = {
      fill_opacity = palette.TILE_FX_FILL_OPACITY or 0.65,
      fill_saturation = palette.TILE_FX_FILL_SATURATION or 0.75,
      fill_brightness = palette.TILE_FX_FILL_BRIGHTNESS or 0.6,
      border_opacity = 0.0,
      border_saturation = 0.8,
      border_brightness = 1.4,
      border_thickness = 1.0,
      gradient_intensity = palette.TILE_FX_GRADIENT_INTENSITY or 0.2,
      gradient_opacity = palette.TILE_FX_GRADIENT_OPACITY or 0.08,
      specular_strength = palette.TILE_FX_SPECULAR_STRENGTH or 0.12,
      specular_coverage = 0.25,
      inner_shadow_strength = palette.TILE_FX_INNER_SHADOW_STRENGTH or 0.25,
      ants_enabled = true,
      ants_replace_border = false,
      ants_thickness = 1,
      ants_dash = 24,
      ants_gap = 11,
      ants_speed = 30,
      ants_inset = 0,
      ants_alpha = 0xFF,
      glow_strength = palette.TILE_FX_GLOW_STRENGTH or 0.4,
      glow_layers = 3,
      hover_fill_boost = palette.TILE_FX_HOVER_FILL_BOOST or 0.16,
      hover_specular_boost = palette.TILE_FX_HOVER_SPECULAR_BOOST or 1.2,
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
      visualization_alpha = palette.SMALL_TILE_VISUALIZATION_ALPHA or 0.1,
      header_saturation_factor = palette.SMALL_TILE_HEADER_SATURATION or 0.6,
      header_brightness_factor = palette.SMALL_TILE_HEADER_BRIGHTNESS or 0.7,
      header_alpha = 0.0,
      header_text_shadow = palette.HEADER_TEXT_SHADOW or hexrgb("#00000099"),
    },
  }
end

-- Cache for tile render config
local _tile_render_cache = nil
local _tile_render_cache_t = nil

-- Legacy static access (uses cached theme config)
-- Note: For dynamic theming, prefer M.get_tile_render()
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
-- REGION TAGS (Theme-reactive)
-- =============================================================================

--- Get theme-reactive region tags config
function M.get_region_tags()
  ensure_theme_initialized()

  local ItemPickerTheme = get_item_picker_theme()
  local palette = ItemPickerTheme and ItemPickerTheme.get() or {}

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
      bg_color = palette.REGION_CHIP_BG or hexrgb("#14181C"),
      alpha = 0xFF,
      text_min_lightness = palette.REGION_TEXT_MIN_LIGHTNESS or 0.35,
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
