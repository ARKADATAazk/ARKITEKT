-- @noindex
-- Region_Playlist/widgets/_temp_transportwidgets.lua
-- Temporary transport widgets for refactor

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local StatusPad = require('rearkitekt.gui.widgets.displays.status_pad')
local Button = require('rearkitekt.gui.widgets.controls.button')
local Tooltip = require('rearkitekt.gui.widgets.controls.tooltip')

local M = {}

-- ============================================================================
-- VIEW MODE BUTTON (Layout Toggle)
-- ============================================================================

M.ViewModeButton = {}
M.ViewModeButton.__index = M.ViewModeButton

function M.ViewModeButton.new(config)
  return setmetatable({
    config = config or {},
    hover_alpha = 0,
  }, M.ViewModeButton)
end

function M.ViewModeButton:draw_icon(ctx, dl, x, y, mode)
  local color = self.config.icon_color or 0xAAAAAAFF
  
  if mode == 'vertical' then
    -- Top bar: 20x3, 2px space, left 5x15, 2px space, right 13x15
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 1)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 5, y + 20, color, 1)
    ImGui.DrawList_AddRectFilled(dl, x + 7, y + 5, x + 20, y + 20, color, 1)
  else
    -- Top bar: 20x3, 2px space, middle 20x4, 2px space, bottom 20x9
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 20, y + 3, color, 1)
    ImGui.DrawList_AddRectFilled(dl, x, y + 5, x + 20, y + 9, color, 1)
    ImGui.DrawList_AddRectFilled(dl, x, y + 11, x + 20, y + 20, color, 1)
  end
end

function M.ViewModeButton:draw(ctx, x, y, current_mode, on_click)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local btn_size = cfg.size or 32
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + btn_size and my >= y and my < y + btn_size
  
  local target = is_hovered and 1.0 or 0.0
  local speed = cfg.animation_speed or 12.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * speed * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  local bg = self:lerp_color(cfg.bg_color or 0x252525FF, cfg.bg_hover or 0x2A2A2AFF, self.hover_alpha)
  local border_inner = self:lerp_color(cfg.border_inner or 0x404040FF, cfg.border_hover or 0x505050FF, self.hover_alpha)
  local border_outer = cfg.border_outer or 0x000000DD
  
  local rounding = cfg.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  
  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + btn_size, y + btn_size, bg, inner_rounding)
  
  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + btn_size - 1, y + btn_size - 1, border_inner, inner_rounding, 0, 1)
  
  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + btn_size, y + btn_size, border_outer, inner_rounding, 0, 1)
  
  local icon_x = x + (btn_size - 20) / 2
  local icon_y = y + (btn_size - 20) / 2
  self:draw_icon(ctx, dl, icon_x, icon_y, current_mode)
  
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##view_mode_toggle", btn_size, btn_size)
  
  if ImGui.IsItemClicked(ctx, 0) and on_click then
    on_click()
  end
  
  if ImGui.IsItemHovered(ctx) then
    local tooltip = current_mode == 'horizontal' and "Switch to List Mode" or "Switch to Timeline Mode"
    Tooltip.show(ctx, tooltip)
  end
  
  return btn_size
end

function M.ViewModeButton:lerp_color(a, b, t)
  local ar, ag, ab, aa = (a >> 24) & 0xFF, (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF
  local br, bg, bb, ba = (b >> 24) & 0xFF, (b >> 16) & 0xFF, (b >> 8) & 0xFF, b & 0xFF
  
  local r = math.floor(ar + (br - ar) * t)
  local g = math.floor(ag + (bg - ag) * t)
  local b = math.floor(ab + (bb - ab) * t)
  local a = math.floor(aa + (ba - aa) * t)
  
  return (r << 24) | (g << 16) | (b << 8) | a
end

-- ============================================================================
-- MODERN TRANSPORT DISPLAY
-- ============================================================================

M.TransportDisplay = {}
M.TransportDisplay.__index = M.TransportDisplay

function M.TransportDisplay.new(config)
  return setmetatable({
    config = config or {},
  }, M.TransportDisplay)
end

function M.TransportDisplay:draw(ctx, x, y, width, height, bridge_state, get_current_region)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  
  local bg = cfg.bg_color or 0x252525FF
  local border_inner = cfg.border_inner or 0x404040FF
  local border_outer = cfg.border_outer or 0x000000DD
  local rounding = cfg.rounding or 6
  local inner_rounding = math.max(0, rounding - 2)
  
  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg, inner_rounding)
  
  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, 0, 1)
  
  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, inner_rounding, 0, 1)
  
  local cx = x + width / 2
  local padding = 12
  
  -- Main time display
  local time_text = "READY"
  local time_color = cfg.time_color or 0xCCCCCCFF
  
  if bridge_state.is_playing then
    local time_remaining = bridge_state.time_remaining or 0
    local mins = math.floor(time_remaining / 60)
    local secs = time_remaining % 60
    
    if mins > 0 then
      time_text = string.format("%02d:%04.1f", mins, secs)
    else
      time_text = string.format("%04.1f", secs)
    end
    time_color = cfg.time_playing_color or 0xFFFFFFFF
  end
  
  local time_w, time_h = ImGui.CalcTextSize(ctx, time_text)
  local time_y = y + padding
  ImGui.DrawList_AddText(dl, cx - time_w / 2, time_y, time_color, time_text)
  
  -- Status indicator
  if bridge_state.is_playing then
    local mode = bridge_state.quantize_mode or "none"
    local status_text = mode ~= "none" and ("Cue: " .. mode) or "Immediate"
    local status_color = cfg.status_color or 0xAAAAAAFF
    local status_w = ImGui.CalcTextSize(ctx, status_text)
    ImGui.DrawList_AddText(dl, cx - status_w / 2, time_y + time_h + 4, status_color, status_text)
  end
  
  -- Progress bar
  local progress = bridge_state.progress or 0
  local bar_h = 3
  local bar_y = y + height - padding - bar_h
  local bar_w = width - padding * 2
  local bar_x = x + padding
  
  -- Track
  local track_color = cfg.track_color or 0x30303080
  ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, track_color, 1.5)
  
  -- Fill
  if progress > 0 then
    local fill_w = bar_w * progress
    local fill_color = cfg.fill_color or 0x41E0A3FF
    ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, fill_color, 1.5)
  end
  
  -- Region name
  if bridge_state.is_playing then
    local current_region = get_current_region and get_current_region()
    if current_region then
      local region_text = current_region.name or "Region"
      local region_color = cfg.region_color or 0xCCCCCCFF
      local region_w = ImGui.CalcTextSize(ctx, region_text)
      ImGui.DrawList_AddText(dl, cx - region_w / 2, bar_y - 20, region_color, region_text)
    end
  end
