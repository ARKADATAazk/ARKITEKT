-- @noindex
-- TemplateBrowser/ui/status_bar.lua
-- Status bar component for displaying messages

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}

-- Draw status bar at the bottom of the window
function M.draw(ctx, state, width, height)
  if not state.status_message or state.status_message == "" then
    return
  end

  -- Auto-clear after 10 seconds
  local current_time = reaper.time_precise()
  if state.status_timestamp and (current_time - state.status_timestamp) > 10 then
    state.status_message = ""
    return
  end

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Background color based on message type
  local bg_color
  local text_color = Colors.hexrgb("#FFFFFFFF")

  if state.status_type == "error" then
    bg_color = Colors.hexrgb("#8B2C2C80")  -- Dark red, 50% opacity
  elseif state.status_type == "warning" then
    bg_color = Colors.hexrgb("#8B7B2C80")  -- Dark yellow, 50% opacity
  elseif state.status_type == "success" then
    bg_color = Colors.hexrgb("#2C8B3680")  -- Dark green, 50% opacity
  else  -- info
    bg_color = Colors.hexrgb("#2C4A8B80")  -- Dark blue, 50% opacity
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, 0)

  -- Draw text with padding
  local text_x = x + 8
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, state.status_message)

  -- Reserve space
  ImGui.Dummy(ctx, width, height)
end

return M
