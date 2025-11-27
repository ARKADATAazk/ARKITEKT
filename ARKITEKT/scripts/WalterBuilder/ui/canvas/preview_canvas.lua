-- @noindex
-- WalterBuilder/ui/canvas/preview_canvas.lua
-- Main resizable preview canvas for WALTER layout visualization

local ImGui = require 'imgui' '0.10'
local Colors = require('WalterBuilder.defs.colors')
local Simulator = require('WalterBuilder.domain.simulator')
local ElementRenderer = require('WalterBuilder.ui.canvas.element_renderer')

local M = {}
local Canvas = {}
Canvas.__index = Canvas

-- Default canvas configuration
local DEFAULT_CONFIG = {
  min_parent_w = 150,
  min_parent_h = 60,
  max_parent_w = 800,
  max_parent_h = 400,
  default_parent_w = 300,
  default_parent_h = 90,
  grid_size = 10,
  show_grid = true,
  show_attachments = true,
  handle_size = 8,
}

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Parent container dimensions (what user resizes)
    parent_w = opts.parent_w or DEFAULT_CONFIG.default_parent_w,
    parent_h = opts.parent_h or DEFAULT_CONFIG.default_parent_h,

    -- Configuration
    config = {
      min_parent_w = opts.min_parent_w or DEFAULT_CONFIG.min_parent_w,
      min_parent_h = opts.min_parent_h or DEFAULT_CONFIG.min_parent_h,
      max_parent_w = opts.max_parent_w or DEFAULT_CONFIG.max_parent_w,
      max_parent_h = opts.max_parent_h or DEFAULT_CONFIG.max_parent_h,
      grid_size = opts.grid_size or DEFAULT_CONFIG.grid_size,
      show_grid = opts.show_grid ~= false,
      show_attachments = opts.show_attachments ~= false,
      handle_size = opts.handle_size or DEFAULT_CONFIG.handle_size,
    },

    -- Interaction state
    dragging = nil,  -- nil, "right", "bottom", "corner"
    drag_start_w = 0,
    drag_start_h = 0,
    drag_start_x = 0,
    drag_start_y = 0,

    -- Selection
    selected_element = nil,
    hovered_element = nil,

    -- Elements to display
    elements = {},

    -- Cached simulation results
    sim_cache = nil,
    sim_cache_w = 0,
    sim_cache_h = 0,

    -- Canvas offset (for centering/scrolling)
    offset_x = 20,
    offset_y = 20,

    -- Element renderer instance
    renderer = ElementRenderer.new(),
  }, Canvas)

  return self
end

-- Set elements to display
function Canvas:set_elements(elements)
  self.elements = elements
  self.sim_cache = nil  -- Invalidate cache
end

-- Set selected element
function Canvas:set_selected(element)
  self.selected_element = element
end

-- Get simulation results (cached)
function Canvas:get_simulation()
  if self.sim_cache and self.sim_cache_w == self.parent_w and self.sim_cache_h == self.parent_h then
    return self.sim_cache
  end

  self.sim_cache = Simulator.simulate(self.elements, self.parent_w, self.parent_h)
  self.sim_cache_w = self.parent_w
  self.sim_cache_h = self.parent_h

  return self.sim_cache
end

-- Draw grid lines
function Canvas:draw_grid(ctx, dl, canvas_x, canvas_y)
  if not self.config.show_grid then return end

  local grid = self.config.grid_size
  local w, h = self.parent_w, self.parent_h

  -- Minor grid lines
  for x = grid, w - 1, grid do
    local px = canvas_x + x
    ImGui.DrawList_AddLine(dl, px, canvas_y, px, canvas_y + h, Colors.CANVAS.GRID, 1)
  end
  for y = grid, h - 1, grid do
    local py = canvas_y + y
    ImGui.DrawList_AddLine(dl, canvas_x, py, canvas_x + w, py, Colors.CANVAS.GRID, 1)
  end

  -- Major grid lines (every 50px)
  for x = 50, w - 1, 50 do
    local px = canvas_x + x
    ImGui.DrawList_AddLine(dl, px, canvas_y, px, canvas_y + h, Colors.CANVAS.GRID_MAJOR, 1)
  end
  for y = 50, h - 1, 50 do
    local py = canvas_y + y
    ImGui.DrawList_AddLine(dl, canvas_x, py, canvas_x + w, py, Colors.CANVAS.GRID_MAJOR, 1)
  end