end

-- ============================================================================
-- JUMP CONTROLS (Library-styled)
-- ============================================================================

M.JumpControls = {}
M.JumpControls.__index = M.JumpControls

function M.JumpControls.new(config)
  return setmetatable({
    config = config or {},
    jump_button_id = "transport_jump_btn",
  }, M.JumpControls)
end

function M.JumpControls:draw(ctx, x, y, width, bridge_state, quantize_lookahead, on_jump, on_mode_change, on_lookahead_change)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  
  local btn_w = 80
  local combo_w = 100
  local slider_label_w = 60
  local spacing = 8
  local slider_w = math.max(60, width - btn_w - combo_w - slider_label_w - spacing * 3)
  local h = 28
  
  local current_x = x
  
  -- JUMP button using library Button component
  local is_disabled = not bridge_state.is_playing
  
  if is_disabled then
    ImGui.BeginDisabled(ctx)
  end
  
  local button_config = {
    label = "JUMP",
    id = self.jump_button_id,
    width = btn_w,
    height = h,
    rounding = 4,
    on_click = on_jump,
    tooltip = "Jump to next quantize point",
  }
  
  Button.draw(ctx, dl, current_x, y, btn_w, h, button_config, self.jump_button_id)
  
  if is_disabled then
    ImGui.EndDisabled(ctx)
  end
  
  current_x = current_x + btn_w + spacing
  
  -- Mode combo (styled to match library)
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
  
  -- Lookahead label + slider
  ImGui.SetCursorScreenPos(ctx, current_x, y + (h - ImGui.GetTextLineHeight(ctx)) / 2)
  ImGui.Text(ctx, "Lookahead:")
  
  current_x = current_x + slider_label_w + 4
  
  ImGui.SetCursorScreenPos(ctx, current_x, y + (h - 20) / 2)
  ImGui.SetNextItemWidth(ctx, slider_w)
  local changed, new_val = ImGui.SliderDouble(ctx, "##lookahead", quantize_lookahead * 1000, 200, 1000, "%.0fms")
  if changed and on_lookahead_change then
    on_lookahead_change(new_val / 1000)
  end
  
  if ImGui.IsItemHovered(ctx) then
    Tooltip.show(ctx, "Jump lookahead time (milliseconds)")
  end
end

-- ============================================================================
-- STATUS PAD CONTROLS
-- ============================================================================

M.GlobalControls = {}
M.GlobalControls.__index = M.GlobalControls

function M.GlobalControls.new(config)
  local self = setmetatable({
    config = config or {},
    transport_pad = nil,
    loop_pad = nil,
  }, M.GlobalControls)
  
  local pad_config = {
    width = config.pad_width or 180,
    height = config.pad_height or 32,
    rounding = config.pad_rounding or 6,
  }
  
  self.transport_pad = StatusPad.new({
    id = "transport_override_pad",
    width = pad_config.width,
    height = pad_config.height,
    rounding = pad_config.rounding,
    color = config.transport_color or 0x4A9EFFFF,
    primary_text = "Transport Override",
    icon_type = "check",
  })
  
  self.loop_pad = StatusPad.new({
    id = "loop_playlist_pad",
    width = pad_config.width,
    height = pad_config.height,
    rounding = pad_config.rounding,
    color = config.loop_color or 0x9C87E8FF,
    primary_text = "Loop Playlist",
    icon_type = "check",
  })
  
  return self
end

function M.GlobalControls:draw(ctx, x, y, transport_override, loop_playlist, on_transport_override, on_loop_playlist)
  local cfg = self.config
  local spacing = cfg.spacing or 8
  
  -- Transport Override pad
  self.transport_pad:set_state(transport_override)
  self.transport_pad.on_click = function(new_state)
    if on_transport_override then
      on_transport_override(new_state)
    end
  end
  self.transport_pad:draw(ctx, x, y)
  
  -- Loop Playlist pad
  local loop_y = y + self.transport_pad.height + spacing
  self.loop_pad:set_state(loop_playlist)
  self.loop_pad.on_click = function(new_state)
    if on_loop_playlist then
      on_loop_playlist(new_state)
    end
  end
  self.loop_pad:draw(ctx, x, loop_y)
end

return M
