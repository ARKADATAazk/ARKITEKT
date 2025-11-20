-- @noindex
-- rearkitekt/app/constants.lua
-- Central repository for ALL framework constants and defaults
-- Single source of truth for overlay configs, animation timings, sizes, colors, etc.

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- PROFILER
-- ============================================================================
M.PROFILER_ENABLED = false  -- Global toggle for profiler

M.PROFILER = {
  ENABLED_BY_DEFAULT = false,
  WINDOW_WIDTH = 800,
  WINDOW_HEIGHT = 600,
}

-- ============================================================================
-- OVERLAY SYSTEM
-- ============================================================================
M.OVERLAY = {
  -- Close button sizing
  CLOSE_BUTTON_SIZE = 32,
  CLOSE_BUTTON_MARGIN = 16,
  CLOSE_BUTTON_PROXIMITY = 150,  -- Distance at which button starts to fade in

  -- Close button colors
  CLOSE_BUTTON_BG_COLOR = hexrgb("#000000"),
  CLOSE_BUTTON_BG_OPACITY = 0.6,
  CLOSE_BUTTON_BG_OPACITY_HOVER = 0.8,
  CLOSE_BUTTON_ICON_COLOR = hexrgb("#FFFFFF"),
  CLOSE_BUTTON_HOVER_COLOR = hexrgb("#FF4444"),
  CLOSE_BUTTON_ACTIVE_COLOR = hexrgb("#FF0000"),

  -- Layout
  CONTENT_PADDING = 24,

  -- Scrim/backdrop
  SCRIM_OPACITY = 0.85,
  SCRIM_COLOR = hexrgb("#000000"),

  -- Behavior defaults
  DEFAULT_USE_VIEWPORT = true,
  DEFAULT_SHOW_CLOSE_BUTTON = true,
  DEFAULT_ESC_TO_CLOSE = true,
  DEFAULT_CLOSE_ON_BG_CLICK = false,
  DEFAULT_CLOSE_ON_BG_RIGHT_CLICK = true,
  DEFAULT_CLOSE_ON_SCRIM = false,
}

-- ============================================================================
-- ANIMATION TIMINGS
-- ============================================================================
M.ANIMATION = {
  -- Fade durations (seconds)
  FADE_INSTANT = 0.0,
  FADE_FAST = 0.15,
  FADE_NORMAL = 0.3,
  FADE_SLOW = 0.5,

  -- Default curves (see rearkitekt/gui/fx/animation/easing.lua)
  DEFAULT_FADE_CURVE = 'ease_out_quad',

  -- Hover states
  HOVER_SPEED = 12.0,  -- Alpha transition speed for hover effects
}

-- ============================================================================
-- WINDOW DEFAULTS
-- ============================================================================
M.WINDOW = {
  -- Size presets
  SMALL = { w = 800, h = 600, min_w = 600, min_h = 400 },
  MEDIUM = { w = 1200, h = 800, min_w = 800, min_h = 600 },
  LARGE = { w = 1400, h = 900, min_w = 1000, min_h = 700 },

  -- Default positioning offset from top-left
  DEFAULT_OFFSET = { x = 100, y = 100 },

  -- Default window config
  title           = "Arkitekt App",
  content_padding = 12,
  min_size        = { w = 400, h = 300 },
  initial_size    = { w = 900, h = 600 },
  initial_pos     = { x = 100, y = 100 },

  -- Background colors
  bg_color_floating = nil,  -- nil = use ImGui default
  bg_color_docked   = hexrgb("#282828"),  -- Slightly lighter for docked mode

  -- Fullscreen/Viewport mode settings
  fullscreen = {
    enabled = false,  -- Whether to use fullscreen/viewport mode
    use_viewport = true,  -- Use full REAPER viewport vs parent window
    -- Note: fade durations should use M.ANIMATION.FADE_NORMAL (0.3s) instead of hardcoding
    fade_speed = 10.0,  -- Animation speed multiplier (higher = faster)

    scrim_enabled = true,  -- Show dark background scrim
    scrim_color = hexrgb("#000000"),
    -- Note: scrim_opacity should use M.OVERLAY.SCRIM_OPACITY instead of hardcoding

    window_bg_override = nil,  -- Override window background color (nil = use default)
    window_opacity = 1.0,  -- Overall window content opacity

    -- Close behavior
    show_close_button = true,  -- Show floating close button on hover
    close_on_background_click = true,  -- Right-click on scrim/background to close
    close_on_background_left_click = false,  -- Left-click on background to close
    -- Note: close_button styling values (size, margin, proximity, colors) should reference M.OVERLAY constants
  },
}

