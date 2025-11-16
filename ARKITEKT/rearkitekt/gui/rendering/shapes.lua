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

-- Draw a favorite star indicator with Arkitekt styling
-- @param dl DrawList
-- @param x X position (top-left of bounds)
-- @param y Y position (top-left of bounds)
-- @param size Size of the star
-- @param base_color Base tile color for complementary styling
-- @param alpha Overall alpha multiplier
-- @param is_favorite Whether the item is favorited
-- @param hover_factor Hover animation factor (0.0 to 1.0)
function M.draw_favorite_star(dl, x, y, size, base_color, alpha, is_favorite, hover_factor)
  hover_factor = hover_factor or 0.0
  alpha = alpha or 1.0

  if not is_favorite and hover_factor < 0.1 then
    return  -- Don't draw if not favorite and not hovering
  end

  local cx = x + size / 2
  local cy = y + size / 2
  local outer_radius = size / 2
  local inner_radius = outer_radius * 0.38

  if is_favorite then
    -- Filled star for favorites
    -- Use a golden/yellow color with slight saturation from base color
    local fill_alpha = math.floor(alpha * 255)
    local star_color = Colors.hexrgb("#FFD700") -- Gold color
    star_color = Colors.with_alpha(star_color, fill_alpha)

    -- Subtle glow effect
    if hover_factor > 0.01 then
      local glow_size = outer_radius * (1.0 + hover_factor * 0.3)
      local glow_inner = glow_size * 0.38
      local glow_alpha = math.floor(alpha * hover_factor * 80)
      local glow_color = Colors.with_alpha(star_color, glow_alpha)
      M.draw_star_filled(dl, cx, cy, glow_size, glow_inner, glow_color)
    end

    -- Main star
    M.draw_star_filled(dl, cx, cy, outer_radius, inner_radius, star_color)

    -- Subtle darker outline for definition
    local outline_alpha = math.floor(alpha * 120)
    local outline_color = Colors.hexrgb("#CC9900")
    outline_color = Colors.with_alpha(outline_color, outline_alpha)
    M.draw_star_outline(dl, cx, cy, outer_radius, inner_radius, outline_color, 1.0)

  else
    -- Empty star outline for hover state (not favorited)
    if hover_factor > 0.1 then
      local outline_alpha = math.floor(alpha * hover_factor * 180)
      local outline_color = Colors.hexrgb("#FFFFFF")
      outline_color = Colors.with_alpha(outline_color, outline_alpha)
      M.draw_star_outline(dl, cx, cy, outer_radius, inner_radius, outline_color, 1.5)
    end
  end
end

return M
