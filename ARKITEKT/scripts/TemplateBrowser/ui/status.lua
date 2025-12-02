-- @noindex
-- TemplateBrowser/ui/status.lua
-- Status bar component using framework notification service

local ImGui = require('arkitekt.platform.imgui')

local M = {}

-- Draw status bar at the bottom of the window
function M.draw(ctx, state, width, height)
  -- Update notification timeouts
  if state.notification then
    state.notification:update()
  end

  -- Get message from notification service
  local message, msg_type = state.notification and state.notification:get() or nil, nil
  if not message or message == '' then
    return
  end

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Get color from notification service
  local text_color = state.notification:get_color() or 0xCCCCCCFF

  -- Draw text with padding
  local text_x = x + 8
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, message)

  -- Reserve space
  ImGui.Dummy(ctx, width, height)
end

return M
