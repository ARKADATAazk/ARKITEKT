-- @noindex
-- Region_Playlist/ui/views/transport/button_widgets.lua
-- Transport button widgets (view mode, toggle buttons, jump controls)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('rearkitekt.core.colors')
local Tooltip = require('rearkitekt.gui.widgets.controls.tooltip')
local hexrgb = Colors.hexrgb

local M = {}

local ViewModeButton = {}
ViewModeButton.__index = ViewModeButton

function M.ViewModeButton_new(config)
  return setmetatable({
    config = config or {},
    hover_alpha = 0,
  }, ViewModeButton)
end

function ViewModeButton:draw_icon(ctx, dl, x, y, mode)
  local color = self.config.icon_color or hexrgb("#AAAAAA")
  
  if mode == 'vertical' then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 5, y + 20, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x + 7, y + 5, x + 20, y + 20, color, 0)
  else
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 20, y + 9, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 11, x + 20, y + 20, color, 0)
  end
end

function ViewModeButton:draw(ctx, x, y, current_mode, on_click, use_foreground_drawlist)
  local dl = use_foreground_drawlist and ImGui.GetForegroundDrawList(ctx) or ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local btn_size = cfg.size or 32
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + btn_size and my >= y and my < y + btn_size
  
  local target = is_hovered and 1.0 or 0.0
  local speed = cfg.animation_speed or 12.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * speed * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  local bg = self:lerp_color(cfg.bg_color or hexrgb("#252525"), cfg.bg_hover or hexrgb("#2A2A2A"), self.hover_alpha)
  local border_inner = self:lerp_color(cfg.border_inner or hexrgb("#404040"), cfg.border_hover or hexrgb("#505050"), self.hover_alpha)
  local border_outer = cfg.border_outer or hexrgb("#000000DD")
  
  local rounding = cfg.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  
  ImGui.DrawList_AddRectFilled(dl, x, y, x + btn_size, y + btn_size, bg, inner_rounding)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + btn_size - 1, y + btn_size - 1, border_inner, inner_rounding, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + btn_size, y + btn_size, border_outer, inner_rounding, 0, 1)
  
  local icon_x = math.floor(x + (btn_size - 20) / 2 + 0.5)
  local icon_y = math.floor(y + (btn_size - 20) / 2 + 0.5)
  self:draw_icon(ctx, dl, icon_x, icon_y, current_mode)
  
  -- Use manual click detection when on foreground drawlist (outside child context)
  if use_foreground_drawlist then
    if is_hovered and ImGui.IsMouseClicked(ctx, 0) and on_click then
      on_click()
    end
  else
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.InvisibleButton(ctx, "##view_mode_toggle", btn_size, btn_size)
    
    if ImGui.IsItemClicked(ctx, 0) and on_click then
      on_click()
    end
  end
  
  if is_hovered then
    local tooltip = current_mode == 'horizontal' and "Switch to List Mode" or "Switch to Timeline Mode"
    Tooltip.show(ctx, tooltip)
  end
  
  return btn_size
end

function ViewModeButton:lerp_color(a, b, t)
  local ar, ag, ab, aa = (a >> 24) & 0xFF, (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF
  local br, bg, bb, ba = (b >> 24) & 0xFF, (b >> 16) & 0xFF, (b >> 8) & 0xFF, b & 0xFF
  
  local r = math.floor(ar + (br - ar) * t)
  local g = math.floor(ag + (bg - ag) * t)
  local b = math.floor(ab + (bb - ab) * t)
  local a = math.floor(aa + (ba - aa) * t)
  
  return (r << 24) | (g << 16) | (b << 8) | a
end

M.ViewModeButton = ViewModeButton

local SimpleToggleButton = {}
SimpleToggleButton.__index = SimpleToggleButton

function M.SimpleToggleButton_new(id, label, width, height)
  return setmetatable({
    id = id,
    label = label,
    width = width or 80,
    height = height or 28,
    hover_alpha = 0,
    state = false,
  }, SimpleToggleButton)
end

function SimpleToggleButton:draw(ctx, x, y, state, on_click, color)
  local dl = ImGui.GetWindowDrawList(ctx)
  self.state = state
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + self.width and my >= y and my < y + self.height
  
  local target = is_hovered and 1.0 or 0.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * 12.0 * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  local bg_off = hexrgb("#252525")
  local bg_off_hover = hexrgb("#2A2A2A")
  local bg_on = Colors.with_alpha(color or hexrgb("#4A9EFF"), 0x40)
  local bg_on_hover = Colors.with_alpha(color or hexrgb("#4A9EFF"), 0x50)
  
  local bg = state and (is_hovered and bg_on_hover or bg_on) or (is_hovered and bg_off_hover or bg_off)
  
  local border_color = state and (color or hexrgb("#4A9EFF")) or hexrgb("#404040")
  
  ImGui.DrawList_AddRectFilled(dl, x, y, x + self.width, y + self.height, bg, 4)
  ImGui.DrawList_AddRect(dl, x, y, x + self.width, y + self.height, border_color, 4, 0, 1)
  
  local text_color = state and hexrgb("#FFFFFF") or hexrgb("#999999")
  local tw, th = ImGui.CalcTextSize(ctx, self.label)
  ImGui.DrawList_AddText(dl, x + (self.width - tw) / 2, y + (self.height - th) / 2, text_color, self.label)
  
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, self.id, self.width, self.height)
  
  if ImGui.IsItemClicked(ctx, 0) and on_click then
    on_click(not state)
  end
  
  return self.width
