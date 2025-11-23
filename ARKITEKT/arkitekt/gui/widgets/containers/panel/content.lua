-- @noindex
-- Arkitekt/gui/widgets/panel/content.lua
-- Scrollable content area management

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local PC = Style.PANEL_COLORS   -- Panel-specific colors


local M = {}

function M.begin_child(ctx, id, width, height, scroll_config, container)
  local flags = scroll_config.flags or 0
  local scroll_bg = scroll_config.bg_color or PC.bg_scrollbar

  ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg, scroll_bg)

  -- Use AlwaysUseWindowPadding flag when padding is configured
  -- Without this flag, child windows ignore WindowPadding by default
  local child_flags = ImGui.ChildFlags_None
  if container and container.config and container.config.padding and container.config.padding > 0 then
    child_flags = ImGui.ChildFlags_AlwaysUseWindowPadding or 0
  end

  local success = ImGui.BeginChild(ctx, id .. "_scroll", width, height, child_flags, flags)
  
  if not success then
    -- BeginChild failed - pop immediately and clean up
    ImGui.PopStyleColor(ctx, 1)
  end
  
  -- Track success state for end_child
  if container then
    container._child_began_successfully = success
  end
  
  return success
end

function M.end_child(ctx, container)
  -- Only proceed if begin_child succeeded
  if not container._child_began_successfully then
    return
  end
  
  local anti_jitter = container.config.anti_jitter
  
  if anti_jitter and anti_jitter.enabled and anti_jitter.track_scrollbar then
    local cursor_y = ImGui.GetCursorPosY(ctx)
    local content_height = cursor_y
    
    local threshold = anti_jitter.height_threshold or 5
    
    if math.abs(content_height - container.last_content_height) > threshold then
      container.had_scrollbar_last_frame = content_height > (container.actual_child_height + threshold)
      container.last_content_height = content_height
    end
  end
  
  ImGui.Dummy(ctx, 0, 0)
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 1)
  
  -- Reset state
  container._child_began_successfully = false
end

return M
