-- @noindex
-- ReArkitekt/app/titlebar.lua
-- MODIFIED: Added CTRL+ALT+CLICK to open debug console
-- ADDED: CTRL+SHIFT+ALT+CLICK on icon to open Lua profiler
-- UPDATED: ImGui 0.10 font size handling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Constants = require('rearkitekt.app.init.constants')

local M = {}
local hexrgb = Colors.hexrgb

local Icon = nil
do
  local ok, mod = pcall(require, 'rearkitekt.app.assets.icon')
  if ok then Icon = mod end
end

function M.new(opts)
  opts = opts or {}

  local titlebar = {
    title           = opts.title or "Window",
    version         = opts.version,
    title_font      = opts.title_font,
    title_font_size = opts.title_font_size or Constants.TYPOGRAPHY.MEDIUM,
    version_font    = opts.version_font,
    version_font_size = opts.version_font_size or Constants.TYPOGRAPHY.DEFAULT,

    height          = opts.height or Constants.TITLEBAR.height,
    pad_h           = opts.pad_h or Constants.TITLEBAR.pad_h,
    pad_v           = opts.pad_v or Constants.TITLEBAR.pad_v,
    button_width    = opts.button_width or Constants.TITLEBAR.button_width,
    button_spacing  = opts.button_spacing or Constants.TITLEBAR.button_spacing,
    button_style    = opts.button_style or Constants.TITLEBAR.button_style,
    separator       = opts.separator ~= false,

    bg_color        = opts.bg_color,
    bg_color_active = opts.bg_color_active,
    text_color      = opts.text_color,
    version_color   = opts.version_color or Constants.TITLEBAR.version_color,
    version_spacing = opts.version_spacing or Constants.TITLEBAR.version_spacing,

    show_icon       = opts.show_icon ~= false,
    icon_size       = opts.icon_size or Constants.TITLEBAR.icon_size,
    icon_spacing    = opts.icon_spacing or Constants.TITLEBAR.icon_spacing,
    icon_color      = opts.icon_color,
    icon_draw       = opts.icon_draw,

    enable_maximize = opts.enable_maximize ~= false,
    is_maximized    = false,

    on_close        = opts.on_close,
    on_maximize     = opts.on_maximize,
    on_icon_click   = opts.on_icon_click,
  }
  
  function titlebar:_truncate_text(ctx, text, max_width, font, font_size)
    if not text then return "" end

    if font then ImGui.PushFont(ctx, font, font_size) end
    local text_w = ImGui.CalcTextSize(ctx, text)
    if font then ImGui.PopFont(ctx) end
    
    if text_w <= max_width then
      return text
    end

    local ellipsis = "..."
    if font then ImGui.PushFont(ctx, font, font_size) end
    local ellipsis_w = ImGui.CalcTextSize(ctx, ellipsis)
    if font then ImGui.PopFont(ctx) end

    if max_width < ellipsis_w then
      return ""
    end

    for i = #text, 1, -1 do
      local sub = text:sub(1, i)
      if font then ImGui.PushFont(ctx, font, font_size) end
      local sub_w = ImGui.CalcTextSize(ctx, sub)
      if font then ImGui.PopFont(ctx) end
      
      if sub_w + ellipsis_w <= max_width then
        return sub .. ellipsis
      end
    end

    return ellipsis
  end

  function titlebar:_draw_icon(ctx, x, y, color)
    if self.icon_draw then
      self.icon_draw(ctx, x, y, self.icon_size, color)
    elseif Icon and Icon.draw_rearkitekt then
      Icon.draw_rearkitekt(ctx, x, y, self.icon_size, color)
    else
      local draw_list = ImGui.GetWindowDrawList(ctx)
      local dpi = ImGui.GetWindowDpiScale(ctx)
      local r = (self.icon_size * 0.5) * dpi
      ImGui.DrawList_AddCircleFilled(draw_list, x + r, y + r, r, color)
    end
  end
  
  function titlebar:set_title(title)
    self.title = tostring(title or self.title)
  end
  
  function titlebar:set_version(version)
    self.version = version and tostring(version) or nil
  end
  
  function titlebar:set_maximized(state)
    self.is_maximized = state
  end
  
  function titlebar:set_icon_visible(visible)
    self.show_icon = visible
  end
  
  function titlebar:set_icon_color(color)
    self.icon_color = color
  end
  
  function titlebar:set_version_color(color)
    self.version_color = color
  end
  
  function titlebar:render(ctx, win_w)
    if not win_w or win_w <= 0 or not self.height or self.height <= 0 then
      return true
    end
    
    local is_focused = ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootWindow)
    
    local bg_color = self.bg_color
    if not bg_color then
      bg_color = is_focused 
        and (self.bg_color_active or ImGui.GetColor(ctx, ImGui.Col_TitleBgActive))
        or ImGui.GetColor(ctx, ImGui.Col_TitleBg)
    end
    
    local text_color = self.text_color or ImGui.GetColor(ctx, ImGui.Col_Text)
    local version_color = self.version_color or Constants.TITLEBAR.version_color
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, self.button_spacing, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, bg_color)
    
    local titlebar_flags = ImGui.ChildFlags_None
    local window_flags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse
    
    local child_visible = ImGui.BeginChild(ctx, "##titlebar", win_w, self.height, titlebar_flags, window_flags)
    
    local clicked_maximize = false
    local clicked_close = false
    local icon_clicked = false
    local icon_shift_clicked = false
    
    if child_visible then
      local content_h = ImGui.GetTextLineHeight(ctx)
      local y_center = (self.height - content_h) * 0.5 
      
      ImGui.SetCursorPos(ctx, self.pad_h, y_center)
      
      local title_x_offset = 0
      if self.show_icon then
        local win_x, win_y = ImGui.GetWindowPos(ctx)
        local icon_x = win_x + self.pad_h
        local icon_y = win_y + (self.height - self.icon_size) * 0.5
        local icon_color = self.icon_color or text_color
        
        ImGui.SetCursorPos(ctx, self.pad_h, (self.height - self.icon_size) * 0.5)
        ImGui.InvisibleButton(ctx, "##icon_button", self.icon_size, self.icon_size)
        
        local icon_hovered = ImGui.IsItemHovered(ctx)
        local icon_button_clicked = ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left)
        
        if icon_button_clicked then
          local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
          local alt_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
          local shift_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
          
          if ctrl_down and alt_down then
            -- CTRL+ALT+CLICK: Open debug console
            local ok, ConsoleWindow = pcall(require, 'rearkitekt.debug.console_window')
            if ok and ConsoleWindow and ConsoleWindow.launch then
              ConsoleWindow.launch()
            end
          elseif shift_down then
            icon_shift_clicked = true
          else
            icon_clicked = true
          end
        end
        
        local draw_color = icon_color
        if icon_hovered then
          local r = (draw_color >> 24) & 0xFF
          local g = (draw_color >> 16) & 0xFF
          local b = (draw_color >> 8) & 0xFF
          local a = draw_color & 0xFF
          r = math.min(255, r + 30)
          g = math.min(255, g + 30)
          b = math.min(255, b + 30)
          draw_color = (r << 24) | (g << 16) | (b << 8) | a
        end
        
        self:_draw_icon(ctx, icon_x, icon_y, draw_color)
        
        if icon_hovered then
          ImGui.SetTooltip(ctx, "Click: Open Hub\nShift+Click: Show Metrics\nCtrl+Alt+Click: Debug Console")
        end
        
        title_x_offset = self.icon_size + self.icon_spacing
        ImGui.SetCursorPos(ctx, self.pad_h + title_x_offset, y_center)
      end
      
      local num_buttons = 1 + (self.enable_maximize and 1 or 0)
      local total_button_width = (self.button_width * num_buttons) + (self.button_spacing * (num_buttons - 1))
      
      local title_start_x = ImGui.GetCursorPosX(ctx)
      local available_width = (win_w - total_button_width) - title_start_x - self.pad_h
      
      if self.version and self.version ~= "" then
        if self.title_font then ImGui.PushFont(ctx, self.title_font, self.title_font_size) end
        local title_w = ImGui.CalcTextSize(ctx, self.title)
        local title_h = ImGui.GetTextLineHeight(ctx)
        if self.title_font then ImGui.PopFont(ctx) end
        
        local version_font = self.version_font
        if version_font then ImGui.PushFont(ctx, version_font, self.version_font_size) end
        local version_w = ImGui.CalcTextSize(ctx, self.version)
        local version_h = ImGui.GetTextLineHeight(ctx)
        if version_font then ImGui.PopFont(ctx) end
        
        local total_w = title_w + self.version_spacing + version_w
        
        if total_w <= available_width then
          local base_y = ImGui.GetCursorPosY(ctx)
          
          if self.title_font then ImGui.PushFont(ctx, self.title_font, self.title_font_size) end
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
          ImGui.Text(ctx, self.title)
          ImGui.PopStyleColor(ctx)
          if self.title_font then ImGui.PopFont(ctx) end
          
          ImGui.SameLine(ctx, 0, self.version_spacing)
          
          local height_diff = title_h - version_h
          if height_diff ~= 0 then
            ImGui.SetCursorPosY(ctx, base_y + height_diff - 1)
          end
          
          if version_font then ImGui.PushFont(ctx, version_font, self.version_font_size) end
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, version_color)
          ImGui.Text(ctx, self.version)
          ImGui.PopStyleColor(ctx)
          if version_font then ImGui.PopFont(ctx) end
        else
          if self.title_font then ImGui.PushFont(ctx, self.title_font, self.title_font_size) end
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
          local display_title = self:_truncate_text(ctx, self.title .. " " .. self.version, available_width, self.title_font, self.title_font_size)
          ImGui.Text(ctx, display_title)
          ImGui.PopStyleColor(ctx)
          if self.title_font then ImGui.PopFont(ctx) end
        end
      else
        if self.title_font then ImGui.PushFont(ctx, self.title_font, self.title_font_size) end
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
        local display_title = self:_truncate_text(ctx, self.title, available_width, self.title_font, self.title_font_size)
        ImGui.Text(ctx, display_title)
        ImGui.PopStyleColor(ctx)
        if self.title_font then ImGui.PopFont(ctx) end
      end

      ImGui.SetCursorPos(ctx, win_w - total_button_width, 0)
      
      if self.button_style == "filled" then
        clicked_maximize, clicked_close = self:_draw_buttons_filled(ctx)
      else
        clicked_maximize, clicked_close = self:_draw_buttons_minimal(ctx, bg_color)
      end
    end
    
    ImGui.EndChild(ctx)
    ImGui.PopStyleColor(ctx)
    ImGui.PopStyleVar(ctx, 2)
    
    if self.separator then
      ImGui.Separator(ctx)
    end
    
    if (icon_clicked or icon_shift_clicked) and self.on_icon_click then
      self.on_icon_click(icon_shift_clicked)
    end
    
    if clicked_maximize and self.on_maximize then
      self.on_maximize()
    end
    
    if clicked_close then
      if self.on_close then
        self.on_close()
        return true
      else
        return false
      end
    end
    
    return true
  end

  function titlebar:_draw_button_icon(ctx, min_x, min_y, max_x, max_y, icon_type, color, button_bg_color)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local dpi = ImGui.GetWindowDpiScale(ctx)
    local thickness = math.max(1, math.floor(1.0 * dpi))

    local h = max_y - min_y
    local w = max_x - min_x
    
    local v_padding = math.floor(h * 0.35)
    local iy1 = min_y + v_padding
    local iy2 = max_y - v_padding

    local icon_h = iy2 - iy1
    
    local square_size = icon_h
    if square_size % 2 == 1 then
        square_size = square_size - 1
    end
    
    local center_x = min_x + (w / 2)
    local half_size = square_size / 2
    local ix1 = math.floor(center_x - half_size)
    local ix2 = ix1 + square_size

    if icon_type == 'maximize' then
        ImGui.DrawList_AddRect(draw_list, ix1, iy1, ix2, iy2, color, 0, 0, thickness)

    elseif icon_type == 'restore' then
        local small_offset = math.floor((ix2 - ix1) * 0.25)
        local bx1, by1 = ix1 + small_offset, iy1
        local bx2, by2 = ix2, iy2 - small_offset
        ImGui.DrawList_AddRect(draw_list, bx1, by1, bx2, by2, color, 0, 0, thickness)
        
        local fx1, fy1 = ix1, iy1 + small_offset
        local fx2, fy2 = ix2 - small_offset, iy2
        ImGui.DrawList_AddRectFilled(draw_list, fx1, fy1, fx2, fy2, button_bg_color)
        ImGui.DrawList_AddRect(draw_list, fx1, fy1, fx2, fy2, color, 0, 0, thickness)

    elseif icon_type == 'close' then
        ImGui.DrawList_AddLine(draw_list, ix1, iy1, ix2, iy2, color, thickness)
        ImGui.DrawList_AddLine(draw_list, ix1, iy2, ix2, iy1, color, thickness)
    end
  end

  function titlebar:_draw_buttons_minimal(ctx, bg_color)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 0)

    local clicked_maximize = false
    local clicked_close = false
    local icon_color = ImGui.GetColor(ctx, ImGui.Col_Text)

    if self.enable_maximize then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, Constants.TITLEBAR.button_maximize_normal)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Constants.TITLEBAR.button_maximize_hovered)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Constants.TITLEBAR.button_maximize_active)

      if ImGui.Button(ctx, "##max", self.button_width, self.height) then
        clicked_maximize = true
      end
      
      local is_hovered = ImGui.IsItemHovered(ctx)
      local is_active = ImGui.IsItemActive(ctx)
      
      local current_button_bg
      if is_active then
        current_button_bg = Constants.TITLEBAR.button_maximize_active
      elseif is_hovered then
        current_button_bg = Constants.TITLEBAR.button_maximize_hovered
      else
        current_button_bg = bg_color
      end
      
      local min_x, min_y = ImGui.GetItemRectMin(ctx)
      local max_x, max_y = ImGui.GetItemRectMax(ctx)
      local icon_type = self.is_maximized and "restore" or "maximize"
      self:_draw_button_icon(ctx, min_x, min_y, max_x, max_y, icon_type, icon_color, current_button_bg)

      ImGui.PopStyleColor(ctx, 3)

      if is_hovered then
        ImGui.SetTooltip(ctx, self.is_maximized and "Restore" or "Maximize")
      end

      ImGui.SameLine(ctx)
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_Button, Constants.TITLEBAR.button_close_normal)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Constants.TITLEBAR.button_close_hovered)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Constants.TITLEBAR.button_close_active)

    if ImGui.Button(ctx, "##close", self.button_width, self.height) then
      clicked_close = true
    end

    local is_hovered = ImGui.IsItemHovered(ctx)
    local is_active = ImGui.IsItemActive(ctx)

    local current_button_bg
    if is_active then
      current_button_bg = Constants.TITLEBAR.button_close_active
    elseif is_hovered then
      current_button_bg = Constants.TITLEBAR.button_close_hovered
    else
      current_button_bg = bg_color
    end

    local min_x, min_y = ImGui.GetItemRectMin(ctx)
    local max_x, max_y = ImGui.GetItemRectMax(ctx)
    self:_draw_button_icon(ctx, min_x, min_y, max_x, max_y, "close", icon_color, current_button_bg)
    
    ImGui.PopStyleColor(ctx, 3)
    ImGui.PopStyleVar(ctx, 3)

    if is_hovered then
      ImGui.SetTooltip(ctx, "Close")
    end

    return clicked_maximize, clicked_close
  end

  function titlebar:_draw_buttons_filled(ctx)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 0)
    
    local clicked_maximize = false
    local clicked_close = false
    
    if self.enable_maximize then
      local icon = self.is_maximized and "⊡" or "▢"

      ImGui.PushStyleColor(ctx, ImGui.Col_Button, Constants.TITLEBAR.button_maximize_filled_normal)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Constants.TITLEBAR.button_maximize_filled_hovered)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Constants.TITLEBAR.button_maximize_filled_active)
      
      if ImGui.Button(ctx, icon .. "##max", self.button_width, self.height) then
        clicked_maximize = true
      end
      
      ImGui.PopStyleColor(ctx, 3)
      
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, self.is_maximized and "Restore" or "Maximize")
      end
      
      ImGui.SameLine(ctx)
    end
    
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, Constants.TITLEBAR.button_close_filled_normal)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Constants.TITLEBAR.button_close_filled_hovered)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Constants.TITLEBAR.button_close_filled_active)
    
    if ImGui.Button(ctx, "X##close", self.button_width, self.height) then
      clicked_close = true
    end
    
    ImGui.PopStyleColor(ctx, 3)
    ImGui.PopStyleVar(ctx, 3)
    
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Close")
    end
    
    return clicked_maximize, clicked_close
  end
  
  return titlebar
end

return M
