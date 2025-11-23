-- @noindex
-- RegionPlaylist/ui/views/transport/button_widgets.lua
-- Transport button widgets (view mode, toggle buttons, jump controls)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('arkitekt.core.colors')
local Tooltip = require('arkitekt.gui.widgets.overlays.tooltip')
local hexrgb = Colors.hexrgb

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

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
  local icon_size = 16  -- Smaller icon for 30px button (was 20px for 32px button)

  if mode == 'vertical' then
    -- List mode icon: horizontal bar at top + two vertical columns below
    ImGui.DrawList_AddRectFilled(dl, x, y, x + icon_size, y + 2, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 4, x + 4, y + icon_size, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x + 6, y + 4, x + icon_size, y + icon_size, color, 0)
  else
    -- Timeline mode icon: three horizontal bars stacked
    ImGui.DrawList_AddRectFilled(dl, x, y, x + icon_size, y + 2, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 4, x + icon_size, y + 7, color, 0)
    ImGui.DrawList_AddRectFilled(dl, x, y + 9, x + icon_size, y + icon_size, color, 0)
  end
end

function ViewModeButton:draw(ctx, x, y, current_mode, on_click, use_foreground_drawlist, is_blocking)
  is_blocking = is_blocking or false
  local dl = use_foreground_drawlist and ImGui.GetForegroundDrawList(ctx) or ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local btn_size = cfg.size or 32

  -- Only check hover if not blocking
  local is_hovered = false
  if not is_blocking then
    local mx, my = ImGui.GetMousePos(ctx)
    is_hovered = mx >= x and mx < x + btn_size and my >= y and my < y + btn_size
  end

  local target = is_hovered and 1.0 or 0.0
  local speed = cfg.animation_speed or 12.0
  local dt = ImGui.GetDeltaTime(ctx)

  -- Reset hover alpha immediately when blocking (don't animate)
  if is_blocking then
    self.hover_alpha = 0
  else
    self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * speed * dt
    self.hover_alpha = max(0, min(1, self.hover_alpha))
  end

  local bg = self:lerp_color(cfg.bg_color or hexrgb("#252525"), cfg.bg_hover or hexrgb("#2A2A2A"), self.hover_alpha)
  local border_inner = self:lerp_color(cfg.border_inner or hexrgb("#404040"), cfg.border_hover or hexrgb("#505050"), self.hover_alpha)
  local border_outer = cfg.border_outer or hexrgb("#000000DD")

  local rounding = cfg.rounding or 4
  local inner_rounding = max(0, rounding - 2)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + btn_size, y + btn_size, bg, inner_rounding)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + btn_size - 1, y + btn_size - 1, border_inner, inner_rounding, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + btn_size, y + btn_size, border_outer, inner_rounding, 0, 1)

  local icon_size = 16  -- Match icon size from draw_icon
  local icon_x = (x + (btn_size - icon_size) / 2 + 0.5)//1
  local icon_y = (y + (btn_size - icon_size) / 2 + 0.5)//1
  self:draw_icon(ctx, dl, icon_x, icon_y, current_mode)

  -- Use manual click detection when on foreground drawlist (outside child context)
  if not is_blocking then
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

    -- Only show tooltip if not blocking
    if is_hovered then
      local tooltip = current_mode == 'horizontal' and "Switch to List Mode" or "Switch to Timeline Mode"
      Tooltip.show(ctx, tooltip)
    end
  end

  return btn_size
end

function ViewModeButton:lerp_color(a, b, t)
  local ar, ag, ab, aa = (a >> 24) & 0xFF, (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF
  local br, bg, bb, ba = (b >> 24) & 0xFF, (b >> 16) & 0xFF, (b >> 8) & 0xFF, b & 0xFF

  local r = (ar + (br - ar) * t)//1
  local g = (ag + (bg - ag) * t)//1
  local b = (ab + (bb - ab) * t)//1
  local a = (aa + (ba - aa) * t)//1

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
  self.hover_alpha = max(0, min(1, self.hover_alpha))
  
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

  -- Note: SimpleToggleButton doesn't currently support is_blocking parameter
  -- If needed, add it to the draw() signature like ViewModeButton
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, self.id, self.width, self.height)

  if ImGui.IsItemClicked(ctx, 0) and on_click then
    on_click(not state)
  end
  
  return self.width
end

M.SimpleToggleButton = SimpleToggleButton

-- Note: JumpControls was removed - transport now uses header elements system
-- Quantize options centralized in RegionPlaylist/core/config.lua (M.QUANTIZE.options)

return M