-- ============================================================================
-- TYPOGRAPHY SCALE
-- ============================================================================
M.TYPOGRAPHY = {
  -- Font sizes (logical scale)
  SMALL = 11,
  DEFAULT = 13,
  MEDIUM = 16,
  LARGE = 20,
  XLARGE = 24,

  -- Semantic mappings
  BODY = 13,
  HEADING = 20,
  TITLE = 24,
  CAPTION = 11,
  CODE = 12,
}

-- ============================================================================
-- FONTS
-- ============================================================================
M.FONTS = {
  -- Default sizes
  default = 13,
  title = 13,
  version = 11,
  titlebar_version_monospace = 10,

  -- Font families
  family_regular = "Inter_18pt-Regular.ttf",
  family_bold = "Inter_18pt-SemiBold.ttf",
  family_mono = 'JetBrainsMono-Regular.ttf',
}

-- ============================================================================
-- TITLEBAR
-- ============================================================================
M.TITLEBAR = {
  -- Layout
  height = 26,
  pad_h = 12,
  pad_v = 0,
  button_width = 44,
  button_spacing = 0,
  button_style = "minimal",
  separator = true,
  icon_size = 18,
  icon_spacing = 8,
  version_spacing = 6,
  show_icon = true,
  enable_maximize = true,

  -- AZK branding font size (Orbitron)
  azk_font_size = 22,  -- Larger for more visible Orbitron geometric style

  -- Colors
  bg_color = nil,
  bg_color_active = nil,
  text_color = nil,
  version_color = hexrgb("#ffffff5b"),

  -- Button colors (minimal style)
  button_maximize_normal = hexrgb("#00000000"),
  button_maximize_hovered = hexrgb("#57C290"),
  button_maximize_active = hexrgb("#60FFFF"),
  button_close_normal = hexrgb("#00000000"),
  button_close_hovered = hexrgb("#CC3333"),
  button_close_active = hexrgb("#FF1111"),

  -- Button colors (filled style)
  button_maximize_filled_normal = hexrgb("#808080"),
  button_maximize_filled_hovered = hexrgb("#999999"),
  button_maximize_filled_active = hexrgb("#666666"),
  button_close_filled_normal = hexrgb("#CC3333"),
  button_close_filled_hovered = hexrgb("#FF4444"),
  button_close_filled_active = hexrgb("#FF1111"),
}

-- ============================================================================
-- STATUS BAR
-- ============================================================================
M.STATUS_BAR = {
  height = 20,
  compensation = 6,  -- Adjustment for layout alignment

  -- Padding and spacing
  left_pad = 10,
  text_pad = 8,
  right_pad = 10,

  -- Resize handle configuration
  show_resize_handle = true,
  resize_square_size = 3,
  resize_spacing = 1,
}

-- ============================================================================
-- LAYOUT
-- ============================================================================
M.LAYOUT = {
  -- Standard padding/spacing values
  PADDING_NONE = 0,
  PADDING_SMALL = 4,
  PADDING_MEDIUM = 8,
  PADDING_LARGE = 12,
  PADDING_XLARGE = 16,

  -- Border radius
  ROUNDING_NONE = 0,
  ROUNDING_SMALL = 2,
  ROUNDING_MEDIUM = 4,
  ROUNDING_LARGE = 8,
}

-- ============================================================================
-- COLORS (Common UI element colors)
-- ============================================================================
-- Note: Actual color values defined in rearkitekt/core/colors.lua
-- This just defines semantic color roles
M.COLOR_ROLES = {
  PRIMARY = "primary",
  SECONDARY = "secondary",
  ACCENT = "accent",
  SUCCESS = "success",
  WARNING = "warning",
  DANGER = "danger",
  INFO = "info",
}

-- ============================================================================
-- DEPENDENCIES
-- ============================================================================
M.DEPENDENCIES = {
  hub_path = "ARKITEKT.lua",  -- Relative path to the hub/launcher file from project root
}

-- ============================================================================
-- ACCESSOR METHODS (for backward compatibility with app_defaults.lua)
-- ============================================================================

-- Returns entire defaults structure in old format
function M.get_defaults()
  return {
    window = M.WINDOW,
    fonts = M.FONTS,
    titlebar = M.TITLEBAR,
    status_bar = M.STATUS_BAR,
    dependencies = M.DEPENDENCIES,
  }
end

-- Get a specific default value by dot-path (e.g., "titlebar.height")
function M.get(path)
  local keys = {}
  for key in path:gmatch("[^.]+") do
    table.insert(keys, key)
  end

  -- Map old paths to new structure
  local root_map = {
    window = M.WINDOW,
    fonts = M.FONTS,
    titlebar = M.TITLEBAR,
    status_bar = M.STATUS_BAR,
    dependencies = M.DEPENDENCIES,
  }

  local value = root_map[keys[1]]
  if not value then
    return nil
  end

  -- Navigate remaining keys
  for i = 2, #keys do
    if type(value) ~= "table" then
      return nil
    end
    value = value[keys[i]]
  end

  return value
end

return M
