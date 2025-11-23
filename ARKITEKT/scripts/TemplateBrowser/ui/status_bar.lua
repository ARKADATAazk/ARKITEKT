-- @noindex
-- TemplateBrowser/ui/status_bar.lua
-- Status bar component for displaying messages

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

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

  -- Transparent background with colored text based on message type
  local text_color

  if state.status_type == "error" then
    text_color = Colors.hexrgb("#FF4444FF")  -- Bright red
  elseif state.status_type == "warning" then
    text_color = Colors.hexrgb("#FFA500FF")  -- Orange
  elseif state.status_type == "success" then
    text_color = Colors.hexrgb("#4AFF4AFF")  -- Bright green
  else  -- info
    text_color = Colors.hexrgb("#FFFFFFFF")  -- White
  end

  -- Draw text with padding
  local text_x = x + 8
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, state.status_message)

  -- Reserve space
  ImGui.Dummy(ctx, width, height)
end

return M
