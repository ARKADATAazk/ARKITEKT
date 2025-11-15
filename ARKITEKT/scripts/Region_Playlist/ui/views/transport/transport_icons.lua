-- @noindex
-- Region_Playlist/ui/views/transport/transport_icons.lua
-- Transport icon drawing functions (play, stop, loop, jump)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Performance: Localize math functions for hot path (30% faster in loops)
local floor = math.floor

function M.draw_play(dl, x, y, width, height, color)
  local icon_size = 14 * 0.7
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)
  
  local x1 = floor(cx - icon_size / 3 + 0.5)
  local y1 = floor(cy - icon_size / 2 + 0.5)
  local x2 = floor(cx - icon_size / 3 + 0.5)
  local y2 = floor(cy + icon_size / 2 + 0.5)
  local x3 = floor(cx + icon_size / 2 + 0.5)
  local y3 = cy
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1, y1)
  ImGui.DrawList_PathLineTo(dl, x2, y2)
  ImGui.DrawList_PathLineTo(dl, x3, y3)
  ImGui.DrawList_PathFillConvex(dl, color)
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1, y1)
  ImGui.DrawList_PathLineTo(dl, x2, y2)
  ImGui.DrawList_PathLineTo(dl, x3, y3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)
end

function M.draw_stop(dl, x, y, width, height, color)
  local icon_size = 10
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)
  
  local x1 = floor(cx - icon_size / 2 + 0.5)
  local y1 = floor(cy - icon_size / 2 + 0.5)
  local x2 = floor(cx + icon_size / 2 + 0.5)
  local y2 = floor(cy + icon_size / 2 + 0.5)
  
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, 0)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, color, 0, 0, 0.5)
end

function M.draw_loop(dl, x, y, width, height, color)
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)
  
  local line_width = 2
  local l_width = 6
  local l_height = 9
  local rect_width = 2
  local rect_height = 5
  local gap = 1
  
  local total_width = l_width + gap + rect_width + gap + rect_width + gap + l_width
  local start_x = floor(cx - total_width / 2 + 0.5)
  local start_y = floor(cy - l_height / 2 + 0.5)
  
  local left_L_dx = 3
  local rect1_dx, rect1_dy = -1, -4
  local rect2_dx, rect2_dy = 0, 4
  local right_L_dx = -4
  
  local left_x = floor(start_x + left_L_dx + 0.5)
  ImGui.DrawList_AddRectFilled(dl, left_x, start_y, left_x + line_width, start_y + l_height, color)
  ImGui.DrawList_AddRectFilled(dl, left_x, start_y + l_height - line_width, left_x + l_width, start_y + l_height, color)
  
  local rect1_x = floor(start_x + l_width + gap + rect1_dx + 0.5)
  local rect1_y = floor(cy - rect_height / 2 + rect1_dy + 0.5)
  ImGui.DrawList_AddRectFilled(dl, rect1_x, rect1_y, rect1_x + rect_width, rect1_y + rect_height, color)
  
  local rect2_x = floor(start_x + l_width + gap + rect_width + gap + rect2_dx + 0.5)
  local rect2_y = floor(cy - rect_height / 2 + rect2_dy + 0.5)
  ImGui.DrawList_AddRectFilled(dl, rect2_x, rect2_y, rect2_x + rect_width, rect2_y + rect_height, color)
  
  local right_l_x = floor(rect2_x + rect_width + gap + right_L_dx + 0.5)
  ImGui.DrawList_AddRectFilled(dl, right_l_x + l_width - line_width, start_y, right_l_x + l_width, start_y + l_height, color)
  ImGui.DrawList_AddRectFilled(dl, right_l_x, start_y, right_l_x + l_width, start_y + line_width, color)
end

