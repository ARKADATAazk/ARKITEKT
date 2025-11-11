-- @noindex
-- ReArkitekt/gui/fx/dnd/config.lua
-- Centralized configuration for drag and drop visual indicators

local Colors = require('rearkitekt.core.colors')

local M = {}
local hexrgb = Colors.hexrgb

M.MODES = {
  move = {
    stroke_color = hexrgb("#42E896"),
    glow_color = hexrgb("#42E89633"),
    badge_accent = hexrgb("#42E896"),
  },
  copy = {
    stroke_color = hexrgb("#9C87E8"),
    glow_color = hexrgb("#9C87E833"),
    badge_accent = hexrgb("#9C87E8"),
    indicator_text = "+",
    indicator_color = hexrgb("#9C87E8"),
  },
  delete = {
    stroke_color = hexrgb("#E84A4A"),
    glow_color = hexrgb("#E84A4A33"),
    badge_accent = hexrgb("#E84A4A"),
    indicator_text = "-",
    indicator_color = hexrgb("#E84A4A"),
  },
}

M.TILE_DEFAULTS = {
  width = 60,
  height = 40,
  base_fill = hexrgb("#1A1A1A"),
  stroke_thickness = 1.5,
  rounding = 4,
  global_opacity = 0.70,
}

M.STACK_DEFAULTS = {
  max_visible = 3,
  offset_x = 3,
  offset_y = 3,
  scale_factor = 0.94,
  opacity_falloff = 0.70,
}

M.BADGE_DEFAULTS = {
  bg = hexrgb("#1A1A1AEE"),
  border_color = hexrgb("#00000099"),
  border_thickness = 1,
  rounding = 6,
  padding_x = 6,
  padding_y = 3,
  offset_x = 35,
  offset_y = -35,
  min_width = 20,
  min_height = 18,
}

M.DROP_DEFAULTS = {
  line_width = 2,
  glow_width = 12,
  pulse_speed = 2.5,
  caps = {
    width = 12,
    height = 3,
    rounding = 0,
    glow_size = 6,
  },
}

M.SHADOW_DEFAULTS = {
  enabled = false,
  layers = 2,
  base_color = hexrgb("#00000044"),
  offset = 2,
  blur_spread = 1.0,
}

M.INNER_GLOW_DEFAULTS = {
  enabled = false,
  color = hexrgb("#42E89622"),
  thickness = 2,
}

function M.get_mode_config(config, is_copy, is_delete)
  local mode_key = is_delete and 'delete' or (is_copy and 'copy' or 'move')
  local mode_cfg = (config and config[mode_key .. '_mode']) or M.MODES[mode_key]
  return mode_cfg
end

return M