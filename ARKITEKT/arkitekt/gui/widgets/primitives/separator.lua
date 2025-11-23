-- @noindex
-- arkitekt/gui/widgets/controls/draggable_separator.lua
-- Draggable separator for resizing panels

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

local DraggableSeparator = {}
DraggableSeparator.__index = DraggableSeparator

function M.new(id)
  return setmetatable({
    id = id or "separator",
    drag_state = {
      is_dragging = false,
      drag_offset = 0
    },
  }, DraggableSeparator)
end

function DraggableSeparator:draw_horizontal(ctx, x, y, width, height, config_or_thickness)
  -- Support both config table and direct thickness param
  local separator_thickness = type(config_or_thickness) == "table"
    and config_or_thickness.thickness
    or (config_or_thickness or 8)

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + width and
                     my >= y - separator_thickness/2 and my < y + separator_thickness/2

  if is_hovered or self.drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
  end

  ImGui.SetCursorScreenPos(ctx, x, y - separator_thickness/2)
  ImGui.InvisibleButton(ctx, "##hsep_" .. self.id, width, separator_thickness)

  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end

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

function DraggableSeparator:draw_vertical(ctx, x, y, width, height, config_or_thickness)
  -- Support both config table and direct thickness param
  local separator_thickness = type(config_or_thickness) == "table"
    and config_or_thickness.thickness
    or (config_or_thickness or 8)

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x - separator_thickness/2 and mx < x + separator_thickness/2 and
                     my >= y and my < y + height

  if is_hovered or self.drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
  end

  ImGui.SetCursorScreenPos(ctx, x - separator_thickness/2, y)
  ImGui.InvisibleButton(ctx, "##vsep_" .. self.id, separator_thickness, height)

  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end

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

function DraggableSeparator:is_dragging()
  return self.drag_state.is_dragging
end

return M