end

M.SimpleToggleButton = SimpleToggleButton

local JumpControls = {}
JumpControls.__index = JumpControls

function M.JumpControls_new(config)
  return setmetatable({
    config = config or {},
    jump_button_id = "transport_jump_btn",
  }, JumpControls)
end

function JumpControls:draw(ctx, x, y, width, height, bridge_state, quantize_lookahead, on_jump, on_mode_change, on_lookahead_change)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  
  local btn_w = 80
  local combo_w = 100
  local slider_label_w = 60
  local spacing = 8
  local slider_w = math.max(60, width - btn_w - combo_w - slider_label_w - spacing * 3)
  
  local current_x = x
  
  local is_disabled = not bridge_state.is_playing
  
  if is_disabled then
    ImGui.BeginDisabled(ctx)
  end
  
  local Button = require('rearkitekt.gui.widgets.controls.button')
  local button_config = {
    label = "JUMP",
    id = self.jump_button_id,
    width = btn_w,
    height = height,
    rounding = 4,
    on_click = on_jump,
    tooltip = "Jump to next quantize point",
  }
  
  Button.draw(ctx, dl, current_x, y, btn_w, height, button_config, self.jump_button_id)
  
  if is_disabled then
    ImGui.EndDisabled(ctx)
  end
  
  current_x = current_x + btn_w + spacing
  
  ImGui.SetCursorScreenPos(ctx, current_x, y)
  ImGui.SetNextItemWidth(ctx, combo_w)
  
  local mode_options = {
    { value = "measure", label = "Measure" },
    { value = "4.0", label = "Bar" },
    { value = "1.0", label = "1/4" },
    { value = "0.5", label = "1/8" },
    { value = "0.25", label = "1/16" },
  }
  
  local current_mode = bridge_state.quantize_mode or "measure"
  local current_label = "Measure"
  for _, opt in ipairs(mode_options) do
    if opt.value == current_mode then
      current_label = opt.label
      break
    end
  end
  
  if ImGui.BeginCombo(ctx, "##jump_mode", current_label) then
    for _, opt in ipairs(mode_options) do
      local is_selected = opt.value == current_mode
      if ImGui.Selectable(ctx, opt.label, is_selected) and on_mode_change then
        on_mode_change(opt.value)
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end
  
  current_x = current_x + combo_w + spacing
  
  ImGui.SetCursorScreenPos(ctx, current_x, y + (height - ImGui.GetTextLineHeight(ctx)) / 2)
  ImGui.Text(ctx, "Lookahead:")
  
  current_x = current_x + slider_label_w + 4
  
  ImGui.SetCursorScreenPos(ctx, current_x, y + (height - 20) / 2)
  ImGui.SetNextItemWidth(ctx, slider_w)
  local changed, new_val = ImGui.SliderDouble(ctx, "##lookahead", quantize_lookahead * 1000, 200, 1000, "%.0fms")
  if changed and on_lookahead_change then
    on_lookahead_change(new_val / 1000)
  end
  
  if ImGui.IsItemHovered(ctx) then
    Tooltip.show(ctx, "Jump lookahead time (milliseconds)")
  end
end

M.JumpControls = JumpControls

return M
