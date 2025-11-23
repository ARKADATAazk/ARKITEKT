-- @noindex
-- Arkitekt/gui/widgets/nodal/core/connection.lua
-- Connection data structure with Manhattan routing

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

function M.new(opts)
  return {
    guid = opts.guid or reaper.genGuid(),
    type = opts.type,
    source_node = opts.source_node,
    target_node = opts.target_node,
    
    event_name = opts.event_name,
    jump_mode = opts.jump_mode,
    
    color = opts.color,
    animated = opts.animated or false,
    
    hovered = false,
  }
end

function M.new_sequential(source_guid, target_guid, color)
  return M.new({
    type = "sequential",
    source_node = source_guid,
    target_node = target_guid,
    color = color or hexrgb("#88CEFF"),
    animated = false,
  })
end

function M.new_trigger(source_guid, target_guid, event_name, jump_mode, color)
  return M.new({
    type = "trigger",
    source_node = source_guid,
    target_node = target_guid,
    event_name = event_name,
    jump_mode = jump_mode or "INCREMENTAL",
    color = color or hexrgb("#FF6B9D"),
    animated = false,
  })
end

-- Manhattan routing: creates orthogonal path (horizontal + vertical lines)
-- Path: Start → Right → Vertical → Horizontal → Down into Target
function M.get_manhattan_points(connection, nodes, config)
  local source = nil
  local target = nil
  
  for _, node in ipairs(nodes) do
    if node.guid == connection.source_node then
      source = node
    end
    if node.guid == connection.target_node then
      target = node
    end
  end
  
  if not source or not target then
    return nil
  end
  
  local x1, y1, x2, y2
  
  if connection.type == "sequential" then
    -- Sequential: bottom center to top center (simple vertical line)
    x1 = source.x + source.width / 2
    y1 = source.y + source.height
    
    x2 = target.x + target.width / 2
    y2 = target.y
    
    return {x1, y1, x2, y2}
  else
    -- Trigger connection: Manhattan routing
    local source_port = M.find_trigger_port(source, connection.event_name)
    if not source_port then
      return nil
    end
    
    -- Start point: right side port
    x1 = source_port.x
    y1 = source_port.y
    
    -- End point: top center of target
    x2 = target.x + target.width / 2
    y2 = target.y
    
    -- Calculate Manhattan path using config values
    local horizontal_offset = config.connection.manhattan_horizontal_offset or 40
    local approach_offset = config.connection.manhattan_approach_offset or 20
    local points = {}

    -- Point 1: Start at port
    points[#points + 1] = x1
    points[#points + 1] = y1

    -- Point 2: Go right from port
    local turn_x = x1 + horizontal_offset
    points[#points + 1] = turn_x
    points[#points + 1] = y1

    -- Point 3: Go vertical to target level (with some space above)
    local approach_y = y2 - approach_offset
    points[#points + 1] = turn_x
    points[#points + 1] = approach_y

    -- Point 4: Go horizontal to target x position
    points[#points + 1] = x2
    points[#points + 1] = approach_y

    -- Point 5: Go down into target
    points[#points + 1] = x2
    points[#points + 1] = y2

    return points
  end
end

function M.find_trigger_port(node, event_name)
  for _, port in ipairs(node.ports.triggers) do
    if port.event_name == event_name then
      return port
    end
  end
  return nil
end

-- Hover detection for Manhattan routing (line segments)
function M.is_point_on_line(connection, nodes, config, mx, my)
  local points = M.get_manhattan_points(connection, nodes, config)
  if not points or #points < 4 then
    return false
  end
  
  local threshold = 8  -- Hover distance threshold
  
  -- Check each line segment
  for i = 1, #points - 2, 2 do
    local x1, y1 = points[i], points[i + 1]
    local x2, y2 = points[i + 2], points[i + 3]
    
    -- Check if point is near this line segment
    if M.is_point_near_segment(mx, my, x1, y1, x2, y2, threshold) then
      return true
    end
  end
  
  return false
end

-- Helper: Check if point is near a line segment
function M.is_point_near_segment(px, py, x1, y1, x2, y2, threshold)
  -- Calculate distance from point to line segment
  local dx = x2 - x1
  local dy = y2 - y1
  local length_sq = dx * dx + dy * dy
  
  if length_sq == 0 then
    -- Line segment is a point
    local dist_sq = (px - x1) * (px - x1) + (py - y1) * (py - y1)
    return dist_sq <= threshold * threshold
  end
  
  -- Calculate projection factor
  local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / length_sq))
  
  -- Calculate closest point on segment
  local closest_x = x1 + t * dx
  local closest_y = y1 + t * dy
  
  -- Calculate distance
  local dist_sq = (px - closest_x) * (px - closest_x) + (py - closest_y) * (py - closest_y)
  
  return dist_sq <= threshold * threshold
end

-- Keep old bezier function for backwards compatibility
function M.get_bezier_points(connection, nodes, config)
  local source = nil
  local target = nil
  
  for _, node in ipairs(nodes) do
    if node.guid == connection.source_node then
      source = node
    end
    if node.guid == connection.target_node then
      target = node
    end
  end
  
  if not source or not target then
    return nil
  end
  
  local x1, y1, x2, y2
  
  if connection.type == "sequential" then
    x1 = source.x + source.width / 2
    y1 = source.y + source.height
    
    x2 = target.x + target.width / 2
    y2 = target.y
  else
    local source_port = M.find_trigger_port(source, connection.event_name)
    if not source_port then
      return nil
    end
    
    x1 = source_port.x
    y1 = source_port.y
    
    x2 = target.x + target.width / 2
    y2 = target.y
  end
  
  local distance = math.abs(y2 - y1)
  local control_offset = distance * config.connection.control_distance_factor
  
  local cx1 = x1
  local cy1 = y1 + control_offset
  
  local cx2 = x2
  local cy2 = y2 - control_offset
  
  return x1, y1, cx1, cy1, cx2, cy2, x2, y2
end

return M