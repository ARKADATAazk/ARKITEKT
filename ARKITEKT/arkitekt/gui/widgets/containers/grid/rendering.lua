-- @noindex
-- Arkitekt/gui/widgets/grid/rendering.lua
-- Generic tile rendering helpers for grid widgets (using new color system)

local ImGui = require('arkitekt.platform.imgui')

local Draw = require('arkitekt.gui.draw.primitives')
local Colors = require('arkitekt.core.colors')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')

local M = {}

M.TileHelpers = {}

local DEFAULTS = {
  hover_shadow = {
    enabled = true,
    max_offset = 2,
    max_alpha = 20,
  },
  selection = {
    ant_speed = 20,
    ant_dash = 8,
    ant_gap = 6,
  },
  color_mode = 'auto',
}

function M.TileHelpers.render_hover_shadow(dl, x1, y1, x2, y2, hover_factor, rounding, config)
  config = config or DEFAULTS.hover_shadow
  if not config.enabled or hover_factor < 0.01 then return end
  
  local shadow_alpha = (hover_factor * (config.max_alpha or 20)) // 1
  local shadow_col = (0x000000 << 8) | shadow_alpha
  
  for i = (config.max_offset or 2), 1, -1 do
    Draw.RectFilled(dl, x1 - i, y1 - i + 2, x2 + i, y2 + i + 2, shadow_col, rounding)
  end
end

function M.TileHelpers.render_border(dl, x1, y1, x2, y2, is_selected, base_color, border_color, thickness, rounding, config)
  config = config or DEFAULTS.selection
  thickness = thickness or 1

  if is_selected then
    local ant_color = Colors.DeriveMarchingAnts(base_color)
    -- No inset, same pixel line as the normal border:
    MarchingAnts.Draw(
      dl, x1, y1, x2, y2,
      ant_color, thickness, rounding,
      config.ant_dash or 8, config.ant_gap or 6, config.ant_speed or 20
    )
  else
    Draw.Rect(dl, x1, y1, x2, y2, border_color, rounding, thickness)
  end
end


function M.TileHelpers.compute_border_color(base_color, is_hovered, is_active, hover_factor, hover_lerp, color_mode)
  color_mode = color_mode or DEFAULTS.color_mode
  
  local border_color = Colors.DeriveBorder(base_color, {
    mode = (color_mode == 'grayscale') and 'brighten' or 'normalize',
    pullback = (color_mode == 'bright') and 0.85 or 0.95,
  })
  
  if is_hovered and hover_factor and hover_lerp then
    local selection_color = Colors.DeriveSelection(base_color)
    return Colors.Lerp(border_color, selection_color, hover_factor * hover_lerp)
  end
  
  return border_color
end

function M.TileHelpers.compute_fill_color(base_color, hover_factor, hover_config)
  local base_fill = Colors.DeriveFill(base_color, {
    desaturate = hover_config and hover_config.base_fill_desaturation or 0.5,
    brightness = hover_config and hover_config.base_fill_brightness or 0.45,
    alpha = hover_config and hover_config.base_fill_alpha or 0xCC,
  })
  
  if hover_factor and hover_factor > 0 then
    local hover_brightness = hover_config and hover_config.hover_brightness_factor or 0.65
    local hover_fill = Colors.AdjustBrightness(base_fill, hover_brightness)
    return Colors.Lerp(base_fill, hover_fill, hover_factor)
  end
  
  return base_fill
end

return M