end

-- Draw resize handles
function Canvas:draw_handles(ctx, dl, canvas_x, canvas_y)
  local w, h = self.parent_w, self.parent_h
  local hs = self.config.handle_size

  -- Right edge handle
  local right_handle = {
    x = canvas_x + w - hs/2,
    y = canvas_y + h/2 - hs,
    w = hs,
    h = hs * 2,
  }

  -- Bottom edge handle
  local bottom_handle = {
    x = canvas_x + w/2 - hs,
    y = canvas_y + h - hs/2,
    w = hs * 2,
    h = hs,
  }

  -- Corner handle
  local corner_handle = {
    x = canvas_x + w - hs,
    y = canvas_y + h - hs,
    w = hs,
    h = hs,
  }

  -- Determine colors based on drag state
  local right_color = self.dragging == "right" and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
  local bottom_color = self.dragging == "bottom" and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
  local corner_color = self.dragging == "corner" and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL

  -- Draw handles
  ImGui.DrawList_AddRectFilled(dl,
    right_handle.x, right_handle.y,
    right_handle.x + right_handle.w, right_handle.y + right_handle.h,
    right_color, 2)

  ImGui.DrawList_AddRectFilled(dl,
    bottom_handle.x, bottom_handle.y,
    bottom_handle.x + bottom_handle.w, bottom_handle.y + bottom_handle.h,
    bottom_color, 2)

  ImGui.DrawList_AddRectFilled(dl,
    corner_handle.x, corner_handle.y,
    corner_handle.x + corner_handle.w, corner_handle.y + corner_handle.h,
    corner_color, 2)

  return {
    right = right_handle,
    bottom = bottom_handle,
    corner = corner_handle,
  }
end

-- Check if point is in handle
local function point_in_rect(px, py, rect)
  return px >= rect.x and px <= rect.x + rect.w
     and py >= rect.y and py <= rect.y + rect.h
end

-- Handle mouse interaction
function Canvas:handle_interaction(ctx, canvas_x, canvas_y, handles)
  local mx, my = ImGui.GetMousePos(ctx)

  -- Check for drag start
  if ImGui.IsMouseClicked(ctx, 0) then
    if point_in_rect(mx, my, handles.corner) then
      self.dragging = "corner"
      self.drag_start_w = self.parent_w
      self.drag_start_h = self.parent_h
      self.drag_start_x = mx
      self.drag_start_y = my
    elseif point_in_rect(mx, my, handles.right) then
      self.dragging = "right"
      self.drag_start_w = self.parent_w
      self.drag_start_x = mx
    elseif point_in_rect(mx, my, handles.bottom) then
      self.dragging = "bottom"
      self.drag_start_h = self.parent_h
      self.drag_start_y = my
    else
      -- Check for element selection
      local rel_x = mx - canvas_x
      local rel_y = my - canvas_y
      if rel_x >= 0 and rel_x <= self.parent_w and rel_y >= 0 and rel_y <= self.parent_h then
        local sim = self:get_simulation()
        local clicked = Simulator.hit_test(sim, rel_x, rel_y)
        if clicked then
          self.selected_element = clicked
          return { type = "select", element = clicked }
        end
      end
    end
  end

  -- Handle dragging
  if self.dragging and ImGui.IsMouseDown(ctx, 0) then
    local dx = mx - self.drag_start_x
    local dy = my - self.drag_start_y

    if self.dragging == "right" or self.dragging == "corner" then
      local new_w = self.drag_start_w + dx
      new_w = math.max(self.config.min_parent_w, math.min(self.config.max_parent_w, new_w))
      self.parent_w = math.floor(new_w)
    end

    if self.dragging == "bottom" or self.dragging == "corner" then
      local new_h = self.drag_start_h + dy
      new_h = math.max(self.config.min_parent_h, math.min(self.config.max_parent_h, new_h))
      self.parent_h = math.floor(new_h)
    end

    self.sim_cache = nil  -- Invalidate cache
  end

  -- End dragging
  if ImGui.IsMouseReleased(ctx, 0) then
    self.dragging = nil
  end

  -- Update hovered element
  local rel_x = mx - canvas_x
  local rel_y = my - canvas_y
  if rel_x >= 0 and rel_x <= self.parent_w and rel_y >= 0 and rel_y <= self.parent_h then
    local sim = self:get_simulation()
    self.hovered_element = Simulator.hit_test(sim, rel_x, rel_y)
  else
    self.hovered_element = nil
  end

  return nil
