-- @noindex
-- ReArkitekt/gui/widgets/transport/transport_container.lua
-- Transport panel with bottom header and gradient background

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Panel = require('rearkitekt.gui.widgets.panel.init')
local TransportFX = require('rearkitekt.gui.widgets.transport.transport_fx')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local DEFAULTS = {
  height = 48,
  button_height = 23,
  fx = TransportFX.DEFAULT_CONFIG,
  background_pattern = {
    primary = { type = 'dots', spacing = 50, color = hexrgb("#0000001c"), dot_size = 2.5 },
    secondary = { enabled = true, type = 'dots', spacing = 5, color = hexrgb("#14141447"), dot_size = 1.5 },
  },
  hover_fade_speed = 6.0,
}

local TransportPanel = {}
TransportPanel.__index = TransportPanel

function M.new(opts)
  opts = opts or {}
  
  local button_height = opts.button_height or DEFAULTS.button_height
  
  -- Create panel with bottom header configuration
  -- Panel.new() automatically sets up id and _panel_id fields which are
  -- required for header elements to detect panel context and apply
  -- automatic corner rounding based on element position and separators.
  local cfg = opts.config or DEFAULTS
  local panel = Panel.new({
    id = opts.id or "transport_panel",
    height = opts.height or DEFAULTS.height,
    width = opts.width,
    
    config = {
      bg_color = cfg.panel_bg_color or hexrgb("#00000000"),  -- Configurable base background (defaults to transparent)
      border_thickness = 0,
      rounding = 8,
      
      -- Use configurable background pattern for transport panel
      background_pattern = {
        enabled = true,
        primary = cfg.background_pattern and cfg.background_pattern.primary or DEFAULTS.background_pattern.primary,
        secondary = cfg.background_pattern and cfg.background_pattern.secondary or DEFAULTS.background_pattern.secondary,
      },
      
      header = {
        enabled = true,
        height = button_height,
        position = "bottom",
        bg_color = hexrgb("#00000000"),  -- Transparent header background
        border_color = hexrgb("#00000000"),
        rounding = 8,
        padding = { left = 0, right = 0 },  -- No padding so corner rounding is visible
        elements = opts.header_elements or {},
      },
    },
  })
  
  local container = setmetatable({
    panel = panel,
    id = opts.id or "transport_panel",
    config = cfg,
    
    height = opts.height or DEFAULTS.height,
    width = opts.width,
    
    hover_alpha = 0.0,
    last_bounds = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },
    
    on_hover_changed = opts.on_hover_changed,
    
    -- Color animation state
    current_region_color = nil,
    next_region_color = nil,
    target_current_color = nil,
    target_next_color = nil,
  }, TransportPanel)
  
  return container
end

function TransportPanel:update_hover_state(ctx, x1, y1, x2, y2, dt)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x1 and mx < x2 and my >= y1 and my < y2
  
  local target_alpha = is_hovered and 1.0 or 0.0
  local fade_speed = self.config.hover_fade_speed or DEFAULTS.hover_fade_speed
  
  local delta = (target_alpha - self.hover_alpha) * fade_speed * dt
  self.hover_alpha = math.max(0.0, math.min(1.0, self.hover_alpha + delta))
  
  return is_hovered
end

function TransportPanel:update_region_colors(ctx, target_current, target_next)
  local dt = ImGui.GetDeltaTime(ctx)
  local fade_speed = self.config.fx.gradient.fade_speed or 8.0
  
  -- Initialize colors if first time
  if not self.current_region_color then
    self.current_region_color = target_current
    self.next_region_color = target_next
    self.target_current_color = target_current
    self.target_next_color = target_next
    return
  end
  
  -- Update targets
  self.target_current_color = target_current
  self.target_next_color = target_next
  
  -- Lerp colors
  local function lerp_color(from, to, t)
    if not from or not to then return to end
    
    local Colors = require('rearkitekt.core.colors')
    local r1, g1, b1, a1 = Colors.rgba_to_components(from)
    local r2, g2, b2, a2 = Colors.rgba_to_components(to)
    
    local r = math.floor(r1 + (r2 - r1) * t)
    local g = math.floor(g1 + (g2 - g1) * t)
    local b = math.floor(b1 + (b2 - b1) * t)
    local a = math.floor(a1 + (a2 - a1) * t)
    
    return Colors.components_to_rgba(r, g, b, a)
  end
  
  local lerp_factor = math.min(1.0, fade_speed * dt)
  
  if self.target_current_color then
    self.current_region_color = lerp_color(self.current_region_color, self.target_current_color, lerp_factor)
  end
  
  if self.target_next_color then
    self.next_region_color = lerp_color(self.next_region_color, self.target_next_color, lerp_factor)
  end
end

function TransportPanel:begin_draw(ctx, region_colors)
  region_colors = region_colors or {}
  local target_current = region_colors.current
  local target_next = region_colors.next
  
  self:update_region_colors(ctx, target_current, target_next)
  
  -- Get panel bounds before drawing
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local w = self.width or avail_w
  local h = self.height
  
  local x1, y1 = cursor_x, cursor_y
  local x2, y2 = x1 + w, y1 + h
  
  self.last_bounds = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
  
  -- Update hover state and draw transport FX background
  local dl = ImGui.GetWindowDrawList(ctx)
  local dt = ImGui.GetDeltaTime(ctx)
  local is_hovered = self:update_hover_state(ctx, x1, y1, x2, y2, dt)
  
  TransportFX.render_complete(dl, x1, y1, x2, y2, self.config.fx, self.hover_alpha, 
    self.current_region_color, self.next_region_color)
  
  if self.on_hover_changed then
    self.on_hover_changed(is_hovered, self.hover_alpha)
  end
  
  -- Begin panel draw (this will draw header at bottom)
  local success = self.panel:begin_draw(ctx)
  
  -- Calculate content dimensions (panel child dimensions)
  local content_w = self.panel.child_width or w
  local content_h = self.panel.child_height or (h - (self.panel.header_height or 0))
  
  return content_w, content_h
end

function TransportPanel:end_draw(ctx)
  self.panel:end_draw(ctx)
end

function TransportPanel:reset()
  self.hover_alpha = 0.0
  self.current_region_color = nil
  self.next_region_color = nil
  self.target_current_color = nil
  self.target_next_color = nil
end

function TransportPanel:get_hover_factor()
  return self.hover_alpha
end

function TransportPanel:set_height(height)
  self.height = height
  if self.panel then
    self.panel.height = height
  end
end

function TransportPanel:set_width(width)
  self.width = width
  if self.panel then
    self.panel.width = width
  end
end

function TransportPanel:set_header_elements(elements)
  if self.panel and self.panel.config and self.panel.config.header then
    self.panel.config.header.elements = elements
  end
end

function TransportPanel:get_panel_state()
  return self.panel
end

function M.draw(ctx, id, width, height, content_fn, config, region_colors)
  config = config or DEFAULTS
  region_colors = region_colors or {}
  
  local container = M.new({
    id = id,
    width = width,
    height = height,
    config = config,
  })
  
  local content_w, content_h = container:begin_draw(ctx, region_colors)
  
  if content_fn then
    content_fn(ctx, content_w, content_h)
  end
  
  container:end_draw(ctx)
  
  return container
end

return M
