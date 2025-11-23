-- @noindex
-- arkitekt/defs/timing.lua
-- Animation timings, durations, and speeds

local M = {}

-- ============================================================================
-- FADE DURATIONS (seconds)
-- ============================================================================
M.FADE = {
    instant = 0.0,
    fast = 0.15,
    normal = 0.3,
    slow = 0.5,
}

-- ============================================================================
-- ANIMATION SPEEDS (multipliers)
-- ============================================================================
M.SPEED = {
    hover = 12.0,           -- Alpha transition speed for hover effects
    fade = 8.0,             -- General fade speed
    slide = 25.0,           -- Slide/transition speed
}

-- ============================================================================
-- DELAYS
-- ============================================================================
M.DELAY = {
    tooltip = 0.5,          -- Time before tooltip appears
    debounce = 0.1,         -- Input debounce delay
}

-- ============================================================================
-- EASING CURVES
-- ============================================================================
M.EASING = {
    default_fade = 'ease_out_quad',
}

return M
