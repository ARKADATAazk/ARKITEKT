-- @noindex
-- Arkitekt/gui/draw.lua
-- Drawing primitives and helpers
-- Crisp pixel-aligned rendering utilities

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')

-- Performance: Localize ImGui functions (significant in hot loops)
local DrawList_AddText = ImGui.DrawList_AddText
local DrawList_AddRect = ImGui.DrawList_AddRect
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddLine = ImGui.DrawList_AddLine
local DrawList_PushClipRect = ImGui.DrawList_PushClipRect
local DrawList_PopClipRect = ImGui.DrawList_PopClipRect
local CalcTextSize = ImGui.CalcTextSize
local GetWindowDrawList = ImGui.GetWindowDrawList

local M = {}

-- Snap to pixel boundary for crisp rendering
function M.Snap(x)
  return (x + 0.5)//1
end

-- Draw centered text within a rectangle
function M.CenteredText(ctx, text, x1, y1, x2, y2, color)
  local dl = GetWindowDrawList(ctx)
  local tw, th = CalcTextSize(ctx, text)
  local cx = x1 + ((x2 - x1 - tw)//1 * 0.5)
  local cy = y1 + ((y2 - y1 - th)//1 * 0.5)
  DrawList_AddText(dl, cx, cy, color or 0xFFFFFFFF, text)
end

-- Draw a crisp rectangle (pixel-aligned)
function M.Rect(dl, x1, y1, x2, y2, color, rounding, thickness)
  x1 = (x1 + 0.5)//1
  y1 = (y1 + 0.5)//1
  x2 = (x2 + 0.5)//1
  y2 = (y2 + 0.5)//1
  thickness = thickness or 1
  rounding = rounding or 0

  -- Offset by 0.5 for crisp 1px lines
  if thickness == 1 then
    DrawList_AddRect(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5,
                     color, rounding, 0, thickness)
  else
    DrawList_AddRect(dl, x1, y1, x2, y2, color, rounding, 0, thickness)
  end
end

-- Draw a filled rectangle (pixel-aligned)
function M.RectFilled(dl, x1, y1, x2, y2, color, rounding)
  DrawList_AddRectFilled(dl, (x1 + 0.5)//1, (y1 + 0.5)//1, (x2 + 0.5)//1, (y2 + 0.5)//1, color, rounding or 0)
end

-- Draw a crisp line (pixel-aligned)
function M.Line(dl, x1, y1, x2, y2, color, thickness)
  DrawList_AddLine(dl, (x1 + 0.5)//1, (y1 + 0.5)//1, (x2 + 0.5)//1, (y2 + 0.5)//1, color, thickness or 1)
end

-- Draw left-aligned text (hot path - inlined snap)
function M.Text(dl, x, y, color, text)
  DrawList_AddText(dl, (x + 0.5)//1, (y + 0.5)//1, color, text or '')
end

-- Draw right-aligned text
function M.TextRight(ctx, x, y, color, text)
  local dl = GetWindowDrawList(ctx)
  local tw = CalcTextSize(ctx, text)
  DrawList_AddText(dl, ((x - tw) + 0.5)//1, (y + 0.5)//1, color, text or '')
end

-- Check if point is in rectangle
function M.PointInRect(x, y, x1, y1, x2, y2)
  return x >= min(x1, x2) and x <= max(x1, x2)
     and y >= min(y1, y2) and y <= max(y1, y2)
end

-- Check if rectangles intersect
function M.RectsIntersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
  local a_left = min(ax1, ax2)
  local a_right = max(ax1, ax2)
  local a_top = min(ay1, ay2)
  local a_bottom = max(ay1, ay2)

  local b_left = min(bx1, bx2)
  local b_right = max(bx1, bx2)
  local b_top = min(by1, by2)
  local b_bottom = max(by1, by2)

  return not (a_left > b_right or a_right < b_left or
              a_top > b_bottom or a_bottom < b_top)
end

-- Create a clipped text helper (for tab labels etc)
function M.TextClipped(ctx, text, x, y, max_width, color)
  local dl = GetWindowDrawList(ctx)
  local tw, th = CalcTextSize(ctx, text)
  local snap_x = (x + 0.5)//1
  local snap_y = (y + 0.5)//1

  if tw <= max_width then
    -- Text fits, no clipping needed
    DrawList_AddText(dl, snap_x, snap_y, color, text)
  else
    -- Clip text
    local clip_x2 = ((x + max_width) + 0.5)//1
    DrawList_PushClipRect(dl, snap_x, y - 2, clip_x2, y + th + 2, true)
    DrawList_AddText(dl, snap_x, snap_y, color, text)
    DrawList_PopClipRect(dl)
  end
end

return M
