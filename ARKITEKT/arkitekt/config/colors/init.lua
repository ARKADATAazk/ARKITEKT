-- @noindex
-- arkitekt/defs/colors/init.lua
-- Color system entry point
--
-- Exports:
--   Theme-reactive (from theme.lua):
--     - presets, anchors, colors
--     - DSL: snap, lerp, offset, bg
--     - get_all_keys()
--
--   Static (from static.lua):
--     - PALETTE (28 Wwise colors)
--     - get_color_by_id(), get_palette_colors(), get_color_by_name()

local Theme = require('arkitekt.config.colors.theme')
local Static = require('arkitekt.config.colors.static')

local M = {}

-- =============================================================================
-- THEME-REACTIVE (from theme.lua)
-- =============================================================================

-- Presets & anchors
M.presets = Theme.presets
M.anchors = Theme.anchors

-- DSL wrappers
M.snap = Theme.snap
M.lerp = Theme.lerp
M.offset = Theme.offset
M.bg = Theme.bg

-- Color definitions
M.colors = Theme.colors

-- Utilities
M.get_all_keys = Theme.get_all_keys
M.get_range_for_key = Theme.get_range_for_key
M.clamp_value = Theme.clamp_value

-- =============================================================================
-- STATIC (from static.lua)
-- =============================================================================

-- Wwise palette
M.PALETTE = Static.PALETTE

-- Helpers
M.get_color_by_id = Static.get_color_by_id
M.get_palette_colors = Static.get_palette_colors
M.get_color_by_name = Static.get_color_by_name

-- =============================================================================
-- BACKWARD COMPATIBILITY
-- =============================================================================
-- Static fallback values for code that reads OPERATIONS at require time.
-- For theme-reactive colors, use Style.COLORS.OP_MOVE/OP_COPY/etc. at runtime.

M.OPERATIONS = {
  move = 0xCCCCCCFF,   -- Fallback: light gray
  copy = 0x06B6D4FF,   -- Fallback: cyan
  delete = 0xE84A4AFF, -- Fallback: red
  link = 0x4A9EFFFF,   -- Fallback: blue
}

return M
