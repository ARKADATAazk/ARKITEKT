-- @noindex
-- ReArkitekt/gui/rendering/shapes.lua
-- Shape rendering utilities for UI elements

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Badge = require('rearkitekt.gui.widgets.primitives.badge')

-- Cache math functions for performance
local cos, sin, pi = math.cos, math.sin, math.pi

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

  local angle_step = (pi * 2) / points
  local half_step = angle_step / 2
  local start_angle = -pi / 2  -- Start from top

  -- Build star path
  for i = 0, points - 1 do
    local outer_angle = start_angle + (i * angle_step)
    local inner_angle = outer_angle + half_step

    -- Outer point
    local ox = cx + cos(outer_angle) * outer_radius
    local oy = cy + sin(outer_angle) * outer_radius
    ImGui.DrawList_PathLineTo(dl, ox, oy)

    -- Inner point
    local ix = cx + cos(inner_angle) * inner_radius
    local iy = cy + sin(inner_angle) * inner_radius
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

  local angle_step = (pi * 2) / points
  local half_step = angle_step / 2
  local start_angle = -pi / 2  -- Start from top

  -- Build star path
  for i = 0, points - 1 do
    local outer_angle = start_angle + (i * angle_step)
    local inner_angle = outer_angle + half_step

    -- Outer point
    local ox = cx + cos(outer_angle) * outer_radius
    local oy = cy + sin(outer_angle) * outer_radius
    ImGui.DrawList_PathLineTo(dl, ox, oy)

    -- Inner point
    local ix = cx + cos(inner_angle) * inner_radius
    local iy = cy + sin(inner_angle) * inner_radius
    ImGui.DrawList_PathLineTo(dl, ix, iy)
  end

  -- Close the path
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness)
end

-- Draw a favorite star indicator using modular badge system
-- @param ctx ImGui context
-- @param dl DrawList
-- @param x X position (top-left of bounds)
-- @param y Y position (top-left of bounds)
-- @param size Size of the badge
-- @param alpha Overall alpha multiplier (0.0-1.0)
-- @param is_favorite Whether the item is favorited
-- @param icon_font Optional icon font to use (remixicon), falls back to Unicode star
-- @param icon_font_size Optional icon font size
-- @param base_color Optional base tile color for border derivation (defaults to neutral gray)
-- @param config Optional badge config overrides
function M.draw_favorite_star(ctx, dl, x, y, size, alpha, is_favorite, icon_font, icon_font_size, base_color, config)
  if not is_favorite then
    return  -- Only draw if favorited
  end

  -- Convert alpha from 0.0-1.0 to 0-255 for badge system
  local alpha_255 = math.floor(alpha * 255)

  -- Use remixicon star-fill if available, otherwise fallback to Unicode star
  local star_char
  if icon_font then
    -- Remixicon star-fill: U+F186
    star_char = utf8.char(0xF186)
  else
    -- Fallback to Unicode star character for cleaner rendering (no aliasing)
    star_char = "★"  -- U+2605 BLACK STAR
  end

  -- Default base color if not provided
  base_color = base_color or Colors.hexrgb("#555555")

  -- Render using modular badge system
  Badge.render_icon_badge(ctx, dl, x, y, size, star_char, base_color, alpha_255, icon_font, icon_font_size, config)
end

return M
