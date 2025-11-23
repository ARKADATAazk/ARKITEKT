-- @noindex
-- Arkitekt/gui/widgets/nodal/core/port.lua
-- Port widget for connections (merged with renderer)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

function M.new(opts)
  return {
    type = opts.type,
    direction = opts.direction,
    event_name = opts.event_name,
    target_section = opts.target_section,
    jump_mode = opts.jump_mode,
    
    x = 0,
    y = 0,
    
    hovered = false,
    active = false,
  }
end

function M.is_hovered(port, mx, my, config)
  local radius = config.port.size * config.port.hitbox_extend
  local dx = mx - port.x
  local dy = my - port.y
  return (dx * dx + dy * dy) < (radius * radius)
end

function M.can_connect(source_port, target_port)
  if source_port.direction == target_port.direction then
    return false
  end
  
  if source_port.direction == "in" then
    return false
  end
  
  if source_port.type ~= target_port.type then
    return false
  end
  
  return true
end

function M.render(ctx, dl, port, color, config)
  local size = config.port.size
  local is_active = port.hovered or port.active
  
  if is_active then
    local glow_size = size + math.sin(reaper.time_precise() * 8) * 2
    ImGui.DrawList_AddCircle(dl, port.x, port.y, glow_size, config.colors.port_glow, 0, 2)
  end
  
  ImGui.DrawList_AddCircleFilled(dl, port.x, port.y, size, color)
  
  if port.hovered and port.event_name then
    ImGui.SetTooltip(ctx, port.event_name .. " → " .. (port.jump_mode or ""))
  end
end

return M