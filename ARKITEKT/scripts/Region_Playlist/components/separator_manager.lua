local ImGui = require 'imgui' '0.10'

local SeparatorManager = {}
SeparatorManager.__index = SeparatorManager

function SeparatorManager.new(deps)
  deps = deps or {}
  local config = deps.Config or deps.config

  local self = setmetatable({
    Config = config,
    drag_state = {
      horizontal = { is_dragging = false, drag_offset = 0 },
      vertical = { is_dragging = false, drag_offset = 0 },
    },
  }, SeparatorManager)

  return self
end

local function horizontal_config(self)
  return self.Config and self.Config.SEPARATOR and self.Config.SEPARATOR.horizontal
end

local function vertical_config(self)
  return self.Config and self.Config.SEPARATOR and self.Config.SEPARATOR.vertical
end

function SeparatorManager:draw_horizontal(ctx, x, y, width, height)
  local config = horizontal_config(self)
  if not config then
    return 'none', y
  end

  local state = self.drag_state.horizontal
  local thickness = config.thickness
  local mx, my = ImGui.GetMousePos(ctx)
  local hovered = mx >= x and mx < x + width and my >= y - thickness / 2 and my < y + thickness / 2

  if hovered or state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
  end

  ImGui.SetCursorScreenPos(ctx, x, y - thickness / 2)
  ImGui.InvisibleButton(ctx, '##hseparator', width, thickness)

  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    state.is_dragging = false
    return 'reset', config.default_position or y
  end

  if ImGui.IsItemActive(ctx) then
    if not state.is_dragging then
      state.is_dragging = true
      state.drag_offset = my - y
    end

    local new_pos = my - state.drag_offset
    return 'drag', new_pos
  elseif state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    state.is_dragging = false
  end

  return 'none', y
end

function SeparatorManager:draw_vertical(ctx, x, y, width, height)
  local config = vertical_config(self)
  if not config then
    return 'none', x
  end

  local state = self.drag_state.vertical
  local thickness = config.thickness
  local mx, my = ImGui.GetMousePos(ctx)
  local hovered = mx >= x - thickness / 2 and mx < x + thickness / 2 and my >= y and my < y + height

  if hovered or state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
  end

  ImGui.SetCursorScreenPos(ctx, x - thickness / 2, y)
  ImGui.InvisibleButton(ctx, '##vseparator', thickness, height)

  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    state.is_dragging = false
    return 'reset', config.default_position or x
  end

  if ImGui.IsItemActive(ctx) then
    if not state.is_dragging then
      state.is_dragging = true
      state.drag_offset = mx - x
    end

    local new_pos = mx - state.drag_offset
    return 'drag', new_pos
  elseif state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    state.is_dragging = false
  end

  return 'none', x
end

return SeparatorManager
