-- @noindex
-- ThemeAdjuster/defs/colors.lua
-- Script-specific color definitions with theme awareness
--
-- Pattern for script isolation:
--   - nil values fall back to Style.COLORS (theme-reactive)
--   - Explicit hex values stay fixed (script-specific)
--   - get() returns resolved colors at render time

local Colors = require('arkitekt.core.colors')
local M = {}

-- ============================================================================
-- SCRIPT-SPECIFIC COLOR DEFINITIONS
-- ============================================================================
-- nil = use Style.COLORS fallback (theme-reactive)
-- hex = explicit color (stays fixed regardless of theme)

M.TILE = {
  -- Theme-reactive (follow light/dark theme)
  bg_inactive = nil,        -- → Style.COLORS.BG_PANEL
  text_inactive = nil,      -- → Style.COLORS.TEXT_NORMAL
  text_secondary = nil,     -- → Style.COLORS.TEXT_DIMMED
  border_inactive = nil,    -- → Style.COLORS.BORDER_OUTER

  -- Script-specific (green accent for 'active/enabled' state)
  bg_active = 0x2D4A37FF,
  text_active = 0xFFFFFFFF,

  -- Hover tint (blend with bg)
  hover_tint = nil,         -- → Style.COLORS.BG_HOVER
  hover_influence = 0.4,

  -- Border for active state (derived from bg_active)
  border_active = nil,      -- Will derive from bg_active
  border_hover = nil,       -- Will derive dynamically
}

M.BADGE = {
  bg_active = 0x00000099,
  bg_inactive = 0x00000066,
  text = nil,               -- → Style.COLORS.TEXT_DIMMED
}

M.FOOTER = {
  gradient = 0x00000044,
}

M.TAGS = {
  -- Tag chip colors (semantic, stay fixed)
  TCP = 0x5A7A9AFF,
  MCP = 0x9A9A5AFF,
  ENVCP = 0x5A9A8AFF,
  TRANSPORT = 0x9A5A5AFF,
  GLOBAL = 0x6A6A6AFF,
  TOOLBARS = 0x8A6A5AFF,
  ITEMS = 0x7A8A5AFF,
  MIDI = 0x6A5A8AFF,
  RTCONFIG = 0x5AAA5AFF,
  text = 0x000000FF,
}

M.SELECTION = {
  ant_color = nil,          -- Will derive from tile color
  brightness_factor = 1.8,
  saturation_factor = 0.6,
}

M.CONFLICT = {
  text = 0xFFA500FF,
}

-- ============================================================================
-- RUNTIME COLOR RESOLUTION
-- ============================================================================

--- Get resolved tile colors (with Style.COLORS fallbacks)
--- Call this at render time to get theme-reactive values
--- @return table Resolved color values
function M.get_tile_colors()
  local ok, Style = pcall(require, 'arkitekt.gui.style')
  local S = ok and Style.COLORS or {}

  return {
    bg_inactive = M.TILE.bg_inactive or S.BG_PANEL or 0x1A1A1AFF,
    bg_active = M.TILE.bg_active,
    text_active = M.TILE.text_active,
    text_inactive = M.TILE.text_inactive or S.TEXT_NORMAL or 0x999999FF,
    text_secondary = M.TILE.text_secondary or S.TEXT_DIMMED or 0x888888FF,
    border_inactive = M.TILE.border_inactive or S.BORDER_OUTER or 0x303030FF,
    hover_tint = M.TILE.hover_tint or S.BG_HOVER or 0x2A2A2AFF,
    hover_influence = M.TILE.hover_influence,
  }
end

--- Get resolved badge colors
--- @return table Resolved badge colors
function M.get_badge_colors()
  local ok, Style = pcall(require, 'arkitekt.gui.style')
  local S = ok and Style.COLORS or {}

  return {
    bg_active = M.BADGE.bg_active,
    bg_inactive = M.BADGE.bg_inactive,
    text = M.BADGE.text or S.TEXT_DIMMED or 0xAAAAAAFF,
  }
end

--- Get tag color by name
--- @param tag_name string Tag identifier (TCP, MCP, etc.)
--- @return number Color in RGBA format
function M.get_tag_color(tag_name)
  return M.TAGS[tag_name] or M.TAGS.GLOBAL
end

return M
