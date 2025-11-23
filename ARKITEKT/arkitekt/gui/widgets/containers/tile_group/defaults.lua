-- @noindex
-- arkitekt/gui/widgets/containers/tile_group/defaults.lua
-- Default styling for tile group headers and containers

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Default group header styling
M.HEADER = {
  -- Dimensions
  height = 40,
  padding_x = 12,
  padding_y = 10,
  color_badge_size = 4,
  color_badge_spacing = 8,
  icon_size = 16,  -- Increased from 12 for bigger arrow
  icon_spacing = 10,

  -- Colors
  bg_color = hexrgb("#2A2A2AEE"),
  bg_color_hover = hexrgb("#353535EE"),
  bg_color_collapsed = hexrgb("#242424EE"),

  border_color = hexrgb("#444444"),
  border_thickness = 1,

  text_color = hexrgb("#EEEEEE"),
  text_color_secondary = hexrgb("#999999"),

  collapse_icon_color = hexrgb("#CCCCCC"),
  collapse_icon_color_hover = hexrgb("#FFFFFF"),

  -- Rounding
  rounding = 4,

  -- Interaction
  hover_brightness = 1.2,
}

-- Default group content styling
M.CONTENT = {
  indent = 20,              -- Pixels to indent grouped items
  vertical_spacing = 4,     -- Extra spacing between groups
}

-- Default collapse/expand icon glyphs
M.ICONS = {
  collapsed = "▸",  -- Right-pointing triangle
  expanded = "▾",   -- Down-pointing triangle
}

return M
