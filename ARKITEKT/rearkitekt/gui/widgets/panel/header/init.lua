-- @noindex
-- ReArkitekt/gui/widgets/panel/header/init.lua
-- Header coordinator - uses layout engine

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Layout = require('rearkitekt.gui.widgets.panel.header.layout')

local M = {}

function M.draw(ctx, dl, x, y, w, h, state, config, rounding)
  local header_cfg = config.header
  if not header_cfg or not header_cfg.enabled then
    return 0
  end
  
  -- Draw header background
  ImGui.DrawList_AddRectFilled(
    dl, x, y, x + w, y + h,
    header_cfg.bg_color or 0x0F0F0FFF,
    rounding,
    ImGui.DrawFlags_RoundCornersTop
  )
  
  -- Draw header bottom separator
  ImGui.DrawList_AddLine(
    dl, x, y + h - 1, x + w, y + h - 1,
    header_cfg.border_color or 0x000000DD,
    1
  )
  
  return h
end

function M.draw_elements(ctx, dl, x, y, w, h, state, config)
  local header_cfg = config.header
  if not header_cfg or not header_cfg.enabled then
    return
  end
  
  -- Draw header elements only
  Layout.draw(ctx, dl, x, y, w, h, state, header_cfg)
end

return M