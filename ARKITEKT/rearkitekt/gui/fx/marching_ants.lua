-- @noindex
-- ReArkitekt/gui/fx/marching_ants.lua
-- Animated marching ants selection border (refactored to use draw.lua)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.9'
local Draw = require('rearkitekt.gui.draw')

local M = {}

local function draw_arc_segment(dl, cx, cy, r, a0, a1, color, thickness)
  local steps = math.max(1, math.floor((r * math.abs(a1 - a0)) / 3))
  local prevx = cx + r * math.cos(a0)
  local prevy = cy + r * math.sin(a0)
  for i = 1, steps do
    local ang = a0 + (a1 - a0) * (i / steps)
    local nx = cx + r * math.cos(ang)
    local ny = cy + r * math.sin(ang)
    Draw.line(dl, prevx, prevy, nx, ny, color, thickness)
    prevx, prevy = nx, ny
  end
end

local function draw_path_segment(dl, x1, y1, x2, y2, r, s, e, color, thickness)
  local w, h = x2 - x1, y2 - y1
  local straight_w = math.max(0, w - 2*r)
  local straight_h = math.max(0, h - 2*r)
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
  
  local pos = 0
  for _, seg in ipairs(segments) do
    if seg.len > 0 and e > pos and s < pos + seg.len then
      local u0 = math.max(0, s - pos)
      local u1 = math.min(seg.len, e - pos)
      
      if seg.type == 'line' then
        local seg_len = math.max(1e-6, math.sqrt((seg.x2-seg.x1)^2 + (seg.y2-seg.y1)^2))
        local t0, t1 = u0/seg_len, u1/seg_len
        local sx = seg.x1 + (seg.x2-seg.x1)*t0
        local sy = seg.y1 + (seg.y2-seg.y1)*t0
        local ex = seg.x1 + (seg.x2-seg.x1)*t1
        local ey = seg.y1 + (seg.y2-seg.y1)*t1
        Draw.line(dl, sx, sy, ex, ey, color, thickness)
      else -- arc
        local seg_len = math.max(1e-6, r * math.abs(seg.a1 - seg.a0))
        local aa0 = seg.a0 + (seg.a1 - seg.a0) * (u0 / seg_len)
        local aa1 = seg.a0 + (seg.a1 - seg.a0) * (u1 / seg_len)
        draw_arc_segment(dl, seg.cx, seg.cy, r, aa0, aa1, color, thickness)
      end
    end
    pos = pos + seg.len
  end
  
  return pos
end

function M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)
  if x2 <= x1 or y2 <= y1 then return end
  
  thickness = thickness or 1
  radius = radius or 6
  dash = math.max(2, dash or 8)
  gap = math.max(2, gap or 6)
  speed_px = speed_px or 20
  
  local w, h = x2 - x1, y2 - y1
  local r = math.max(0, math.min(radius, math.floor(math.min(w, h) * 0.5)))
  
  local straight_w = math.max(0, w - 2*r)
  local straight_h = math.max(0, h - 2*r)
  local arc_len = (math.pi * r) / 2
  local perimeter = 2 * (straight_w + straight_h + 2 * arc_len)
  
  if perimeter <= 0 then return end
  
  local period = dash + gap
  local phase = (reaper.time_precise() * speed_px) % period
  
  local s = -phase
  while s < perimeter do
    local e = math.min(perimeter, s + dash)
    if e > math.max(0, s) then
      draw_path_segment(dl, x1, y1, x2, y2, r, math.max(0, s), e, color, thickness)
    end
    s = s + period
  end
end

return M