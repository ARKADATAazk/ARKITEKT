-- @noindex
-- TemplateBrowser/ui/status.lua
-- Status bar component for displaying messages

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local Layout = require('TemplateBrowser.defs.constants')

local M = {}

-- Draw status bar at the bottom of the window
function M.draw(ctx, state, width, height)
  if not state.status_message or state.status_message == "" then
    return
  end

  -- Auto-clear after timeout (from constants)
  local auto_clear_timeout = Layout.STATUS_BAR.AUTO_CLEAR_TIMEOUT
  local current_time = reaper.time_precise()
  if state.status_timestamp and (current_time - state.status_timestamp) > auto_clear_timeout then
    state.clear_status()
    return
  end

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Color based on message type (from constants)
  local text_color
  if state.status_type == "error" then
    text_color = Layout.STATUS.ERROR
  elseif state.status_type == "warning" then
    text_color = Layout.STATUS.WARNING
  elseif state.status_type == "success" then
    text_color = Layout.STATUS.SUCCESS
  else
    text_color = Layout.STATUS.INFO
  end

  -- Draw text with padding
  local text_x = x + 8
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, state.status_message)

  -- Reserve space
  ImGui.Dummy(ctx, width, height)
end

return M
