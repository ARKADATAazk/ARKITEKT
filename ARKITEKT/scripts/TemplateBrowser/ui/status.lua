-- @noindex
-- TemplateBrowser/ui/status.lua
-- Status bar component using framework notification service

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local FXQueue = require('TemplateBrowser.domain.fx.queue')

local M = {}

-- Draw status bar at the bottom of the window
function M.Draw(ctx, state, width, height)
  -- Update notification timeouts
  if state.notification then
    state.notification:update()
  end

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Check for FX parsing status first (takes priority over notifications)
  if not FXQueue.is_complete(state) then
    local status = FXQueue.get_status(state)

    -- Draw loading spinner on the left
    local spinner_size = 6
    local spinner_x = x + 8
    local spinner_y = y + (height - spinner_size * 2) * 0.5

    Ark.LoadingSpinner(ctx, {
      x = spinner_x,
      y = spinner_y,
      size = spinner_size,
      thickness = 2,
      advance = 'none',
    })

    -- Draw status text after spinner
    local text_x = spinner_x + spinner_size * 2 + 8
    local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
    ImGui.DrawList_AddText(dl, text_x, text_y, 0xB3B3B3FF, status)

    -- Reserve space
    ImGui.Dummy(ctx, width, height)
    return
  end

  -- Get message from notification service
  local message = state.notification and state.notification:get() or nil
  if not message or message == '' then
    -- Reserve space even when empty
    ImGui.Dummy(ctx, width, height)
    return
  end

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
