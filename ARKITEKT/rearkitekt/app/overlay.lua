-- @noindex
-- rearkitekt/app/overlay.lua
-- Clean overlay/fullscreen implementation for ReArkitekt
-- Handles modal-style overlays with proper ImGui context management

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Utility functions
local function floor(n) return math.floor(n + 0.5) end
local function clamp(val, min, max) return math.max(min, math.min(max, val)) end

-- Alpha animation tracker
local function create_alpha_tracker(speed)
  return {
    current = 0.0,
    target = 0.0,
    speed = speed or 8.0,
    set_target = function(self, t) 
      self.target = clamp(t, 0.0, 1.0)
    end,
    update = function(self, dt)
      local diff = self.target - self.current
      if math.abs(diff) < 0.005 then
        self.current = self.target
      else
        local alpha = 1.0 - math.exp(-self.speed * dt)
        self.current = self.current + diff * alpha
      end
    end,
    value = function(self) 
      return clamp(self.current, 0.0, 1.0)
    end,
    is_complete = function(self)
      return math.abs(self.target - self.current) < 0.005
    end
  }
end

function M.new(opts)
  opts = opts or {}
  
  local overlay = {
    -- Configuration
    enabled = opts.enabled ~= false,
    use_viewport = opts.use_viewport ~= false,
    fade_duration = opts.fade_duration or 0.3,
    fade_speed = opts.fade_speed or 10.0,
    
    -- Scrim (background) settings
    scrim_enabled = opts.scrim_enabled ~= false,
    scrim_color = opts.scrim_color or 0x000000FF,
    scrim_opacity = opts.scrim_opacity or 0.85,
    
    -- Content window settings
    content_padding = opts.content_padding or 0,
    window_bg_color = opts.window_bg_color,
    window_opacity = opts.window_opacity or 1.0,
    
    -- Close behavior
    show_close_button = opts.show_close_button ~= false,
    close_on_background_click = opts.close_on_background_click ~= false,
    close_on_background_right_click = opts.close_on_background_right_click ~= false,
    close_on_escape = opts.close_on_escape ~= false,
    
    -- Close button settings
    close_button = {
      size = opts.close_button_size or 32,
      margin = opts.close_button_margin or 16,
      proximity = opts.close_button_proximity or 150,
      color = opts.close_button_color or 0xFFFFFFFF,
      hover_color = opts.close_button_hover_color or 0xFF4444FF,
      bg_color = opts.close_button_bg_color or 0x000000FF,
      bg_opacity = opts.close_button_bg_opacity or 0.6,
      bg_opacity_hover = opts.close_button_bg_opacity_hover or 0.8,
    },
    
    -- Callbacks
    on_close = opts.on_close,
    draw = opts.draw,
    
    -- Internal state
    alpha = create_alpha_tracker(opts.fade_speed or 10.0),
    is_closing = false,
    close_requested = false,
    is_open = false,
    ctx = nil,
    
    -- Close button state
    close_button_hovered = false,
    close_button_alpha = 0.0,
    
    -- Stats
    frame_count = 0,
  }
  
  -- Public methods
  function overlay:open()
    if self.is_open then return end
    self.is_open = true
    self.is_closing = false
    self.close_requested = false
    self.alpha:set_target(1.0)
    self.frame_count = 0
  end
  
  function overlay:close()
    if not self.is_open then return end
    self.is_closing = true
    self.close_requested = true
    self.alpha:set_target(0.0)
  end
  
  function overlay:toggle()
    if self.is_open then
      self:close()
    else
      self:open()
    end
  end
  
  function overlay:render(ctx)
    if not self.is_open and self.alpha:value() <= 0.001 then 
      return false 
    end
    
    self.ctx = ctx
    self.frame_count = self.frame_count + 1
    
    -- Update animation
    local dt = 1/60
    self.alpha:update(dt)
    
    -- Check if closing animation is complete
    if self.is_closing and self.alpha:is_complete() then
      self.is_open = false
      self.is_closing = false
      if self.on_close then
        self.on_close()
      end
      return false
    end
    
    -- Get viewport dimensions
    local vp_x, vp_y, vp_w, vp_h
    if self.use_viewport then
      local viewport = ImGui.GetMainViewport(ctx)
      vp_x, vp_y = ImGui.Viewport_GetPos(viewport)
      vp_w, vp_h = ImGui.Viewport_GetSize(viewport)
    else
      vp_x, vp_y = 0, 0
      vp_w = ImGui.GetWindowWidth(ctx)
      vp_h = ImGui.GetWindowHeight(ctx)
    end
    
    local alpha_val = self.alpha:value()
    
    -- Render scrim (background overlay)
    if self.scrim_enabled and alpha_val > 0.001 then
      local dl = ImGui.GetForegroundDrawList(ctx)
      local scrim_alpha = floor(255 * self.scrim_opacity * alpha_val)
      local color = (self.scrim_color & 0xFFFFFF00) | scrim_alpha
      ImGui.DrawList_AddRectFilled(dl, vp_x, vp_y, vp_x + vp_w, vp_y + vp_h, color)
    end
    
    -- Setup overlay window
    ImGui.SetNextWindowPos(ctx, vp_x, vp_y)
    ImGui.SetNextWindowSize(ctx, vp_w, vp_h)
    
    local window_flags = ImGui.WindowFlags_NoTitleBar |
                        ImGui.WindowFlags_NoResize |
                        ImGui.WindowFlags_NoMove |
                        ImGui.WindowFlags_NoCollapse |
                        ImGui.WindowFlags_NoScrollbar |
                        ImGui.WindowFlags_NoScrollWithMouse |
                        ImGui.WindowFlags_NoSavedSettings |
                        ImGui.WindowFlags_NoBackground
    
    -- Use unique window name to avoid conflicts
    local window_name = "##Overlay_" .. tostring(self)
    
    -- Begin overlay window
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, alpha_val)
    
    local visible, open = ImGui.Begin(ctx, window_name, true, window_flags)
    
    if visible then
      -- Draw close button FIRST (before background) so it's on top
      if self.show_close_button and alpha_val > 0.1 then
        self:draw_close_button(ctx, vp_x, vp_y, vp_w, vp_h)
      end
      
      -- Handle escape key
      if self.close_on_escape and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        self:close()
      end
      
      -- Draw content
      if self.draw then
        -- Save cursor position before content
        ImGui.SetCursorPos(ctx, self.content_padding, self.content_padding)
        
        -- Let the draw callback handle the actual content
        self.draw(ctx, {
          x = vp_x + self.content_padding,
          y = vp_y + self.content_padding,
          width = vp_w - (self.content_padding * 2),
          height = vp_h - (self.content_padding * 2),
          alpha = alpha_val,
          is_closing = self.is_closing,
          frame = self.frame_count,
          overlay = self,  -- Pass reference to overlay for close requests
        })
      end
      
      -- Handle background click LAST (after content and close button)
      if self.close_on_background_click or self.close_on_background_right_click then
        -- Check if mouse is NOT over close button area
        local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
        local btn = self.close_button
        local btn_x = vp_x + vp_w - btn.size - btn.margin
        local btn_y = vp_y + btn.margin
        local over_close_btn = mouse_x >= btn_x and mouse_x <= btn_x + btn.size and
                               mouse_y >= btn_y and mouse_y <= btn_y + btn.size
        
        if not over_close_btn then
          -- Check if clicked on background (not on content)
          local content_x = vp_x + self.content_padding
          local content_y = vp_y + self.content_padding + 100 -- Account for search bar area
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
    
    return self.is_open or self.is_closing
  end
  
  function overlay:draw_close_button(ctx, vp_x, vp_y, vp_w, vp_h)
    local btn = self.close_button
    local size = btn.size
    local margin = btn.margin
    
    local btn_x = vp_x + vp_w - size - margin
    local btn_y = vp_y + margin
    
    -- Check mouse proximity for fade effect
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local dist = math.sqrt((mouse_x - (btn_x + size/2))^2 + (mouse_y - (btn_y + size/2))^2)
    local in_proximity = dist < btn.proximity
    
    -- Update button alpha
    local target_alpha = in_proximity and 1.0 or 0.3
    local fade_speed = 8.0
    self.close_button_alpha = self.close_button_alpha + (target_alpha - self.close_button_alpha) * (1.0 - math.exp(-fade_speed * 1/60))
    
    -- Handle click with InvisibleButton
    ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
    ImGui.InvisibleButton(ctx, "##overlay_close_btn", size, size)
    self.close_button_hovered = ImGui.IsItemHovered(ctx)
    
    if ImGui.IsItemClicked(ctx) then
      self:close()
    end
    
    -- Draw button visuals
    local dl = ImGui.GetForegroundDrawList(ctx)
    local alpha_val = self.alpha:value() * self.close_button_alpha
    
    -- Background
    local bg_opacity = self.close_button_hovered and btn.bg_opacity_hover or btn.bg_opacity
    local bg_alpha = floor(255 * bg_opacity * alpha_val)
    local bg_color = (btn.bg_color & 0xFFFFFF00) | bg_alpha
    ImGui.DrawList_AddRectFilled(dl, btn_x, btn_y, btn_x + size, btn_y + size, bg_color, size/2)
    
    -- X icon
    local icon_alpha = floor(255 * alpha_val)
    local icon_color = self.close_button_hovered and btn.hover_color or btn.color
    icon_color = (icon_color & 0xFFFFFF00) | icon_alpha
    
    local padding = size * 0.3
    local x1, y1 = btn_x + padding, btn_y + padding
    local x2, y2 = btn_x + size - padding, btn_y + size - padding
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, icon_color, 2)
    ImGui.DrawList_AddLine(dl, x2, y1, x1, y2, icon_color, 2)
  end
  
  return overlay
end

-- Convenience function to create and manage an overlay
function M.create_managed(opts)
  local overlay = M.new(opts)
  
  -- Auto-open on creation if specified
  if opts.auto_open then
    overlay:open()
  end
  
  return overlay
end

return M