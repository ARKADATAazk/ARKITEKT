-- @noindex
-- rearkitekt/defs/app.lua
-- App-level defaults for window, titlebar, status bar, overlay, etc.

local Colors = require('rearkitekt.defs.colors')
local Timing = require('rearkitekt.defs.timing')
local Layout = require('rearkitekt.defs.layout')
local Typography = require('rearkitekt.defs.typography')

-- Helper for hex colors (using rearkitekt.core.colors for conversion)
local CoreColors = require('rearkitekt.core.colors')
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
    -- Close button
    close_button_size = 32,
    close_button_margin = 16,
    close_button_proximity = 150,

    -- Close button colors
    close_button_bg_color = hexrgb(Colors.BASE.black),
    close_button_bg_opacity = 0.6,
    close_button_bg_opacity_hover = 0.8,
    close_button_icon_color = hexrgb(Colors.BASE.white),
    close_button_hover_color = hexrgb("#FF4444"),
    close_button_active_color = hexrgb("#FF0000"),

    -- Layout
    content_padding = Layout.PADDING.xxl,

    -- Scrim/backdrop
    scrim_opacity = 0.99,
    scrim_color = hexrgb(Colors.BASE.black),

    -- Behavior defaults
    default_use_viewport = true,
    default_show_close_button = true,
    default_esc_to_close = true,
    default_close_on_bg_click = false,
    default_close_on_bg_right_click = true,
    default_close_on_scrim = false,
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
    content_padding = Layout.PADDING.lg,
    min_size = { w = 400, h = 300 },
    initial_size = { w = 900, h = 600 },
    initial_pos = { x = 100, y = 100 },

    -- Background colors
    bg_color_floating = nil,
    bg_color_docked = hexrgb("#282828"),

    -- Fullscreen/Viewport mode
    fullscreen = {
        enabled = false,
        use_viewport = true,
        fade_speed = 10.0,
        scrim_enabled = true,
        scrim_color = hexrgb(Colors.BASE.black),
        window_bg_override = nil,
        window_opacity = 1.0,
        show_close_button = true,
        close_on_background_click = true,
        close_on_background_left_click = false,
    },
}

-- ============================================================================
-- TITLEBAR
-- ============================================================================
M.TITLEBAR = {
    -- Layout
    height = 26,
    pad_h = Layout.PADDING.lg,
    pad_v = 0,
    button_width = 44,
    button_spacing = 0,
    button_style = "minimal",
    separator = true,
    icon_size = 18,
    icon_spacing = Layout.PADDING.md,
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
    button_maximize_hovered = hexrgb(Colors.SEMANTIC.success),
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
    compensation = 6,

    -- Padding
    left_pad = 10,
    text_pad = Layout.PADDING.md,
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

-- ============================================================================
-- ACCESSOR METHODS (backward compatibility)
-- ============================================================================

function M.get_defaults()
    return {
        window = M.WINDOW,
        fonts = {
            default = Typography.SIZE.md,
            title = Typography.SIZE.md,
            version = Typography.SIZE.sm,
            titlebar_version_monospace = Typography.SIZE.xs,
            family_regular = Typography.FAMILY.regular,
            family_bold = Typography.FAMILY.bold,
            family_mono = Typography.FAMILY.mono,
        },
        titlebar = M.TITLEBAR,
        status_bar = M.STATUS_BAR,
        dependencies = M.DEPENDENCIES,
    }
end

function M.get(path)
    local keys = {}
    for key in path:gmatch("[^.]+") do
        table.insert(keys, key)
    end

    local root_map = {
        window = M.WINDOW,
        fonts = M.get_defaults().fonts,
        titlebar = M.TITLEBAR,
        status_bar = M.STATUS_BAR,
        dependencies = M.DEPENDENCIES,
    }

    local value = root_map[keys[1]]
    if not value then
        return nil
    end

    for i = 2, #keys do
        if type(value) ~= "table" then
            return nil
        end
        value = value[keys[i]]
    end

    return value
end

return M
