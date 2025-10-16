-- @noindex
-- rearkitekt/app/overlay.lua
-- Clean overlay with fade curves

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}

-- ============================================================================
-- SECTION 1: Dependencies
-- ============================================================================

local Easing = nil
do
  local ok, mod = pcall(require, 'rearkitekt.gui.fx.easing')
  if ok then Easing = mod end
end

local hexrgb = Colors.hexrgb

-- ============================================================================
-- SECTION 2: Curve Type Constants
-- ============================================================================

M.CURVE_LINEAR = 'linear'
M.CURVE_EASE_IN_QUAD = 'ease_in_quad'
M.CURVE_EASE_OUT_QUAD = 'ease_out_quad'
M.CURVE_EASE_IN_OUT_QUAD = 'ease_in_out_quad'
M.CURVE_EASE_IN_CUBIC = 'ease_in_cubic'
M.CURVE_EASE_OUT_CUBIC = 'ease_out_cubic'
M.CURVE_EASE_IN_OUT_CUBIC = 'ease_in_out_cubic'
M.CURVE_EASE_IN_SINE = 'ease_in_sine'
M.CURVE_EASE_OUT_SINE = 'ease_out_sine'
M.CURVE_EASE_IN_OUT_SINE = 'ease_in_out_sine'
M.CURVE_SMOOTHSTEP = 'smoothstep'
M.CURVE_SMOOTHERSTEP = 'smootherstep'
M.CURVE_EASE_IN_EXPO = 'ease_in_expo'
M.CURVE_EASE_OUT_EXPO = 'ease_out_expo'
M.CURVE_EASE_IN_OUT_EXPO = 'ease_in_out_expo'
M.CURVE_EASE_IN_BACK = 'ease_in_back'
M.CURVE_EASE_OUT_BACK = 'ease_out_back'

-- ============================================================================
-- SECTION 3: Default Configuration
-- ============================================================================

local DEFAULT_CONFIG = {
  enabled = true,
  use_viewport = true,
  fade_duration = 0.3,
  fade_curve = M.CURVE_SMOOTHERSTEP,
  
  scrim_enabled = true,
  scrim_color = hexrgb("#101010ff"),
  scrim_opacity = 0.90,
  
  content_padding = 0,
  window_opacity = 1.0,
  
  show_close_button = true,
  close_on_background_click = true,
  close_on_background_right_click = true,
  close_on_escape = true,
  
  close_button = {
    size = 32,
    margin = 16,
    proximity = 150,
    color = hexrgb("#FFFFFFFF"),
    hover_color = hexrgb("#FF4444FF"),
    bg_color = hexrgb("#000000FF"),
    bg_opacity = 0.6,
    bg_opacity_hover = 0.8,
  },
  
  cached_viewport = { x = 0, y = 0, w = 1920, h = 1080 },
}

-- ============================================================================
-- SECTION 4: Helper Functions
-- ============================================================================

local function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

local function apply_curve(t, curve_name)
  t = clamp(t, 0.0, 1.0)
  if not Easing or not curve_name then return t end
  local easing_func = Easing[curve_name]
  if easing_func then return easing_func(t) end
  return t
end

local function create_alpha_tracker(duration, curve_type)
  return {
    current = 0.0,
    target = 0.0,
    duration = duration or 0.3,
    curve_type = curve_type or M.CURVE_SMOOTHERSTEP,
    elapsed = 0.0,
    set_target = function(self, t) 
      self.target = clamp(t, 0.0, 1.0)
      self.elapsed = 0.0
    end,
    update = function(self, dt)
      if math.abs(self.target - self.current) < 0.001 then
        self.current = self.target
        return
      end
      self.elapsed = self.elapsed + dt
      local t = clamp(self.elapsed / self.duration, 0.0, 1.0)
      local curved = apply_curve(t, self.curve_type)
      self.current = self.current + (self.target - self.current) * curved
      if self.elapsed >= self.duration then
        self.current = self.target
      end
    end,
    value = function(self) 
      return clamp(self.current, 0.0, 1.0)
    end,
    is_complete = function(self)
      return math.abs(self.target - self.current) < 0.001
    end
  }
end

-- ============================================================================
-- SECTION 5: Main Overlay Implementation
-- ============================================================================

