-- @noindex
-- panel/rendering.lua
-- Core panel rendering: backgrounds, borders, per-corner rounding

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- ============================================================================
-- PIXEL SNAPPING
-- ============================================================================

local function snap_pixel(v)
  return (v + 0.5) // 1
end

-- ============================================================================
-- PER-CORNER ROUNDED RECT (PATH-BASED)
-- ============================================================================

--- Draw a rectangle with per-corner rounding using ImGui path API
--- @param dl userdata ImGui draw list
--- @param x1 number Top-left X
--- @param y1 number Top-left Y
--- @param x2 number Bottom-right X
--- @param y2 number Bottom-right Y
--- @param color number RGBA color
--- @param filled boolean True for filled, false for stroke
--- @param rounding_tl number Top-left corner radius
--- @param rounding_tr number Top-right corner radius
--- @param rounding_br number Bottom-right corner radius
--- @param rounding_bl number Bottom-left corner radius
--- @param thickness number Stroke thickness (ignored if filled)
function M.draw_rounded_rect_path(dl, x1, y1, x2, y2, color, filled, rounding_tl, rounding_tr, rounding_br, rounding_bl, thickness)
  -- Snap to pixel boundaries for crisp rendering
  x1 = snap_pixel(x1)
  y1 = snap_pixel(y1)
  x2 = snap_pixel(x2)
  y2 = snap_pixel(y2)

  -- For 1px strokes, offset by 0.5 for perfect alignment
  if not filled and thickness == 1 then
    x1 = x1 + 0.5
    y1 = y1 + 0.5
    x2 = x2 - 0.5
    y2 = y2 - 0.5
  end

  -- Clamp rounding to maximum possible
  local w = x2 - x1
  local h = y2 - y1
  local max_rounding = math.min(w, h) * 0.5
  rounding_tl = math.min(rounding_tl or 0, max_rounding)
  rounding_tr = math.min(rounding_tr or 0, max_rounding)
  rounding_br = math.min(rounding_br or 0, max_rounding)
  rounding_bl = math.min(rounding_bl or 0, max_rounding)

  -- Calculate arc segments (more for larger radii)
  local function get_segments(r)
    if r <= 0 then return 0 end
    return math.max(4, (r * 0.6) // 1)
  end

  ImGui.DrawList_PathClear(dl)

  -- Top-left corner
  if rounding_tl > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rounding_tl, y1 + rounding_tl, rounding_tl,
                             math.pi, math.pi * 1.5, get_segments(rounding_tl))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y1)
  end

  -- Top-right corner
  if rounding_tr > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rounding_tr, y1 + rounding_tr, rounding_tr,
                             math.pi * 1.5, math.pi * 2.0, get_segments(rounding_tr))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y1)
  end

  -- Bottom-right corner
  if rounding_br > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rounding_br, y2 - rounding_br, rounding_br,
                             0, math.pi * 0.5, get_segments(rounding_br))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y2)
  end

  -- Bottom-left corner
  if rounding_bl > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rounding_bl, y2 - rounding_bl, rounding_bl,
                             math.pi * 0.5, math.pi, get_segments(rounding_bl))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y2)
  end

  if filled then
    ImGui.DrawList_PathFillConvex(dl, color)
  else
    ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness or 1)
  end
end

-- ============================================================================
-- PANEL BACKGROUND
-- ============================================================================

--- Draw panel background with uniform rounding
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param bg_color number Background color
--- @param rounding number Corner rounding
function M.draw_background(dl, x, y, w, h, bg_color, rounding)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, rounding)
end

-- ============================================================================
-- PANEL BORDER
-- ============================================================================

--- Draw panel border with uniform rounding
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param border_color number Border color
--- @param rounding number Corner rounding
--- @param thickness number Border thickness
function M.draw_border(dl, x, y, w, h, border_color, rounding, thickness)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, rounding, 0, thickness)
end

return M
