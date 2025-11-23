-- @noindex
-- Arkitekt/gui/fx/marching_ants.lua
-- Animated marching ants selection border (optimized with polylines)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Performance: Localize math functions
local cos = math.cos
local sin = math.sin
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min
local sqrt = math.sqrt

-- Add arc points to a points array (for polyline batching)
local function add_arc_points(points, cx, cy, r, a0, a1)
  local steps = max(1, floor((r * abs(a1 - a0)) / 3))
  for i = 0, steps do
    local ang = a0 + (a1 - a0) * (i / steps)
    points[#points + 1] = cx + r * cos(ang)
    points[#points + 1] = cy + r * sin(ang)
  end
end

-- Collect points for a dash segment and draw with single polyline
local function draw_path_segment(dl, x1, y1, x2, y2, r, s, e, color, thickness)
  local w, h = x2 - x1, y2 - y1
  local straight_w = max(0, w - 2*r)
  local straight_h = max(0, h - 2*r)
  local arc_len = (math.pi * r) / 2

  local segments = {
    {type='line', x1=x1+r, y1=y1,   x2=x2-r, y2=y1,   len=straight_w},  -- Top
    {type='arc',  cx=x2-r, cy=y1+r, a0=-math.pi/2, a1=0, len=arc_len},   -- TR corner
    {type='line', x1=x2,   y1=y1+r, x2=x2,   y2=y2-r, len=straight_h},  -- Right
    {type='arc',  cx=x2-r, cy=y2-r, a0=0, a1=math.pi/2, len=arc_len},     -- BR corner
    {type='line', x1=x2-r, y1=y2,   x2=x1+r, y2=y2,   len=straight_w},  -- Bottom
    {type='arc',  cx=x1+r, cy=y2-r, a0=math.pi/2, a1=math.pi, len=arc_len}, -- BL corner
    {type='line', x1=x1,   y1=y2-r, x2=x1,   y2=y1+r, len=straight_h},  -- Left
    {type='arc',  cx=x1+r, cy=y1+r, a0=math.pi, a1=3*math.pi/2, len=arc_len}, -- TL corner
  }

  -- Collect all points for this dash into a single array
  local points = {}
  local pos = 0

  for _, seg in ipairs(segments) do
    if seg.len > 0 and e > pos and s < pos + seg.len then
      local u0 = max(0, s - pos)
      local u1 = min(seg.len, e - pos)

      if seg.type == 'line' then
        local seg_len = max(1e-6, sqrt((seg.x2-seg.x1)^2 + (seg.y2-seg.y1)^2))
        local t0, t1 = u0/seg_len, u1/seg_len
        -- Add start point (only if this is the first point)
        if #points == 0 then
          points[#points + 1] = seg.x1 + (seg.x2-seg.x1)*t0
          points[#points + 1] = seg.y1 + (seg.y2-seg.y1)*t0
        end
        -- Add end point
        points[#points + 1] = seg.x1 + (seg.x2-seg.x1)*t1
        points[#points + 1] = seg.y1 + (seg.y2-seg.y1)*t1
      else -- arc
        local seg_len = max(1e-6, r * abs(seg.a1 - seg.a0))
        local aa0 = seg.a0 + (seg.a1 - seg.a0) * (u0 / seg_len)
        local aa1 = seg.a0 + (seg.a1 - seg.a0) * (u1 / seg_len)
        -- Skip first point if we already have points (avoid duplicates)
        local start_i = (#points == 0) and 0 or 1
        local steps = max(1, floor((r * abs(aa1 - aa0)) / 3))
        for i = start_i, steps do
          local ang = aa0 + (aa1 - aa0) * (i / steps)
          points[#points + 1] = seg.cx + r * cos(ang)
          points[#points + 1] = seg.cy + r * sin(ang)
        end
      end
    end
    pos = pos + seg.len
  end

  -- Draw all collected points with a single polyline call
  if #points >= 4 then
    local points_arr = reaper.new_array(points)
    ImGui.DrawList_AddPolyline(dl, points_arr, color, ImGui.DrawFlags_None, thickness)
  end

  return pos
end

function M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)
  if x2 <= x1 or y2 <= y1 then return end

  thickness = thickness or 1
  radius = radius or 6
  dash = max(2, dash or 8)
  gap = max(2, gap or 6)
  speed_px = speed_px or 20

  local w, h = x2 - x1, y2 - y1
  local r = max(0, min(radius, floor(min(w, h) * 0.5)))

  local straight_w = max(0, w - 2*r)
  local straight_h = max(0, h - 2*r)
  local arc_len = (math.pi * r) / 2
  local perimeter = 2 * (straight_w + straight_h + 2 * arc_len)

  if perimeter <= 0 then return end

  local period = dash + gap
  local phase = (reaper.time_precise() * speed_px) % period

  local s = -phase
  while s < perimeter do
    local e = min(perimeter, s + dash)
    if e > max(0, s) then
      draw_path_segment(dl, x1, y1, x2, y2, r, max(0, s), e, color, thickness)
    end
    s = s + period
  end
end

return M