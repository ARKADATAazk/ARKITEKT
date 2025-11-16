-- @noindex
-- ReArkitekt/gui/rendering/shapes.lua
-- Shape rendering utilities for UI elements

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}

-- Draw a filled star shape
-- @param dl DrawList
-- @param cx Center X
-- @param cy Center Y
-- @param outer_radius Outer radius of the star
-- @param inner_radius Inner radius of the star (defaults to outer_radius * 0.4)
-- @param color Fill color (RGBA format)
-- @param points Number of star points (default 5)
function M.draw_star_filled(dl, cx, cy, outer_radius, inner_radius, color, points)
  points = points or 5
  inner_radius = inner_radius or (outer_radius * 0.4)

  ImGui.DrawList_PathClear(dl)

  local angle_step = (math.pi * 2) / points
  local half_step = angle_step / 2
  local start_angle = -math.pi / 2  -- Start from top

  -- Build star path
  for i = 0, points - 1 do
    local outer_angle = start_angle + (i * angle_step)
    local inner_angle = outer_angle + half_step

    -- Outer point
    local ox = cx + math.cos(outer_angle) * outer_radius
    local oy = cy + math.sin(outer_angle) * outer_radius
    ImGui.DrawList_PathLineTo(dl, ox, oy)

    -- Inner point
    local ix = cx + math.cos(inner_angle) * inner_radius
    local iy = cy + math.sin(inner_angle) * inner_radius
    ImGui.DrawList_PathLineTo(dl, ix, iy)
  end

  ImGui.DrawList_PathFillConvex(dl, color)
end

-- Draw a star outline
-- @param dl DrawList
-- @param cx Center X
-- @param cy Center Y
-- @param outer_radius Outer radius of the star
-- @param inner_radius Inner radius of the star (defaults to outer_radius * 0.4)
-- @param color Stroke color (RGBA format)
-- @param thickness Line thickness (default 1.0)
-- @param points Number of star points (default 5)
function M.draw_star_outline(dl, cx, cy, outer_radius, inner_radius, color, thickness, points)
  points = points or 5
  inner_radius = inner_radius or (outer_radius * 0.4)
  thickness = thickness or 1.0

  ImGui.DrawList_PathClear(dl)

  local angle_step = (math.pi * 2) / points
  local half_step = angle_step / 2
  local start_angle = -math.pi / 2  -- Start from top

  -- Build star path
  for i = 0, points - 1 do
    local outer_angle = start_angle + (i * angle_step)
    local inner_angle = outer_angle + half_step

    -- Outer point
    local ox = cx + math.cos(outer_angle) * outer_radius
    local oy = cy + math.sin(outer_angle) * outer_radius
    ImGui.DrawList_PathLineTo(dl, ox, oy)

    -- Inner point
    local ix = cx + math.cos(inner_angle) * inner_radius
    local iy = cy + math.sin(inner_angle) * inner_radius
    ImGui.DrawList_PathLineTo(dl, ix, iy)
  end

  -- Close the path
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness)
end

-- Draw a favorite star indicator with simple badge styling
-- @param dl DrawList
-- @param x X position (top-left of bounds)
-- @param y Y position (top-left of bounds)
-- @param size Size of the badge
-- @param alpha Overall alpha multiplier
-- @param is_favorite Whether the item is favorited
function M.draw_favorite_star(dl, x, y, size, alpha, is_favorite)
  alpha = alpha or 1.0

  if not is_favorite then
    return  -- Only draw if favorited
  end

  local padding = 3
  local badge_rounding = 3

  -- Badge background
  local bg_alpha = math.floor(alpha * 200)  -- Slightly transparent
  local bg_color = Colors.hexrgb("#14181C")  -- Dark background
  bg_color = Colors.with_alpha(bg_color, bg_alpha)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, badge_rounding)

  -- Badge border
  local border_alpha = math.floor(alpha * 100)
  local border_color = Colors.hexrgb("#2A2A2A")
  border_color = Colors.with_alpha(border_color, border_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_color, badge_rounding, 0, 1)

  -- Simple white star
  local cx = x + size / 2
  local cy = y + size / 2
  local star_size = (size - padding * 2) / 2
  local outer_radius = star_size
  local inner_radius = outer_radius * 0.38

  local star_alpha = math.floor(alpha * 255)
  local star_color = Colors.hexrgb("#FFFFFF")
  star_color = Colors.with_alpha(star_color, star_alpha)

  M.draw_star_filled(dl, cx, cy, outer_radius, inner_radius, star_color)
end

return M
