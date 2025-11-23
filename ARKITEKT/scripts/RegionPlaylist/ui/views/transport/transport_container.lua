-- @noindex
-- RegionPlaylist/ui/views/transport/transport_container.lua
-- Transport panel with bottom header and gradient background
-- MOVED FROM LIBRARY: Project-specific transport panel (no other scripts use this)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Panel = require('arkitekt.gui.widgets.containers.panel.init')
local TransportFX = require('RegionPlaylist.ui.views.transport.transport_fx')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min
local abs = math.abs

local M = {}

-- Note: All default configuration is centralized in RegionPlaylist/core/config.lua (M.TRANSPORT)
-- This avoids duplication and ensures single source of truth

local TransportPanel = {}
TransportPanel.__index = TransportPanel

function M.new(opts)
  opts = opts or {}

  -- Require config to be passed in - no local defaults
  if not opts.config then
    error("TransportContainer.new requires opts.config to be provided")
  end

  local cfg = opts.config
  local button_height = opts.button_height or 23

  local panel = Panel.new({
    id = opts.id or "transport_panel",
    height = opts.height,
    width = opts.width,

    config = {
      bg_color = cfg.panel_bg_color or hexrgb("#00000000"),
      border_thickness = 0,
      rounding = cfg.fx and cfg.fx.rounding or 8,

      background_pattern = {
        enabled = cfg.background_pattern ~= nil,
        primary = cfg.background_pattern and cfg.background_pattern.primary or {},
        secondary = cfg.background_pattern and cfg.background_pattern.secondary or {},
      },

      header = {
        enabled = true,
        height = button_height,
        position = "top",
        valign = "middle",
        bg_color = hexrgb("#00000000"),  -- Transparent so pattern shows through
        border_color = hexrgb("#00000000"),  -- Transparent border
        rounding = cfg.fx and cfg.fx.rounding or 8,
        padding = { left = 0, right = 0 },
        elements = opts.header_elements or {},
      },

      corner_buttons = cfg.corner_buttons or nil,
      corner_buttons_always_visible = true,  -- Show corner buttons even with header
    },
  })

  local container = setmetatable({
    panel = panel,
    id = opts.id or "transport_panel",
    config = cfg,

    height = opts.height,
    width = opts.width,

    hover_alpha = 0.0,
    last_bounds = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 },

    on_hover_changed = opts.on_hover_changed,

    current_region_color = nil,
    next_region_color = nil,
    target_current_color = nil,
    target_next_color = nil,

    -- Jump flash effect
    jump_flash_alpha = 0.0,
    jump_flash_state = "idle",  -- "idle", "holding", "fading"
    jump_target_rid = nil,      -- Target region ID we're jumping to
  }, TransportPanel)

  return container
end

function TransportPanel:update_hover_state(ctx, x1, y1, x2, y2, dt)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x1 and mx < x2 and my >= y1 and my < y2

  local target_alpha = is_hovered and 1.0 or 0.0
  local fade_speed = (self.config.fx and self.config.fx.hover and self.config.fx.hover.transition_speed) or 6.0

  local delta = (target_alpha - self.hover_alpha) * fade_speed * dt
  self.hover_alpha = max(0.0, min(1.0, self.hover_alpha + delta))

  return is_hovered
end

-- Trigger jump flash effect (call when jump button is clicked)
function TransportPanel:trigger_jump_flash(target_rid)
  self.jump_flash_alpha = 1.0
  self.jump_flash_state = "holding"
  self.jump_target_rid = target_rid
end

-- Cancel jump flash effect (call when transport stops or transition cancelled)
function TransportPanel:cancel_jump_flash()
  self.jump_flash_alpha = 0.0
  self.jump_flash_state = "idle"
  self.jump_target_rid = nil
end

-- Update jump flash (hold during transition, fade after reaching target)
function TransportPanel:update_jump_flash(dt, current_rid)
  if self.jump_flash_state == "holding" then
    -- Hold at full opacity until we reach the target region
    if current_rid and self.jump_target_rid and current_rid == self.jump_target_rid then
      -- Transition complete, start fading
      self.jump_flash_state = "fading"
    end
    -- Keep alpha at 1.0 while holding
    self.jump_flash_alpha = 1.0

  elseif self.jump_flash_state == "fading" then
    -- Fade out
    if self.jump_flash_alpha > 0.0 then
      local fade_speed = (self.config.fx and self.config.fx.jump_flash and self.config.fx.jump_flash.fade_speed) or 3.0
      local fade_delta = fade_speed * dt
      self.jump_flash_alpha = max(0.0, self.jump_flash_alpha - fade_delta)

      if self.jump_flash_alpha == 0.0 then
        self.jump_flash_state = "idle"
        self.jump_target_rid = nil
      end
    end
  end