function M.draw_jump(dl, x, y, width, height, color)
  local icon_size = 11
  local spacing = 3
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)

  local x1_1 = floor(cx - icon_size - spacing / 2 + 0.5)
  local y1_1 = floor(cy - icon_size / 2 + 0.5)
  local x1_2 = floor(cx - icon_size - spacing / 2 + 0.5)
  local y1_2 = floor(cy + icon_size / 2 + 0.5)
  local x1_3 = floor(cx - spacing / 2 + 0.5)
  local y1_3 = cy

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1_1, y1_1)
  ImGui.DrawList_PathLineTo(dl, x1_2, y1_2)
  ImGui.DrawList_PathLineTo(dl, x1_3, y1_3)
  ImGui.DrawList_PathFillConvex(dl, color)

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x1_1, y1_1)
  ImGui.DrawList_PathLineTo(dl, x1_2, y1_2)
  ImGui.DrawList_PathLineTo(dl, x1_3, y1_3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)

  local x2_1 = floor(cx + spacing / 2 + 0.5)
  local y2_1 = floor(cy - icon_size / 2 + 0.5)
  local x2_2 = floor(cx + spacing / 2 + 0.5)
  local y2_2 = floor(cy + icon_size / 2 + 0.5)
  local x2_3 = floor(cx + icon_size + spacing / 2 + 0.5)
  local y2_3 = cy

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x2_1, y2_1)
  ImGui.DrawList_PathLineTo(dl, x2_2, y2_2)
  ImGui.DrawList_PathLineTo(dl, x2_3, y2_3)
  ImGui.DrawList_PathFillConvex(dl, color)

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x2_1, y2_1)
  ImGui.DrawList_PathLineTo(dl, x2_2, y2_2)
  ImGui.DrawList_PathLineTo(dl, x2_3, y2_3)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 0.5)
end

function M.draw_bolt(dl, x, y, width, height, color)
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)

  -- Simplified lightning bolt using rectangles
  -- Top vertical segment
  local top_x = cx - 1
  local top_y = cy - 6
  local top_w = 2
  local top_h = 4
  ImGui.DrawList_AddRectFilled(dl, top_x, top_y, top_x + top_w, top_y + top_h, color)

  -- Upper diagonal (top-right slant)
  local mid1_x = cx - 1
  local mid1_y = cy - 2
  local mid1_w = 4
  local mid1_h = 2
  ImGui.DrawList_AddRectFilled(dl, mid1_x, mid1_y, mid1_x + mid1_w, mid1_y + mid1_h, color)

  -- Middle vertical (offset left)
  local mid2_x = cx - 2
  local mid2_y = cy
  local mid2_w = 2
  local mid2_h = 2
  ImGui.DrawList_AddRectFilled(dl, mid2_x, mid2_y, mid2_x + mid2_w, mid2_y + mid2_h, color)

  -- Lower diagonal (bottom-left slant)
  local mid3_x = cx - 4
  local mid3_y = cy + 2
  local mid3_w = 4
  local mid3_h = 2
  ImGui.DrawList_AddRectFilled(dl, mid3_x, mid3_y, mid3_x + mid3_w, mid3_y + mid3_h, color)

  -- Bottom vertical segment
  local bot_x = cx - 1
  local bot_y = cy + 4
  local bot_w = 2
  local bot_h = 3
  ImGui.DrawList_AddRectFilled(dl, bot_x, bot_y, bot_x + bot_w, bot_y + bot_h, color)
end

function M.draw_gear(dl, x, y, width, height, color)
  local cx = floor(x + width / 2 + 0.5)
  local cy = floor(y + height / 2 + 0.5)

  -- Simple gear using circle with small rectangles for teeth
  local body_radius = 5
  local tooth_len = 2
  local tooth_w = 2
  local tooth_count = 8

  -- Draw main body circle
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, body_radius, color, 16)

  -- Draw teeth as small rectangles around the circle
  for i = 0, tooth_count - 1 do
    local angle = (i / tooth_count) * 2 * math.pi
    local tooth_cx = cx + math.cos(angle) * (body_radius + tooth_len / 2)
    local tooth_cy = cy + math.sin(angle) * (body_radius + tooth_len / 2)

    -- Small rectangle for tooth
    local tx = floor(tooth_cx - tooth_w / 2 + 0.5)
    local ty = floor(tooth_cy - tooth_w / 2 + 0.5)
    ImGui.DrawList_AddRectFilled(dl, tx, ty, tx + tooth_w, ty + tooth_w, color, 0)
  end

  -- Draw center hole
  local hole_radius = 2
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, hole_radius, 0xFF000000, 12)
  ImGui.DrawList_AddCircle(dl, cx, cy, hole_radius, color, 12, 1)
end

return M
