-- @noindex
-- rearkitekt/defs/colors.lua
-- Shared color palette and semantic colors

local M = {}

-- ============================================================================
-- BASE PALETTE
-- ============================================================================
M.BASE = {
    black = "#000000FF",
    white = "#FFFFFFFF",

    -- Grays (dark to light)
    gray_50 = "#0A0A0AFF",
    gray_100 = "#1A1A1AFF",
    gray_200 = "#252525FF",
    gray_300 = "#333333FF",
    gray_400 = "#404040FF",
    gray_500 = "#666666FF",
    gray_600 = "#888888FF",
    gray_700 = "#AAAAAAFF",
    gray_800 = "#CCCCCCFF",
    gray_900 = "#E5E5E5FF",
}

-- ============================================================================
-- SEMANTIC COLORS
-- ============================================================================
M.SEMANTIC = {
    success = "#42E896FF",      -- Green
    warning = "#E0B341FF",      -- Yellow/Orange
    error = "#E04141FF",        -- Red
    info = "#4A9EFFFF",         -- Blue
    accent = "#5588FFFF",       -- Highlight blue
}

-- ============================================================================
-- UI ROLES (default mappings)
-- ============================================================================
M.UI = {
    -- Text
    text_primary = "#CCCCCCFF",
    text_secondary = "#888888FF",
    text_disabled = "#666666FF",

    -- Backgrounds
    bg_base = "#1A1A1AFF",
    bg_panel = "#252525FF",
    bg_elevated = "#333333FF",
    bg_hover = "#404040FF",

    -- Borders
    border = "#333333FF",
    border_light = "#404040FF",
    divider = "#2A2A2AFF",

    -- Interactive
    primary = "#5588FFFF",
    primary_hover = "#6699FFFF",
    primary_active = "#4477EEFF",
}

-- ============================================================================
-- BUTTON COLORS
-- ============================================================================
M.BUTTON = {
    -- Close button
    close_normal = "#00000000",
    close_hover = "#CC3333FF",
    close_active = "#FF1111FF",

    -- Maximize button
    maximize_normal = "#00000000",
    maximize_hover = "#57C290FF",
    maximize_active = "#60FFFFFF",
}

-- ============================================================================
-- STATUS COLORS
-- ============================================================================
M.STATUS = {
    ready = "#41E0A3FF",        -- Green
    warning = "#E0B341FF",      -- Yellow
    error = "#E04141FF",        -- Red
    info = "#CCCCCCFF",         -- Light gray
    playing = "#FFFFFFFF",      -- White
    idle = "#888888FF",         -- Gray
}

return M