function M.new(opts)
  opts = opts or {}
  
  local cfg = DEFAULT_CONFIG
  
  local overlay = {
    enabled = opts.enabled ~= false,
    use_viewport = opts.use_viewport ~= false,
    fade_duration = opts.fade_duration or cfg.fade_duration,
    fade_curve = opts.fade_curve or cfg.fade_curve,
    
    scrim_enabled = opts.scrim_enabled ~= false,
    scrim_color = opts.scrim_color or cfg.scrim_color,
    scrim_opacity = opts.scrim_opacity or cfg.scrim_opacity,
    
    content_padding = opts.content_padding or cfg.content_padding,
    window_bg_color = opts.window_bg_color,
    window_opacity = opts.window_opacity or cfg.window_opacity,
    
    show_close_button = opts.show_close_button ~= false,
    close_on_background_click = opts.close_on_background_click ~= false,
    close_on_background_right_click = opts.close_on_background_right_click ~= false,
    close_on_escape = opts.close_on_escape ~= false,
    
    close_button = {
      size = opts.close_button_size or cfg.close_button.size,
      margin = opts.close_button_margin or cfg.close_button.margin,
      proximity = opts.close_button_proximity or cfg.close_button.proximity,
      color = opts.close_button_color or cfg.close_button.color,
      hover_color = opts.close_button_hover_color or cfg.close_button.hover_color,
      bg_color = opts.close_button_bg_color or cfg.close_button.bg_color,
      bg_opacity = opts.close_button_bg_opacity or cfg.close_button.bg_opacity,
      bg_opacity_hover = opts.close_button_bg_opacity_hover or cfg.close_button.bg_opacity_hover,
    },
    
    on_close = opts.on_close,
    draw = opts.draw,
    
    alpha = create_alpha_tracker(opts.fade_duration or cfg.fade_duration, opts.fade_curve or cfg.fade_curve),
    is_closing = false,
    is_open = false,
    ctx = nil,
    close_frame_delay = 0,
    close_button_hovered = false,
    close_button_alpha = 0.0,
    frame_count = 0,
    last_frame_time = nil,
    cached_vp_x = cfg.cached_viewport.x,
    cached_vp_y = cfg.cached_viewport.y,
    cached_vp_w = cfg.cached_viewport.w,
    cached_vp_h = cfg.cached_viewport.h,
  }
  
  function overlay:open()
    if self.is_open then return end
    self.is_open = true
    self.is_closing = false
    self.alpha:set_target(1.0)
    self.frame_count = 0
    self.last_frame_time = reaper.time_precise()
  end
  
  function overlay:close()
    if not self.is_open then return end
    self.is_closing = true
    self.close_frame_delay = 1
    self.alpha:set_target(0.0)
  end
  
  function overlay:toggle()
    if self.is_open then self:close() else self:open() end
  end
  
  function overlay:render(ctx)
    if not self.is_open and self.alpha:value() <= 0.001 then return false end
    
    self.ctx = ctx
    self.frame_count = self.frame_count + 1
    
    local current_time = reaper.time_precise()
    local dt = self.last_frame_time and clamp(current_time - self.last_frame_time, 0.001, 0.1) or 1/60
    self.last_frame_time = current_time
    
    self.alpha:update(dt)
    
    if self.close_frame_delay > 0 then
      self.close_frame_delay = self.close_frame_delay - 1
    end
    
    if self.is_closing and self.alpha:is_complete() then
      self.is_open = false
      self.is_closing = false
      if self.on_close then self.on_close() end
      return false
    end
    
    local alpha_val = self.alpha:value()
    
    if not self.is_closing and self.close_on_escape and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      self:close()
    end
    
    local vp_x, vp_y, vp_w, vp_h
    if self.use_viewport then
      local viewport = ImGui.GetMainViewport(ctx)
      if viewport then
        vp_x, vp_y = ImGui.Viewport_GetPos(viewport)
        vp_w, vp_h = ImGui.Viewport_GetSize(viewport)
        self.cached_vp_x, self.cached_vp_y, self.cached_vp_w, self.cached_vp_h = vp_x, vp_y, vp_w, vp_h
      else
        vp_x, vp_y, vp_w, vp_h = self.cached_vp_x, self.cached_vp_y, self.cached_vp_w, self.cached_vp_h
      end
    else
      vp_x, vp_y = 0, 0
      vp_w = ImGui.GetWindowWidth(ctx)
      vp_h = ImGui.GetWindowHeight(ctx)
    end
    
    ImGui.SetNextWindowPos(ctx, vp_x, vp_y)
    ImGui.SetNextWindowSize(ctx, vp_w, vp_h)
    
    local window_flags = ImGui.WindowFlags_NoTitleBar |
                        ImGui.WindowFlags_NoResize |
                        ImGui.WindowFlags_NoMove |
                        ImGui.WindowFlags_NoCollapse |
                        ImGui.WindowFlags_NoScrollbar |
                        ImGui.WindowFlags_NoScrollWithMouse |
                        ImGui.WindowFlags_NoNav
    
    if self.is_closing and self.close_frame_delay == 0 then
      window_flags = window_flags | ImGui.WindowFlags_NoInputs
    end
    
    local window_name = "##Overlay_" .. tostring(self)
    
    if self.scrim_enabled and alpha_val > 0.001 then
      local scrim_alpha = self.scrim_opacity * alpha_val
      local scrim_color = (self.scrim_color & 0xFFFFFF00) | math.floor(255 * scrim_alpha + 0.5)
      ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, scrim_color)
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x00000000)
    end
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, alpha_val)
    
    local visible = ImGui.Begin(ctx, window_name, true, window_flags)
    
    if visible and not self.is_closing then
      if self.show_close_button and alpha_val > 0.1 then
        self:draw_close_button(ctx, vp_x, vp_y, vp_w, vp_h, dt)
      end
      
      if self.draw then
        ImGui.SetCursorPos(ctx, self.content_padding, self.content_padding)
        self.draw(ctx, {
          x = vp_x + self.content_padding,
          y = vp_y + self.content_padding,
          width = vp_w - (self.content_padding * 2),
          height = vp_h - (self.content_padding * 2),
          alpha = alpha_val,
          is_closing = self.is_closing,
          frame = self.frame_count,
          overlay = self,
        })
      end
      
      if self.close_on_background_click or self.close_on_background_right_click then
        local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
        local btn = self.close_button
        local btn_x = vp_x + vp_w - btn.size - btn.margin
        local btn_y = vp_y + btn.margin
        local over_close_btn = mouse_x >= btn_x and mouse_x <= btn_x + btn.size and
                               mouse_y >= btn_y and mouse_y <= btn_y + btn.size
        
        if not over_close_btn then
          local content_x = vp_x + self.content_padding
          local content_y = vp_y + self.content_padding + 100
          local content_w = vp_w - (self.content_padding * 2)
          local content_h = vp_h - (self.content_padding * 2) - 100
          
          local over_content = mouse_x >= content_x and mouse_x <= content_x + content_w and
                              mouse_y >= content_y and mouse_y <= content_y + content_h
          
          if not over_content and not ImGui.IsAnyItemHovered(ctx) then
            if (self.close_on_background_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)) or
               (self.close_on_background_right_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right)) then
              self:close()
            end
          end
        end
      end
    end
    
    ImGui.End(ctx)
    ImGui.PopStyleVar(ctx, 3)
    ImGui.PopStyleColor(ctx)
    
    return self.is_open or self.is_closing
  end
  
  function overlay:draw_close_button(ctx, vp_x, vp_y, vp_w, vp_h, dt)
    local btn = self.close_button
    local btn_x = vp_x + vp_w - btn.size - btn.margin
    local btn_y = vp_y + btn.margin
    
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local dist = math.sqrt((mouse_x - (btn_x + btn.size/2))^2 + (mouse_y - (btn_y + btn.size/2))^2)
    local in_proximity = dist < btn.proximity
    
    local target_alpha = in_proximity and 1.0 or 0.3
    self.close_button_alpha = self.close_button_alpha + (target_alpha - self.close_button_alpha) * (1.0 - math.exp(-10.0 * dt))
    
    ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
    ImGui.InvisibleButton(ctx, "##overlay_close_btn", btn.size, btn.size)
    self.close_button_hovered = ImGui.IsItemHovered(ctx)
    
    if ImGui.IsItemClicked(ctx) then self:close() end
    
    local dl = ImGui.GetForegroundDrawList(ctx)
    local alpha_val = self.alpha:value() * self.close_button_alpha
    
    local bg_opacity = self.close_button_hovered and btn.bg_opacity_hover or btn.bg_opacity
    local bg_alpha = bg_opacity * alpha_val
    local bg_color = (btn.bg_color & 0xFFFFFF00) | math.floor(255 * bg_alpha + 0.5)
    ImGui.DrawList_AddRectFilled(dl, btn_x, btn_y, btn_x + btn.size, btn_y + btn.size, bg_color, btn.size/2)
    
    local icon_color = self.close_button_hovered and btn.hover_color or btn.color
    icon_color = (icon_color & 0xFFFFFF00) | math.floor(255 * alpha_val + 0.5)
    
    local padding = btn.size * 0.3
    local x1, y1 = btn_x + padding, btn_y + padding
    local x2, y2 = btn_x + btn.size - padding, btn_y + btn.size - padding
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, icon_color, 2)
    ImGui.DrawList_AddLine(dl, x2, y1, x1, y2, icon_color, 2)
  end
  
  return overlay
end

function M.create_managed(opts)
  local overlay = M.new(opts)
  if opts.auto_open then overlay:open() end
  return overlay
end

return M