-- @noindex
-- ReArkitekt/gui/widgets/tools/custom_color_picker.lua
-- Custom color picker with hue wheel and SV triangle with black borders

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

-- Cache math functions for performance
local abs, max, min = math.abs, math.max, math.min
local pi, cos, sin, sqrt, atan = math.pi, math.cos, math.sin, math.sqrt, math.atan

local M = {}

-- Convert HSV to RGB
local function hsv_to_rgb(h, s, v)
  local c = v * s
  local x = c * (1 - abs((h * 6) % 2 - 1))
  local m = v - c

  local r, g, b
  if h < 1/6 then
    r, g, b = c, x, 0
  elseif h < 2/6 then
    r, g, b = x, c, 0
  elseif h < 3/6 then
    r, g, b = 0, c, x
  elseif h < 4/6 then
    r, g, b = 0, x, c
  elseif h < 5/6 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  return (r + m) * 255, (g + m) * 255, (b + m) * 255
end

-- Convert RGB to HSV
local function rgb_to_hsv(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local max_c = max(r, g, b)
  local min_c = min(r, g, b)
  local delta = max_c - min_c

  local h = 0
  if delta ~= 0 then
    if max_c == r then
      h = ((g - b) / delta) % 6
    elseif max_c == g then
      h = (b - r) / delta + 2
    else
      h = (r - g) / delta + 4
    end
    h = h / 6
  end

  local s = (max_c == 0) and 0 or (delta / max_c)
  local v = max_c

  return h, s, v
end

-- Point in triangle test
local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
  local v0x, v0y = cx - ax, cy - ay
  local v1x, v1y = bx - ax, by - ay
  local v2x, v2y = px - ax, py - ay

  local dot00 = v0x * v0x + v0y * v0y
  local dot01 = v0x * v1x + v0y * v1y
  local dot02 = v0x * v2x + v0y * v2y
  local dot11 = v1x * v1x + v1y * v1y
  local dot12 = v1x * v2x + v1y * v2y

  local inv_denom = 1 / (dot00 * dot11 - dot01 * dot01)
  local u = (dot11 * dot02 - dot01 * dot12) * inv_denom
  local v = (dot00 * dot12 - dot01 * dot02) * inv_denom

  return (u >= 0) and (v >= 0) and (u + v <= 1)
end

--- Render custom color picker
--- @param ctx userdata ImGui context
--- @param size number Size of the picker
--- @param h number Hue (0-1)
--- @param s number Saturation (0-1)
--- @param v number Value (0-1)
--- @return boolean changed, number h, number s, number v
function M.render(ctx, size, h, s, v)
  local changed = false

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local cx, cy = ImGui.GetCursorScreenPos(ctx)

  -- Center of the picker
  local center_x = cx + size / 2
  local center_y = cy + size / 2

  local outer_radius = size / 2 - 5
  local inner_radius = outer_radius * 0.65
  local wheel_thickness = outer_radius - inner_radius

  -- Draw hue wheel
  local segments = 64
  for i = 0, segments - 1 do
    local angle1 = (i / segments) * 2 * pi
    local angle2 = ((i + 1) / segments) * 2 * pi

    local hue1 = i / segments
    local hue2 = (i + 1) / segments

    local r1, g1, b1 = hsv_to_rgb(hue1, 1, 1)
    local r2, g2, b2 = hsv_to_rgb(hue2, 1, 1)

    local color1 = ImGui.ColorConvertDouble4ToU32(r1/255, g1/255, b1/255, 1)
    local color2 = ImGui.ColorConvertDouble4ToU32(r2/255, g2/255, b2/255, 1)

    -- Outer points
    local x1_out = center_x + cos(angle1) * outer_radius
    local y1_out = center_y + sin(angle1) * outer_radius
    local x2_out = center_x + cos(angle2) * outer_radius
    local y2_out = center_y + sin(angle2) * outer_radius

    -- Inner points
    local x1_in = center_x + cos(angle1) * inner_radius
    local y1_in = center_y + sin(angle1) * inner_radius
    local x2_in = center_x + cos(angle2) * inner_radius
    local y2_in = center_y + sin(angle2) * inner_radius

    -- Draw quad for this segment
    ImGui.DrawList_AddQuadFilled(draw_list, x1_out, y1_out, x2_out, y2_out, x2_in, y2_in, x1_in, y1_in, color1)
  end

  -- Draw black outline around hue wheel
  ImGui.DrawList_AddCircle(draw_list, center_x, center_y, outer_radius, 0x000000FF, segments, 2)
  ImGui.DrawList_AddCircle(draw_list, center_x, center_y, inner_radius, 0x000000FF, segments, 2)

  -- Calculate triangle points based on current hue
  local hue_angle = h * 2 * pi - pi / 2
  local tri_radius = inner_radius - 8

  local top_x = center_x + cos(hue_angle) * tri_radius
  local top_y = center_y + sin(hue_angle) * tri_radius

  local bot_left_angle = hue_angle + 2 * pi / 3
  local bot_left_x = center_x + cos(bot_left_angle) * tri_radius
  local bot_left_y = center_y + sin(bot_left_angle) * tri_radius

  local bot_right_angle = hue_angle - 2 * pi / 3
  local bot_right_x = center_x + cos(bot_right_angle) * tri_radius
  local bot_right_y = center_y + sin(bot_right_angle) * tri_radius

  -- Draw SV triangle with gradient
  local r_pure, g_pure, b_pure = hsv_to_rgb(h, 1, 1)
  local color_pure = ImGui.ColorConvertDouble4ToU32(r_pure/255, g_pure/255, b_pure/255, 1)
  local color_white = 0xFFFFFFFF
  local color_black = 0x000000FF

  -- Draw triangle with vertex colors
  ImGui.DrawList_AddTriangleFilled(draw_list, top_x, top_y, bot_left_x, bot_left_y, bot_right_x, bot_right_y, color_pure)

  -- Draw gradients (approximate with multiple triangles)
  local steps = 20
  for i = 0, steps do
    local t = i / steps
    local mid_x = bot_left_x + (bot_right_x - bot_left_x) * t
    local mid_y = bot_left_y + (bot_right_y - bot_left_y) * t

    -- Gradient from pure color at top to black at bottom
    local r_grad = r_pure * (1 - t)
    local g_grad = g_pure * (1 - t)
    local b_grad = b_pure * (1 - t)
    local col_grad = ImGui.ColorConvertDouble4ToU32(r_grad/255, g_grad/255, b_grad/255, 1)

    if i < steps then
      local next_t = (i + 1) / steps
      local next_mid_x = bot_left_x + (bot_right_x - bot_left_x) * next_t
      local next_mid_y = bot_left_y + (bot_right_y - bot_left_y) * next_t

      local r_next = r_pure * (1 - next_t)
      local g_next = g_pure * (1 - next_t)
      local b_next = b_pure * (1 - next_t)
      local col_next = ImGui.ColorConvertDouble4ToU32(r_next/255, g_next/255, b_next/255, 1)

      ImGui.DrawList_AddQuadFilled(draw_list, top_x, top_y, mid_x, mid_y, next_mid_x, next_mid_y, top_x, top_y, col_grad)
    end
  end

  -- Draw black border around triangle
  ImGui.DrawList_AddTriangle(draw_list, top_x, top_y, bot_left_x, bot_left_y, bot_right_x, bot_right_y, 0x000000FF, 3)

  -- Draw current selection point
  local sel_x = top_x + (bot_left_x - top_x) * (1 - v) + (bot_right_x - top_x) * s * (1 - v)
  local sel_y = top_y + (bot_left_y - top_y) * (1 - v) + (bot_right_y - top_y) * s * (1 - v)

  ImGui.DrawList_AddCircleFilled(draw_list, sel_x, sel_y, 5, 0xFFFFFFFF)
  ImGui.DrawList_AddCircle(draw_list, sel_x, sel_y, 5, 0x000000FF, 0, 2)

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, cx, cy)
  ImGui.InvisibleButton(ctx, "color_picker", size, size)

  -- Handle mouse interaction
  if ImGui.IsItemActive(ctx) then
    local mx, my = ImGui.GetMousePos(ctx)
    local dx = mx - center_x
    local dy = my - center_y
    local dist = sqrt(dx * dx + dy * dy)

    -- Check if clicking in hue wheel
    if dist >= inner_radius and dist <= outer_radius then
      local angle = atan(dy, dx)
      h = (angle + pi / 2) / (2 * pi)
      if h < 0 then h = h + 1 end
      if h > 1 then h = h - 1 end
      changed = true
    end

    -- Check if clicking in SV triangle
    if point_in_triangle(mx, my, top_x, top_y, bot_left_x, bot_left_y, bot_right_x, bot_right_y) then
      -- Calculate barycentric coordinates
      local v0x, v0y = bot_right_x - top_x, bot_right_y - top_y
      local v1x, v1y = bot_left_x - top_x, bot_left_y - top_y
      local v2x, v2y = mx - top_x, my - top_y

      local d00 = v0x * v0x + v0y * v0y
      local d01 = v0x * v1x + v0y * v1y
      local d11 = v1x * v1x + v1y * v1y
      local d20 = v2x * v0x + v2y * v0y
      local d21 = v2x * v1x + v2y * v1y

      local denom = d00 * d11 - d01 * d01
      if denom ~= 0 then
        s = max(0, min(1, (d11 * d20 - d01 * d21) / denom))
        local t = max(0, min(1, (d00 * d21 - d01 * d20) / denom))
        v = 1 - t
        changed = true
      end
    end
  end

  return changed, h, s, v
end

return M
