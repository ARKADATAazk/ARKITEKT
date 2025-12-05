-- @noindex
-- Arkitekt/gui/fx/marching_ants.lua
-- Animated marching ants selection border (optimized with polylines)

local ImGui = require('arkitekt.core.imgui')

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

-- Performance: Pre-allocated tables (reused to avoid GC pressure)
local _points_buffer = {}
local _edges_buffer = {
  { x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
}
local _segments_buffer = {
  { type = 'line', x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { type = 'arc', cx = 0, cy = 0, a0 = 0, a1 = 0, len = 0 },
  { type = 'line', x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { type = 'arc', cx = 0, cy = 0, a0 = 0, a1 = 0, len = 0 },
  { type = 'line', x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { type = 'arc', cx = 0, cy = 0, a0 = 0, a1 = 0, len = 0 },
  { type = 'line', x1 = 0, y1 = 0, x2 = 0, y2 = 0, len = 0 },
  { type = 'arc', cx = 0, cy = 0, a0 = 0, a1 = 0, len = 0 },
}

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
  local pi = math.pi

  -- Reuse pre-allocated segments buffer (update values in-place)
  local segments = _segments_buffer
  -- Top line
  segments[1].x1 = x1+r; segments[1].y1 = y1; segments[1].x2 = x2-r; segments[1].y2 = y1; segments[1].len = straight_w
  -- TR arc
  segments[2].cx = x2-r; segments[2].cy = y1+r; segments[2].a0 = -pi/2; segments[2].a1 = 0; segments[2].len = arc_len
  -- Right line
  segments[3].x1 = x2; segments[3].y1 = y1+r; segments[3].x2 = x2; segments[3].y2 = y2-r; segments[3].len = straight_h
  -- BR arc
  segments[4].cx = x2-r; segments[4].cy = y2-r; segments[4].a0 = 0; segments[4].a1 = pi/2; segments[4].len = arc_len
  -- Bottom line
  segments[5].x1 = x2-r; segments[5].y1 = y2; segments[5].x2 = x1+r; segments[5].y2 = y2; segments[5].len = straight_w
  -- BL arc
  segments[6].cx = x1+r; segments[6].cy = y2-r; segments[6].a0 = pi/2; segments[6].a1 = pi; segments[6].len = arc_len
  -- Left line
  segments[7].x1 = x1; segments[7].y1 = y2-r; segments[7].x2 = x1; segments[7].y2 = y1+r; segments[7].len = straight_h
  -- TL arc
  segments[8].cx = x1+r; segments[8].cy = y1+r; segments[8].a0 = pi; segments[8].a1 = 3*pi/2; segments[8].len = arc_len

  -- Collect all points for this dash into reused buffer
  local points = _points_buffer
  local point_count = 0
  local pos = 0

  for idx = 1, 8 do
    local seg = segments[idx]
    if seg.len > 0 and e > pos and s < pos + seg.len then
      local u0 = max(0, s - pos)
      local u1 = min(seg.len, e - pos)

      if seg.type == 'line' then
        local seg_len = max(1e-6, sqrt((seg.x2-seg.x1)^2 + (seg.y2-seg.y1)^2))
        local t0, t1 = u0/seg_len, u1/seg_len
        -- Add start point (only if this is the first point)
        if point_count == 0 then
          point_count = point_count + 1; points[point_count] = seg.x1 + (seg.x2-seg.x1)*t0
          point_count = point_count + 1; points[point_count] = seg.y1 + (seg.y2-seg.y1)*t0
        end
        -- Add end point
        point_count = point_count + 1; points[point_count] = seg.x1 + (seg.x2-seg.x1)*t1
        point_count = point_count + 1; points[point_count] = seg.y1 + (seg.y2-seg.y1)*t1
      else -- arc
        local seg_len = max(1e-6, r * abs(seg.a1 - seg.a0))
        local aa0 = seg.a0 + (seg.a1 - seg.a0) * (u0 / seg_len)
        local aa1 = seg.a0 + (seg.a1 - seg.a0) * (u1 / seg_len)
        -- Skip first point if we already have points (avoid duplicates)
        local start_i = (point_count == 0) and 0 or 1
        local steps = max(1, floor((r * abs(aa1 - aa0)) / (3 / quality_factor)))
        for i = start_i, steps do
          local ang = aa0 + (aa1 - aa0) * (i / steps)
          point_count = point_count + 1; points[point_count] = seg.cx + r * cos(ang)
          point_count = point_count + 1; points[point_count] = seg.cy + r * sin(ang)
        end
      end
    end
    pos = pos + seg.len
  end

  -- Draw all collected points with a single polyline call
  if point_count >= 4 then
    -- Truncate buffer to actual size and draw
    for i = point_count + 1, #points do points[i] = nil end
    local points_arr = reaper.new_array(points)
    ImGui.DrawList_AddPolyline(dl, points_arr, color, ImGui.DrawFlags_None, thickness)
  end

  return pos
end

function M.Draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px, selection_count)
  if x2 <= x1 or y2 <= y1 then return end

  thickness = thickness or 1
  radius = radius or 6
  dash = max(2, dash or 24)  -- Default: 3x sparser than old baseline (24px vs 8px)
  gap = max(2, gap or 11)    -- Default: larger gap for more spacing (11px vs original 6px)
  speed_px = speed_px or 30  -- Default: 50% faster for better visibility (30 vs original 20)
  selection_count = selection_count or 1

  -- LOD: Instant threshold-based sparsity for massive selections
  -- No lerp - instant changes at thresholds for cleaner logic
  if selection_count > 200 then
    -- 200+ items: 1.5x sparser (instant change at threshold)
    dash = dash * 1.5  -- 24px → 36px
    gap = gap * 1.5    -- 11px → 16.5px
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

    -- Reuse pre-allocated edges buffer (update values in-place)
    local edges = _edges_buffer
    edges[1].x1 = x1; edges[1].y1 = y1; edges[1].x2 = x2; edges[1].y2 = y1; edges[1].len = w  -- Top
    edges[2].x1 = x2; edges[2].y1 = y1; edges[2].x2 = x2; edges[2].y2 = y2; edges[2].len = h  -- Right
    edges[3].x1 = x2; edges[3].y1 = y2; edges[3].x2 = x1; edges[3].y2 = y2; edges[3].len = w  -- Bottom
    edges[4].x1 = x1; edges[4].y1 = y2; edges[4].x2 = x1; edges[4].y2 = y1; edges[4].len = h  -- Left

    -- Reuse points buffer
    local points = _points_buffer

    local s = -phase
    while s < perimeter do
      local e_pos = min(perimeter, s + dash)
      if e_pos > max(0, s) then
        -- Draw dash inline (avoid function call overhead)
        local dash_start, dash_end = max(0, s), e_pos
        local point_count = 0
        local pos = 0
        for idx = 1, 4 do
          local edge = edges[idx]
          if dash_end > pos and dash_start < pos + edge.len then
            local u0 = max(0, dash_start - pos) / edge.len
            local u1 = min(edge.len, dash_end - pos) / edge.len
            if point_count == 0 then
              point_count = point_count + 1; points[point_count] = edge.x1 + (edge.x2 - edge.x1) * u0
              point_count = point_count + 1; points[point_count] = edge.y1 + (edge.y2 - edge.y1) * u0
            end
            point_count = point_count + 1; points[point_count] = edge.x1 + (edge.x2 - edge.x1) * u1
            point_count = point_count + 1; points[point_count] = edge.y1 + (edge.y2 - edge.y1) * u1
          end
          pos = pos + edge.len
        end
        if point_count >= 4 then
          for i = point_count + 1, #points do points[i] = nil end
          local points_arr = reaper.new_array(points)
          ImGui.DrawList_AddPolyline(dl, points_arr, color, ImGui.DrawFlags_None, thickness)
        end
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