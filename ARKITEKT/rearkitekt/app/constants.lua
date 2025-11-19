-- @noindex
-- rearkitekt/app/constants.lua
-- Central repository for all framework constants
-- Single source of truth for overlay configs, animation timings, sizes, etc.

local M = {}

-- ============================================================================
-- OVERLAY SYSTEM
-- ============================================================================
M.OVERLAY = {
  -- Close button
  CLOSE_BUTTON_SIZE = 32,
  CLOSE_BUTTON_MARGIN = 16,
  CLOSE_BUTTON_PROXIMITY = 150,  -- Distance at which button starts to fade in

  -- Layout
  CONTENT_PADDING = 24,

  -- Scrim/backdrop
  SCRIM_OPACITY = 0.85,

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
-- WINDOW PRESETS
-- ============================================================================
M.WINDOW = {
  -- Size presets
  SMALL = { w = 800, h = 600, min_w = 600, min_h = 400 },
  MEDIUM = { w = 1200, h = 800, min_w = 800, min_h = 600 },
  LARGE = { w = 1400, h = 900, min_w = 1000, min_h = 700 },

  -- Default positioning offset from top-left
  DEFAULT_OFFSET = { x = 100, y = 100 },
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
-- CHROME (Titlebar, Status Bar, etc.)
-- ============================================================================
M.CHROME = {
  TITLEBAR_HEIGHT = 26,
  STATUS_BAR_HEIGHT = 28,
  STATUS_BAR_COMPENSATION = 6,  -- Adjustment for layout alignment
  TAB_HEIGHT = 30,
}

-- ============================================================================
-- COLORS (Common UI element colors)
-- ============================================================================
-- Note: Actual color values defined in rearkitekt/gui/theme/colors.lua
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
-- PROFILER
-- ============================================================================
M.PROFILER = {
  ENABLED_BY_DEFAULT = false,
  WINDOW_WIDTH = 800,
  WINDOW_HEIGHT = 600,
}

return M