end

function TransportPanel:update_region_colors(ctx, target_current, target_next)
  local dt = ImGui.GetDeltaTime(ctx)
  local fade_speed = self.config.fx.gradient.fade_speed or 8.0
  
  if not self.current_region_color then
    self.current_region_color = target_current
    self.next_region_color = target_next
    self.target_current_color = target_current
    self.target_next_color = target_next
    return
  end
  
  self.target_current_color = target_current
  self.target_next_color = target_next
  
  local function lerp_color(from, to, t)
    if not from and not to then return nil end
    if not from then
      local ready_color = self.config.fx.gradient.ready_color or Colors.hexrgb("#1A1A1A")
      from = ready_color
    end
    if not to then
      local ready_color = self.config.fx.gradient.ready_color or Colors.hexrgb("#1A1A1A")
      to = ready_color
    end

    local r1, g1, b1, a1 = Colors.rgba_to_components(from)
    local r2, g2, b2, a2 = Colors.rgba_to_components(to)

    local r = (r1 + (r2 - r1) * t)//1
    local g = (g1 + (g2 - g1) * t)//1
    local b = (b1 + (b2 - b1) * t)//1
    local a = (a1 + (a2 - a1) * t)//1

    return Colors.components_to_rgba(r, g, b, a)
  end

  local lerp_factor = min(1.0, fade_speed * dt)
  
  if self.target_current_color then
    self.current_region_color = lerp_color(self.current_region_color, self.target_current_color, lerp_factor)
  else
    local ready_color = self.config.fx.gradient.ready_color or Colors.hexrgb("#1A1A1A")
    if self.current_region_color then
      self.current_region_color = lerp_color(self.current_region_color, ready_color, lerp_factor)
      if abs((self.current_region_color or 0) - ready_color) < 256 then
        self.current_region_color = nil
      end
    else
      self.current_region_color = nil
    end
  end
  
  if self.target_next_color then
    self.next_region_color = lerp_color(self.next_region_color, self.target_next_color, lerp_factor)
  else
    local ready_color = self.config.fx.gradient.ready_color or Colors.hexrgb("#1A1A1A")
    if self.next_region_color then
      self.next_region_color = lerp_color(self.next_region_color, ready_color, lerp_factor)
      if abs((self.next_region_color or 0) - ready_color) < 256 then
        self.next_region_color = nil
      end
    else
      self.next_region_color = nil
    end
  end
end

function TransportPanel:begin_draw(ctx, region_colors, current_rid)
  region_colors = region_colors or {}
  local target_current = region_colors.current
  local target_next = region_colors.next

  local dt = ImGui.GetDeltaTime(ctx)

  self:update_region_colors(ctx, target_current, target_next)
  self:update_jump_flash(dt, current_rid)

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local w = self.width or avail_w
  local h = self.height

  local x1, y1 = cursor_x, cursor_y
  local x2, y2 = x1 + w, y1 + h

  self.last_bounds = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }

  local dl = ImGui.GetWindowDrawList(ctx)
  local is_hovered = self:update_hover_state(ctx, x1, y1, x2, y2, dt)

  -- Pass jump flash alpha to render for gradient boost
  TransportFX.render_complete(dl, x1, y1, x2, y2, self.config.fx, self.hover_alpha,
    self.current_region_color, self.next_region_color, self.jump_flash_alpha)

  if self.on_hover_changed then
    self.on_hover_changed(is_hovered, self.hover_alpha)
  end

  local success = self.panel:begin_draw(ctx)

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
  self.jump_flash_alpha = 0.0
  self.jump_flash_state = "idle"
  self.jump_target_rid = nil
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

function M.draw(ctx, id, width, height, content_fn, config, region_colors, current_rid)
  if not config then
    error("TransportContainer.draw requires config parameter")
  end

  region_colors = region_colors or {}

  local container = M.new({
    id = id,
    width = width,
    height = height,
    config = config,
  })

  local content_w, content_h = container:begin_draw(ctx, region_colors, current_rid)

  if content_fn then
    content_fn(ctx, content_w, content_h)
  end

  container:end_draw(ctx)

  return container
end

return M