end

-- Main draw function
function Canvas:draw(ctx)
  local result = nil

  -- Get available space
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local canvas_h = math.max(200, avail_h - 40)  -- Leave room for size display

  -- Begin child region for canvas
  if ImGui.BeginChild(ctx, "walter_canvas", avail_w, canvas_h, 1) then
    local win_x, win_y = ImGui.GetWindowPos(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Calculate canvas position (centered)
    local canvas_x = win_x + self.offset_x
    local canvas_y = win_y + self.offset_y

    -- Draw background
    ImGui.DrawList_AddRectFilled(dl, win_x, win_y, win_x + avail_w, win_y + canvas_h,
      Colors.CANVAS.BACKGROUND)

    -- Draw parent container background
    ImGui.DrawList_AddRectFilled(dl,
      canvas_x, canvas_y,
      canvas_x + self.parent_w, canvas_y + self.parent_h,
      Colors.CANVAS.PARENT_FILL)

    -- Draw grid
    self:draw_grid(ctx, dl, canvas_x, canvas_y)

    -- Draw elements
    local sim = self:get_simulation()
    for _, sim_result in ipairs(sim) do
      local is_selected = sim_result.element == self.selected_element
      local is_hovered = sim_result.element == self.hovered_element

      self.renderer:draw_element(ctx, dl, canvas_x, canvas_y, sim_result, {
        selected = is_selected,
        hovered = is_hovered,
        show_attachments = self.config.show_attachments,
      })
    end

    -- Draw parent container border
    ImGui.DrawList_AddRect(dl,
      canvas_x, canvas_y,
      canvas_x + self.parent_w, canvas_y + self.parent_h,
      Colors.CANVAS.PARENT_BORDER, 0, 0, 2)

    -- Draw resize handles
    local handles = self:draw_handles(ctx, dl, canvas_x, canvas_y)

    -- Handle mouse interaction
    result = self:handle_interaction(ctx, canvas_x, canvas_y, handles)

    ImGui.EndChild(ctx)
  end

  -- Draw size display below canvas
  ImGui.Text(ctx, string.format("Parent Size: %d x %d px", self.parent_w, self.parent_h))
  ImGui.SameLine(ctx, 0, 20)

  -- Toggle buttons
  local _, show_grid = ImGui.Checkbox(ctx, "Grid", self.config.show_grid)
  self.config.show_grid = show_grid

  ImGui.SameLine(ctx)
  local _, show_attach = ImGui.Checkbox(ctx, "Attachments", self.config.show_attachments)
  self.config.show_attachments = show_attach

  return result
end

-- Get current parent dimensions
function Canvas:get_parent_size()
  return self.parent_w, self.parent_h
end

-- Set parent dimensions
function Canvas:set_parent_size(w, h)
  self.parent_w = math.max(self.config.min_parent_w, math.min(self.config.max_parent_w, w))
  self.parent_h = math.max(self.config.min_parent_h, math.min(self.config.max_parent_h, h))
  self.sim_cache = nil
end

return M
