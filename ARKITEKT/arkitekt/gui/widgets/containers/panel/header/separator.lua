-- @noindex
-- Arkitekt/gui/widgets/panel/header/separator.lua
-- Separator element for header layout

local Theme = require('arkitekt.theme')

local M = {}

function M.Draw(ctx, dl, x, y, width, height, config)
  -- Separator is just empty space
  -- The layout engine will handle corner rounding of adjacent elements

  -- Optional: Draw a visual line if configured
  if config.show_line then
    local line_x = x + width * 0.5
    -- Dynamic color from Theme.COLORS for theme reactivity
    local line_color = config.line_color or Theme.COLORS.BORDER_INNER
    local line_thickness = config.line_thickness or 1
    local line_height = height * (config.line_height_ratio or 0.6)
    local line_y1 = y + (height - line_height) * 0.5
    local line_y2 = line_y1 + line_height
    
    -- DrawList_AddLine expects: dl, x1, y1, x2, y2, color, thickness
    local ImGui = require('arkitekt.core.imgui')
    ImGui.DrawList_AddLine(dl, line_x, line_y1, line_x, line_y2, line_color, line_thickness)
  end
  
  return width
end

function M.Measure(ctx, config)
  -- Separators can be fixed width or flex
  return config.width or 0
end

return M