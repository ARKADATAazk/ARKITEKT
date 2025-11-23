-- @noindex
-- Arkitekt/gui/widgets/nodal/systems/bezier.lua
-- Bezier curve utilities (simplified from Sexan's path2d system)

local M = {}

function M.cubic_bezier_point(t, x1, y1, cx1, cy1, cx2, cy2, x2, y2)
  local mt = 1 - t
  local mt2 = mt * mt
  local mt3 = mt2 * mt
  local t2 = t * t
  local t3 = t2 * t
  
  local x = mt3 * x1 + 3 * mt2 * t * cx1 + 3 * mt * t2 * cx2 + t3 * x2
  local y = mt3 * y1 + 3 * mt2 * t * cy1 + 3 * mt * t2 * cy2 + t3 * y2
  
  return x, y
end

function M.get_bezier_bounding_box(x1, y1, cx1, cy1, cx2, cy2, x2, y2, padding)
  padding = padding or 0
  
  local min_x = math.min(x1, cx1, cx2, x2)
  local max_x = math.max(x1, cx1, cx2, x2)
  local min_y = math.min(y1, cy1, cy2, y2)
  local max_y = math.max(y1, cy1, cy2, y2)
  
  return min_x - padding, min_y - padding,
         max_x - min_x + padding * 2, max_y - min_y + padding * 2
end

function M.distance_to_bezier(mx, my, x1, y1, cx1, cy1, cx2, cy2, x2, y2, segments)
  segments = segments or 20
  local min_dist_sq = math.huge
  
  for i = 0, segments do
    local t = i / segments
    local px, py = M.cubic_bezier_point(t, x1, y1, cx1, cy1, cx2, cy2, x2, y2)
    
    local dx = mx - px
    local dy = my - py
    local dist_sq = dx * dx + dy * dy
    
    if dist_sq < min_dist_sq then
      min_dist_sq = dist_sq
    end
  end
  
  return math.sqrt(min_dist_sq)
end

function M.split_bezier(t, x1, y1, cx1, cy1, cx2, cy2, x2, y2)
  local mt = 1 - t
  
  local x12 = x1 * mt + cx1 * t
  local y12 = y1 * mt + cy1 * t
  
  local x23 = cx1 * mt + cx2 * t
  local y23 = cy1 * mt + cy2 * t
  
  local x34 = cx2 * mt + x2 * t
  local y34 = cy2 * mt + y2 * t
  
  local x123 = x12 * mt + x23 * t
  local y123 = y12 * mt + y23 * t
  
  local x234 = x23 * mt + x34 * t
  local y234 = y23 * mt + y34 * t
  
  local x1234 = x123 * mt + x234 * t
  local y1234 = y123 * mt + y234 * t
  
  return x1, y1, x12, y12, x123, y123, x1234, y1234,
         x1234, y1234, x234, y234, x34, y34, x2, y2
end

return M