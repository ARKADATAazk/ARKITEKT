-- @noindex
-- ThemeAdjuster/ui/grids/renderers/tile_visuals.lua
-- Shared visual effects for tiles (marching ants, hover, selection)

local ImGui = require 'imgui' '0.10'

local M = {}

-- Marching ants animation for selection
function M.draw_marching_ants_rounded(dl, x1, y1, x2, y2, col, thick, radius)
  if x2 <= x1 or y2 <= y1 then return end

  local w, h = x2 - x1, y2 - y1
  local r = math.max(0, math.min(radius or 3, math.floor(math.min(w, h) * 0.5)))

  -- Calculate perimeter segments
  local straight_w = math.max(0, w - 2*r)
  local straight_h = math.max(0, h - 2*r)
  local arc_len = (math.pi * r) / 2
  local total_len = straight_w + arc_len + straight_h + arc_len + straight_w + arc_len + straight_h + arc_len

  if total_len <= 0 then return end

  -- Helper to draw line segment
  local function line(ax, ay, bx, by, u0, u1)
    local seg = math.max(1e-6, ((bx-ax)^2 + (by-ay)^2)^0.5)
    local t0, t1 = u0/seg, u1/seg
    local sx, sy = ax + (bx-ax)*t0, ay + (by-ay)*t0
    local ex, ey = ax + (bx-ax)*t1, ay + (by-ay)*t1
    ImGui.DrawList_AddLine(dl, sx, sy, ex, ey, col, thick)
  end

  -- Helper to draw arc segment
  local function arc(cx, cy, rr, a0, a1, u0, u1)
    local seg = math.max(1e-6, rr * math.abs(a1 - a0))
    local aa0 = a0 + (a1 - a0) * (u0/seg)
    local aa1 = a0 + (a1 - a0) * (u1/seg)
    local steps = math.max(1, math.floor((rr * math.abs(aa1 - aa0)) / 3))
    local px, py = cx + rr * math.cos(aa0), cy + rr * math.sin(aa0)
    for i = 1, steps do
      local t = i / steps
      local ang = aa0 + (aa1 - aa0) * t
      local nx, ny = cx + rr * math.cos(ang), cy + rr * math.sin(ang)
      ImGui.DrawList_AddLine(dl, px, py, nx, ny, col, thick)
      px, py = nx, ny
    end
  end

  -- Animation
  local dash_len = 8
  local gap_len = 6
  local period = dash_len + gap_len
  local speed = 20  -- pixels per second
  local phase_px = (reaper.time_precise() * speed) % period

  -- Draw perimeter path with dashes
  local function subpath(s, e)
    local pos = 0

    -- Top edge
    if e > pos and s < pos + straight_w and straight_w > 0 then
      line(x1+r, y1, x2-r, y1, math.max(0, s-pos), math.min(straight_w, e-pos))
    end
    pos = pos + straight_w

    -- Top-right corner
    if e > pos and s < pos + arc_len and arc_len > 0 then
      arc(x2-r, y1+r, r, -math.pi/2, 0, math.max(0, s-pos), math.min(arc_len, e-pos))
    end
    pos = pos + arc_len

    -- Right edge
    if e > pos and s < pos + straight_h and straight_h > 0 then
      line(x2, y1+r, x2, y2-r, math.max(0, s-pos), math.min(straight_h, e-pos))
    end
    pos = pos + straight_h

    -- Bottom-right corner
    if e > pos and s < pos + arc_len and arc_len > 0 then
      arc(x2-r, y2-r, r, 0, math.pi/2, math.max(0, s-pos), math.min(arc_len, e-pos))
    end
    pos = pos + arc_len

    -- Bottom edge
    if e > pos and s < pos + straight_w and straight_w > 0 then
      line(x2-r, y2, x1+r, y2, math.max(0, s-pos), math.min(straight_w, e-pos))
    end
    pos = pos + straight_w

    -- Bottom-left corner
    if e > pos and s < pos + arc_len and arc_len > 0 then
      arc(x1+r, y2-r, r, math.pi/2, math.pi, math.max(0, s-pos), math.min(arc_len, e-pos))
    end
    pos = pos + arc_len

    -- Left edge
    if e > pos and s < pos + straight_h and straight_h > 0 then
      line(x1, y2-r, x1, y1+r, math.max(0, s-pos), math.min(straight_h, e-pos))
    end
    pos = pos + straight_h

    -- Top-left corner
    if e > pos and s < pos + arc_len and arc_len > 0 then
      arc(x1+r, y1+r, r, math.pi, 3*math.pi/2, math.max(0, s-pos), math.min(arc_len, e-pos))
    end
  end

  -- Draw all dashes
  local s = -phase_px
  while s < total_len do
    local e = s + dash_len
    local cs, ce = math.max(0, s), math.min(total_len, e)
    if ce > cs then
      subpath(cs, ce)
    end
    s = s + period
  end
end

-- Draw hover shadow effect
function M.draw_hover_shadow(dl, x1, y1, x2, y2, hover_alpha, rounding)
  if hover_alpha <= 0.01 then return end

  local alpha = math.floor(hover_alpha * 20)
  local shadow = (0x000000 << 8) | alpha

  -- Draw layered shadow
  for i = 2, 1, -1 do
    ImGui.DrawList_AddRectFilled(dl, x1 - i, y1 - i + 2, x2 + i, y2 + i + 2, shadow, rounding)
  end
end

-- Color lerp helper
function M.color_lerp(c1, c2, t)
  t = math.min(1.0, math.max(0.0, t))

  local function rgba(c)
    return (c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF
  end

  local r1, g1, b1, a1 = rgba(c1)
  local r2, g2, b2, a2 = rgba(c2)

  local r = math.floor(r1 + (r2 - r1) * t)
  local g = math.floor(g1 + (g2 - g1) * t)
  local b = math.floor(b1 + (b2 - b1) * t)
  local a = math.floor(a1 + (a2 - a1) * t)

  return (r << 24) | (g << 16) | (b << 8) | a
end

-- Lerp helper
function M.lerp(a, b, t)
  return a + (b - a) * math.min(1.0, t)
end

return M
