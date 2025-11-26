-- @noindex
-- arkitekt/defs/app.lua
-- App-level defaults for window, titlebar, status bar, overlay, etc.

local CoreColors = require('arkitekt.core.colors')
local hexrgb = CoreColors.hexrgb

local M = {}

-- ============================================================================
-- PROFILER
-- ============================================================================
M.PROFILER_ENABLED = false

M.PROFILER = {
    enabled_by_default = false,
    window_width = 800,
    window_height = 600,
}

-- ============================================================================
-- OVERLAY SYSTEM
-- ============================================================================
M.OVERLAY = {
    -- Close button sizing
    CLOSE_BUTTON_SIZE = 32,
    CLOSE_BUTTON_MARGIN = 16,
    CLOSE_BUTTON_PROXIMITY = 150,

    -- Close button colors
    CLOSE_BUTTON_BG_COLOR = hexrgb("#000000FF"),
    CLOSE_BUTTON_BG_OPACITY = 0.6,
    CLOSE_BUTTON_BG_OPACITY_HOVER = 0.8,
    CLOSE_BUTTON_ICON_COLOR = hexrgb("#FFFFFFFF"),
    CLOSE_BUTTON_HOVER_COLOR = hexrgb("#FF4444FF"),
    CLOSE_BUTTON_ACTIVE_COLOR = hexrgb("#FF0000FF"),

    -- Layout
    CONTENT_PADDING = 24,

    -- Scrim/backdrop
    SCRIM_OPACITY = 0.99,
    SCRIM_COLOR = hexrgb("#000000FF"),

    -- Behavior defaults
    DEFAULT_USE_VIEWPORT = true,
    DEFAULT_SHOW_CLOSE_BUTTON = true,
    DEFAULT_ESC_TO_CLOSE = true,
    DEFAULT_CLOSE_ON_BG_CLICK = false,
    DEFAULT_CLOSE_ON_BG_RIGHT_CLICK = true,
    DEFAULT_CLOSE_ON_SCRIM = false,
}

-- ============================================================================
-- WINDOW DEFAULTS
-- ============================================================================
M.WINDOW = {
    -- Size presets
    SMALL = { w = 800, h = 600, min_w = 600, min_h = 400 },
    MEDIUM = { w = 1200, h = 800, min_w = 800, min_h = 600 },
    LARGE = { w = 1400, h = 900, min_w = 1000, min_h = 700 },

    -- Default positioning
    default_offset = { x = 100, y = 100 },

    -- Default window config
    title = "Arkitekt App",
    content_padding = 12,
    min_size = { w = 400, h = 300 },
    initial_size = { w = 900, h = 600 },
    initial_pos = { x = 100, y = 100 },

    -- Background colors
    bg_color_floating = nil,
    bg_color_docked = hexrgb("#282828"),
}

-- ============================================================================
-- TITLEBAR
-- ============================================================================
M.TITLEBAR = {
    -- Layout
    height = 25,  -- Reduced by 1 for DejaVu Sans alignment
    pad_h = 12,
    pad_v = 0,
    button_width = 44,
    button_spacing = 0,
    button_style = "minimal",
    separator = true,
    icon_size = 24,
    icon_spacing = 8,
    version_spacing = 6,
    show_icon = true,
    enable_maximize = true,

    -- Branding
    branding_font_size = 22,
    branding_text = "",
    branding_opacity = 0.15,
    branding_color = nil,

    -- Colors
    bg_color = nil,
    bg_color_active = nil,
    text_color = nil,
    version_color = hexrgb("#ffffff5b"),

    -- Button colors (minimal style)
    button_maximize_normal = hexrgb("#00000000"),
    button_maximize_hovered = hexrgb("#4CAF50FF"),  -- Success green
    button_maximize_active = hexrgb("#60FFFFFF"),
    button_close_normal = hexrgb("#00000000"),
    button_close_hovered = hexrgb("#CC3333FF"),
    button_close_active = hexrgb("#FF1111FF"),

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
    compensation = 6,

    -- Padding
    left_pad = 10,
    text_pad = 8,
    right_pad = 10,

    -- Resize handle
    show_resize_handle = true,
    resize_square_size = 3,
    resize_spacing = 1,
}

-- ============================================================================
-- DEPENDENCIES
-- ============================================================================
M.DEPENDENCIES = {
    hub_path = "ARKITEKT.lua",
}

return M
