-- @noindex
-- ReArkitekt/gui/widgets/panel/header/button.lua
-- Generic button component for headers with integrated design

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.9'

local M = {}

local DEFAULTS = {
  bg_color = 0x252525FF,
  bg_hover_color = 0x2A2A2AFF,
  bg_active_color = 0x2A2A2AFF,
  border_outer_color = 0x000000DD,
  border_inner_color = 0x404040FF,
  border_hover_color = 0x505050FF,
  border_active_color = 0xB0B0B077,
  text_color = 0xCCCCCCFF,
  text_hover_color = 0xFFFFFFFF,
  text_active_color = 0xFFFFFFFF,
}

local function get_corner_flags(corner_rounding)
  if not corner_rounding then
    return 0
  end
  
  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end
  
  return flags
end

function M.draw(ctx, dl, x, y, width, height, config, state)
  for k, v in pairs(DEFAULTS) do
    if config[k] == nil then config[k] = v end
  end
  
  local element_id = config.id or "button"
  local label = config.label or ""
  local icon = config.icon or ""
  
  local unique_id = string.format("%s_%s", tostring(state._panel_id or "unknown"), element_id)
  
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered
  
  local bg_color = config.bg_color
  local border_inner = config.border_inner_color
  local text_color = config.text_color
  
  if is_active then
    bg_color = config.bg_active_color
    border_inner = config.border_active_color
    text_color = config.text_active_color
  elseif is_hovered then
    bg_color = config.bg_hover_color
    border_inner = config.border_hover_color
    text_color = config.text_hover_color
  end
  
  local corner_rounding = config.corner_rounding
  local rounding = corner_rounding and corner_rounding.rounding or 0
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(corner_rounding)
  
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)
  
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, config.border_outer_color, inner_rounding, corner_flags, 1)
  
  local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label
  
  if config.custom_draw then
    config.custom_draw(ctx, dl, x, y, width, height, is_hovered, is_active, text_color)
  elseif display_text ~= "" then
    local text_w = ImGui.CalcTextSize(ctx, display_text)
    local text_x = x + (width - text_w) * 0.5
    local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
    ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_text)
  end
  
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, width, height)
  
  local clicked = ImGui.IsItemClicked(ctx, 0)
  
  if clicked and config.on_click then
    config.on_click()
  end
  
  if is_hovered and config.tooltip then
    ImGui.SetTooltip(ctx, config.tooltip)
  end
  
  return width, clicked
end

function M.measure(ctx, config)
  local label = config.label or ""
  local icon = config.icon or ""
  local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label
  
  if config.width then
    return config.width
  end
  
  local text_w = ImGui.CalcTextSize(ctx, display_text)
  local padding = config.padding_x or 10
  return text_w + padding * 2
end

return M