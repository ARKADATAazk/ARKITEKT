-- @noindex
-- ReArkitekt/gui/widgets/tiles_container/background.lua
-- Background pattern rendering

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

local function draw_grid_pattern(dl, x1, y1, x2, y2, spacing, color, thickness, offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0
  
  -- Calculate the starting position by finding the first line that would be visible
  -- We need to account for the offset and wrap it within the spacing
  local start_x = x1 - ((x1 - offset_x) % spacing)
  local start_y = y1 - ((y1 - offset_y) % spacing)
  
  -- Draw vertical lines
  local x = start_x
  while x <= x2 do
    ImGui.DrawList_AddLine(dl, x, y1, x, y2, color, thickness)
    x = x + spacing
  end
  
  -- Draw horizontal lines
  local y = start_y
  while y <= y2 do
    ImGui.DrawList_AddLine(dl, x1, y, x2, y, color, thickness)
    y = y + spacing
  end
end

local function draw_dot_pattern(dl, x1, y1, x2, y2, spacing, color, dot_size, offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0
  
  local half_size = dot_size * 0.5
  
  -- Calculate the starting position using modulo to wrap within spacing
  local start_x = x1 - ((x1 - offset_x) % spacing)
  local start_y = y1 - ((y1 - offset_y) % spacing)
  
  -- Draw dots
  local x = start_x
  while x <= x2 do
    local y = start_y
    while y <= y2 do
      ImGui.DrawList_AddCircleFilled(dl, x, y, half_size, color)
      y = y + spacing
    end
    x = x + spacing
  end
end

function M.draw(dl, x1, y1, x2, y2, pattern_cfg)
  if not pattern_cfg or not pattern_cfg.enabled then return end
  
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  
  if pattern_cfg.secondary and pattern_cfg.secondary.enabled then
    local sec = pattern_cfg.secondary
    if sec.type == 'grid' then
      draw_grid_pattern(dl, x1, y1, x2, y2, sec.spacing, sec.color, sec.line_thickness, sec.offset_x, sec.offset_y)
    elseif sec.type == 'dots' then
      draw_dot_pattern(dl, x1, y1, x2, y2, sec.spacing, sec.color, sec.dot_size, sec.offset_x, sec.offset_y)
    end
  end
  
  if pattern_cfg.primary then
    local pri = pattern_cfg.primary
    if pri.type == 'grid' then
      draw_grid_pattern(dl, x1, y1, x2, y2, pri.spacing, pri.color, pri.line_thickness, pri.offset_x, pri.offset_y)
    elseif pri.type == 'dots' then
      draw_dot_pattern(dl, x1, y1, x2, y2, pri.spacing, pri.color, pri.dot_size, pri.offset_x, pri.offset_y)
    end
  end
  
  ImGui.DrawList_PopClipRect(dl)
end

return M