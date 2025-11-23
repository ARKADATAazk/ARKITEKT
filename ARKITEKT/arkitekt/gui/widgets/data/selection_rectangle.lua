-- @noindex
-- Arkitekt/gui/widgets/selection_rectangle.lua
-- Standalone selection rectangle overlay widget  
-- Marquee selection (LEFT click + drag on background, square corners)
-- FIXED: Scroll-aware selection maintains origin point

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

local SelRect = {}
SelRect.__index = SelRect

function M.new(opts)
  opts = opts or {}

  return setmetatable({
    active = false,
    mode = "replace",
    start_pos = nil,
    current_pos = nil,
    dragged = false,
    
    start_scroll_x = 0,
    start_scroll_y = 0,
    ctx = nil,
  }, SelRect)
end

function SelRect:begin(x, y, mode, ctx)
  self.active = true
  self.mode = mode or "replace"
  self.ctx = ctx
  
  if ctx then
    self.start_scroll_x = ImGui.GetScrollX(ctx)
    self.start_scroll_y = ImGui.GetScrollY(ctx)
  else
    self.start_scroll_x = 0
    self.start_scroll_y = 0
  end
  
  self.start_pos = {x, y}
  self.current_pos = {x, y}
  self.dragged = false
end

function SelRect:update(x, y)
  if not self.active then return end
  self.current_pos = {x, y}
  
  if self.start_pos then
    local dx = math.abs(x - self.start_pos[1])
    local dy = math.abs(y - self.start_pos[2])
    if dx > 3 or dy > 3 then
      self.dragged = true
    end
  end
end

function SelRect:is_active()
  return self.active
end

function SelRect:did_drag()
  return self.dragged
end

function SelRect:aabb()
  if not self.active or not self.start_pos or not self.current_pos then
    return nil
  end

  local scroll_delta_x = 0
  local scroll_delta_y = 0
  
  if self.ctx then
    local current_scroll_x = ImGui.GetScrollX(self.ctx)
    local current_scroll_y = ImGui.GetScrollY(self.ctx)
    
    scroll_delta_x = current_scroll_x - self.start_scroll_x
    scroll_delta_y = current_scroll_y - self.start_scroll_y
  end
  
  local adjusted_start_x = self.start_pos[1] - scroll_delta_x
  local adjusted_start_y = self.start_pos[2] - scroll_delta_y
  
  local x1 = math.min(adjusted_start_x, self.current_pos[1])
  local y1 = math.min(adjusted_start_y, self.current_pos[2])
  local x2 = math.max(adjusted_start_x, self.current_pos[1])
  local y2 = math.max(adjusted_start_y, self.current_pos[2])

  x1 = math.floor(x1 + 0.5)
  y1 = math.floor(y1 + 0.5)
  x2 = math.floor(x2 + 0.5)
  y2 = math.floor(y2 + 0.5)

  return x1, y1, x2, y2
end

function SelRect:aabb_visual()
  return self:aabb()
end

function SelRect:clear()
  self.active = false
  self.start_pos = nil
  self.current_pos = nil
  self.mode = "replace"
  self.dragged = false
  self.start_scroll_x = 0
  self.start_scroll_y = 0
  self.ctx = nil
end

function SelRect:finish()
  local x1, y1, x2, y2 = self:aabb()
  local did_drag = self.dragged
  self:clear()
  return x1, y1, x2, y2, did_drag
end

return M