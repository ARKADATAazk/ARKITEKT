-- @noindex
-- TemplateBrowser/ui/separator.lua
-- Draggable vertical separator for resizing panels

local ImGui = require 'imgui' '0.10'

local M = {}

local Separator = {}
Separator.__index = Separator

function M.new(id)
  return setmetatable({
    id = id,
    drag_state = {
      is_dragging = false,
      drag_offset = 0
    },
  }, Separator)
end

function Separator:draw_vertical(ctx, x, y, width, height, thickness)
  local separator_thickness = thickness or 8

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x - separator_thickness/2 and mx < x + separator_thickness/2 and
                     my >= y and my < y + height

  if is_hovered or self.drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
  end

  ImGui.SetCursorScreenPos(ctx, x - separator_thickness/2, y)
  ImGui.InvisibleButton(ctx, "##vsep_" .. self.id, separator_thickness, height)

  -- Double-click to reset
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end

  -- Drag handling
  if ImGui.IsItemActive(ctx) then
    if not self.drag_state.is_dragging then
      self.drag_state.is_dragging = true
      self.drag_state.drag_offset = mx - x
    end

    local new_pos = mx - self.drag_state.drag_offset
    return "drag", new_pos
  elseif self.drag_state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    self.drag_state.is_dragging = false
  end

  return "none", x
end

function Separator:draw_horizontal(ctx, x, y, width, height, thickness)
  local separator_thickness = thickness or 8

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + width and
                     my >= y - separator_thickness/2 and my < y + separator_thickness/2

  if is_hovered or self.drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
  end

  ImGui.SetCursorScreenPos(ctx, x, y - separator_thickness/2)
  ImGui.InvisibleButton(ctx, "##hsep_" .. self.id, width, separator_thickness)

  -- Double-click to reset
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end

  -- Drag handling
  if ImGui.IsItemActive(ctx) then
    if not self.drag_state.is_dragging then
      self.drag_state.is_dragging = true
      self.drag_state.drag_offset = my - y
    end

    local new_pos = my - self.drag_state.drag_offset
    return "drag", new_pos
  elseif self.drag_state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    self.drag_state.is_dragging = false
  end

  return "none", y
end

function Separator:is_dragging()
  return self.drag_state.is_dragging
end

return M
