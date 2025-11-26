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

-- Performance: Frame-level animation phase cache (batch time calculation)
local _phase_cache = { time = 0, value = 0 }

-- Add arc points to a points array (for polyline batching)
-- quality_factor: 1.0 = full quality, 0.5 = half points (faster)
local function add_arc_points(points, cx, cy, r, a0, a1, quality_factor)
  quality_factor = quality_factor or 1.0
  local steps = max(1, floor((r * abs(a1 - a0)) / (3 / quality_factor)))
  for i = 0, steps do
    local ang = a0 + (a1 - a0) * (i / steps)
    points[#points + 1] = cx + r * cos(ang)
    points[#points + 1] = cy + r * sin(ang)
  end
end

-- Collect points for a dash segment and draw with single polyline
local function draw_path_segment(dl, x1, y1, x2, y2, r, s, e, color, thickness, quality_factor)
  quality_factor = quality_factor or 1.0
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
        local steps = max(1, floor((r * abs(aa1 - aa0)) / (3 / quality_factor)))
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

function M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px, selection_count)
  if x2 <= x1 or y2 <= y1 then return end

  thickness = thickness or 1
  radius = radius or 6
  dash = max(2, dash or 24)  -- Default: 3x sparser than old baseline (24px vs 8px)
  gap = max(2, gap or 11)    -- Default: larger gap for more spacing (11px vs original 6px)
  speed_px = speed_px or 30  -- Default: 50% faster for better visibility (30 vs original 20)
  selection_count = selection_count or 1

  -- LOD: Smooth lerp for MASSIVE selections (200+) to avoid visible density jumps
  -- Base is already 3x sparser (24px dash, 11px gap from constants)
  if selection_count > 200 then
    -- Lerp from 1x to 1.5x between 200-300 items, cap at 1.5x
    local lerp_factor = min((selection_count - 200) / 100, 1.0)
    local sparsity_multiplier = 1.0 + (lerp_factor * 0.5)  -- 1.0 → 1.5x
    dash = dash * sparsity_multiplier  -- 24px → 36px at 300+
    gap = gap * sparsity_multiplier    -- 11px → 16.5px at 300+
  end

  -- Arc quality reduction: More aggressive for large selections
  local quality_factor = 1.0
  if selection_count > 150 then
    quality_factor = 0.25  -- Very aggressive: quarter of arc points for 150+ selections
  elseif selection_count > 75 then
    quality_factor = 0.5   -- Half the arc points for 75-150 selections
  elseif selection_count > 30 then
    quality_factor = 0.75  -- Slightly reduced for 30-75 selections
  end

  local w, h = x2 - x1, y2 - y1
  local r = max(0, min(radius, floor(min(w, h) * 0.5)))

  -- FAST PATH: No rounding (r=0) - skip all arc calculations
  if r <= 0 then
    local perimeter = 2 * (w + h)
    if perimeter <= 0 then return end

    local period = dash + gap

    -- Batch time calculation: Cache phase per frame
    local current_time = reaper.time_precise()
    local phase
    if _phase_cache.time ~= current_time then
      _phase_cache.time = current_time
      _phase_cache.value = (current_time * speed_px) % period
    end
    phase = _phase_cache.value

    -- Simple rectangular path: top, right, bottom, left
    local edges = {
      {x1=x1, y1=y1, x2=x2, y2=y1, len=w},     -- Top
      {x1=x2, y1=y1, x2=x2, y2=y2, len=h},     -- Right
      {x1=x2, y1=y2, x2=x1, y2=y2, len=w},     -- Bottom
      {x1=x1, y1=y2, x2=x1, y2=y1, len=h},     -- Left
    }

    -- Helper function to draw a dash segment
    local function draw_dash(dash_start, dash_end)
      local points = {}
      local pos = 0
      for _, edge in ipairs(edges) do
        if dash_end > pos and dash_start < pos + edge.len then
          local u0 = max(0, dash_start - pos) / edge.len
          local u1 = min(edge.len, dash_end - pos) / edge.len
          if #points == 0 then
            points[#points + 1] = edge.x1 + (edge.x2 - edge.x1) * u0
            points[#points + 1] = edge.y1 + (edge.y2 - edge.y1) * u0
          end
          points[#points + 1] = edge.x1 + (edge.x2 - edge.x1) * u1
          points[#points + 1] = edge.y1 + (edge.y2 - edge.y1) * u1
        end
        pos = pos + edge.len
      end
      if #points >= 4 then
        local points_arr = reaper.new_array(points)
        ImGui.DrawList_AddPolyline(dl, points_arr, color, ImGui.DrawFlags_None, thickness)
      end
    end

    local s = -phase
    while s < perimeter do
      local e = min(perimeter, s + dash)
      if e > max(0, s) then
        draw_dash(max(0, s), e)
      end
      s = s + period
    end
    return
  end

  -- NORMAL PATH: With rounding (r>0) - use arc segments
  local straight_w = max(0, w - 2*r)
  local straight_h = max(0, h - 2*r)
  local arc_len = (math.pi * r) / 2
  local perimeter = 2 * (straight_w + straight_h + 2 * arc_len)

  if perimeter <= 0 then return end

  local period = dash + gap

  -- Batch time calculation: Cache phase per frame (eliminates redundant time_precise calls)
  local current_time = reaper.time_precise()
  local phase
  if _phase_cache.time ~= current_time then
    _phase_cache.time = current_time
    _phase_cache.value = (current_time * speed_px) % period
  end
  phase = _phase_cache.value

  local s = -phase
  while s < perimeter do
    local e = min(perimeter, s + dash)
    if e > max(0, s) then
      draw_path_segment(dl, x1, y1, x2, y2, r, max(0, s), e, color, thickness, quality_factor)
    end
    s = s + period
  end
end

return M