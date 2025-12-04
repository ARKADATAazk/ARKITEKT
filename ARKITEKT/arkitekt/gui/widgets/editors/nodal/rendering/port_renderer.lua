-- @noindex
-- Arkitekt/gui/widgets/nodal/port_renderer.lua
-- Port rendering

local ImGui = require('arkitekt.core.imgui')

local M = {}

function M.render(ctx, dl, port, color, config)
  local size = config.port.size
  local is_active = port.hovered or port.active
  
  if is_active then
    local glow_size = size + math.sin(reaper.time_precise() * 8) * 2
    ImGui.DrawList_AddCircle(dl, port.x, port.y, glow_size, config.colors.port_glow, 0, 2)
  end
  
  ImGui.DrawList_AddCircleFilled(dl, port.x, port.y, size, color)
  
  if port.hovered and port.event_name then
    ImGui.SetTooltip(ctx, port.event_name .. ' → ' .. (port.jump_mode or ''))
  end
end

return M