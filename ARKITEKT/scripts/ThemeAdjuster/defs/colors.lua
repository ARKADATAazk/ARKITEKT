-- @noindex
-- ThemeAdjuster/defs/colors.lua
-- Script-specific color definitions with theme awareness
--
-- Pattern for script isolation:
--   - nil values fall back to Style.COLORS (theme-reactive)
--   - Explicit hex values stay fixed (script-specific)
--   - get() returns resolved colors at render time

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

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

  -- Script-specific (green accent for "active/enabled" state)
  bg_active = hexrgb("#2D4A37"),
  text_active = hexrgb("#FFFFFF"),

  -- Hover tint (blend with bg)
  hover_tint = nil,         -- → Style.COLORS.BG_HOVER
  hover_influence = 0.4,

  -- Border for active state (derived from bg_active)
  border_active = nil,      -- Will derive from bg_active
  border_hover = nil,       -- Will derive dynamically
}

M.BADGE = {
  bg_active = hexrgb("#00000099"),
  bg_inactive = hexrgb("#00000066"),
  text = nil,               -- → Style.COLORS.TEXT_DIMMED
}

M.FOOTER = {
  gradient = hexrgb("#00000044"),
}

M.TAGS = {
  -- Tag chip colors (semantic, stay fixed)
  TCP = hexrgb("#5A7A9A"),
  MCP = hexrgb("#9A9A5A"),
  ENVCP = hexrgb("#5A9A8A"),
  TRANSPORT = hexrgb("#9A5A5A"),
  GLOBAL = hexrgb("#6A6A6A"),
  TOOLBARS = hexrgb("#8A6A5A"),
  ITEMS = hexrgb("#7A8A5A"),
  MIDI = hexrgb("#6A5A8A"),
  RTCONFIG = hexrgb("#5AAA5A"),
  text = hexrgb("#000000"),
}

M.SELECTION = {
  ant_color = nil,          -- Will derive from tile color
  brightness_factor = 1.8,
  saturation_factor = 0.6,
}

M.CONFLICT = {
  text = hexrgb("#FFA500"),
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
    bg_inactive = M.TILE.bg_inactive or S.BG_PANEL or hexrgb("#1A1A1A"),
    bg_active = M.TILE.bg_active,
    text_active = M.TILE.text_active,
    text_inactive = M.TILE.text_inactive or S.TEXT_NORMAL or hexrgb("#999999"),
    text_secondary = M.TILE.text_secondary or S.TEXT_DIMMED or hexrgb("#888888"),
    border_inactive = M.TILE.border_inactive or S.BORDER_OUTER or hexrgb("#303030"),
    hover_tint = M.TILE.hover_tint or S.BG_HOVER or hexrgb("#2A2A2A"),
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
    text = M.BADGE.text or S.TEXT_DIMMED or hexrgb("#AAAAAA"),
  }
end

--- Get tag color by name
--- @param tag_name string Tag identifier (TCP, MCP, etc.)
--- @return number Color in RGBA format
function M.get_tag_color(tag_name)
  return M.TAGS[tag_name] or M.TAGS.GLOBAL
end

return M
