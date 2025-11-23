-- @noindex
-- Arkitekt/gui/widgets/nodal/systems/auto_layout.lua
-- Vertical auto-layout for nodes

local Node = require('arkitekt.gui.widgets.editors.nodal.core.node')

local M = {}

function M.calculate_vertical_layout(nodes, config, center_x)
  local y_offset = 50
  
  for i, node in ipairs(nodes) do
    node.x = center_x - node.width / 2
    node.y = y_offset
    
    node.height = Node.calculate_height(node, config)
    
    y_offset = y_offset + node.height + config.node.spacing
  end
  
  return y_offset
end

function M.calculate_container_layout(nodes, config, container_x, container_width)
  local y_offset = 50
  local padding = 10
  
  for i, node in ipairs(nodes) do
    node.width = container_width - (padding * 2)
    node.x = container_x + padding
    node.y = y_offset
    
    node.height = Node.calculate_height(node, config)
    
    y_offset = y_offset + node.height + config.node.spacing
  end
  
  return y_offset
end

function M.get_bounds(nodes)
  if #nodes == 0 then
    return 0, 0, 0, 0
  end
  
  local min_x = math.huge
  local min_y = math.huge
  local max_x = -math.huge
  local max_y = -math.huge
  
  local has_valid_node = false
  
  for _, node in ipairs(nodes) do
    if node.x and node.y and node.width and node.height then
      min_x = math.min(min_x, node.x)
      min_y = math.min(min_y, node.y)
      max_x = math.max(max_x, node.x + node.width)
      max_y = math.max(max_y, node.y + node.height)
      has_valid_node = true
    end
  end
  
  if not has_valid_node then
    return 0, 0, 0, 0
  end
  
  if min_x == math.huge or min_y == math.huge or 
     max_x == -math.huge or max_y == -math.huge then
    return 0, 0, 0, 0
  end
  
  return min_x, min_y, max_x - min_x, max_y - min_y
end

function M.center_in_view(nodes, view_x, view_y, view_w, view_h, config)
  local bounds_x, bounds_y, bounds_w, bounds_h = M.get_bounds(nodes)
  
  if not bounds_x or not bounds_y or not bounds_w or not bounds_h then
    return
  end
  
  if bounds_w == 0 or bounds_h == 0 then
    return
  end
  
  local target_center_x = view_x + view_w / 2
  local target_center_y = view_y + view_h / 2
  
  local bounds_center_x = bounds_x + bounds_w / 2
  local bounds_center_y = bounds_y + bounds_h / 2
  
  local offset_x = target_center_x - bounds_center_x
  local offset_y = target_center_y - bounds_center_y
  
  for _, node in ipairs(nodes) do
    if node.x and node.y then
      node.x = node.x + offset_x
      node.y = node.y + offset_y
    end
  end
end

return M