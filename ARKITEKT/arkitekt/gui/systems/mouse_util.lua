-- @noindex
-- Arkitekt/gui/systems/mouse_util.lua
-- Mouse utilities for differentiating clicks from drags

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Default configuration
M.DEFAULTS = {
  DRAG_THRESHOLD = 5,  -- Pixels to move before considering it a drag
}

-- Track potential drag states by ID
local drag_states = {}

-- Start tracking a potential drag operation
-- Call this when mouse button is pressed on an item
function M.start_potential_drag(ctx, id, button)
  button = button or 0
  local mx, my = ImGui.GetMousePos(ctx)

  drag_states[id] = {
    start_x = mx,
    start_y = my,
    button = button,
    is_dragging = false,
    was_click = false,
  }
end

-- Check if a drag has started (threshold exceeded)
-- Returns true once when threshold is first exceeded
function M.check_drag_started(ctx, id, threshold)
  threshold = threshold or M.DEFAULTS.DRAG_THRESHOLD
  local state = drag_states[id]
  if not state then return false end

  -- Already determined to be dragging
  if state.is_dragging then return false end

  -- Check if mouse is still held
  if not ImGui.IsMouseDown(ctx, state.button) then
    return false
  end

  local mx, my = ImGui.GetMousePos(ctx)
  local dx = math.abs(mx - state.start_x)
  local dy = math.abs(my - state.start_y)

  if dx > threshold or dy > threshold then
    state.is_dragging = true
    return true
  end

  return false
end

-- Check if currently in drag mode (after threshold exceeded)
function M.is_dragging(id)
  local state = drag_states[id]
  return state and state.is_dragging
end

-- Check if this was a click (mouse released without exceeding drag threshold)
-- Returns true once when mouse is released without dragging
function M.check_click(ctx, id)
  local state = drag_states[id]
  if not state then return false end

  -- If already determined to be dragging, not a click
  if state.is_dragging then return false end

  -- Check if mouse was released
  if ImGui.IsMouseReleased(ctx, state.button) then
    state.was_click = true
    return true
  end

  return false
end

-- Get the distance moved from start position
function M.get_drag_delta(ctx, id)
  local state = drag_states[id]
  if not state then return 0, 0 end

  local mx, my = ImGui.GetMousePos(ctx)
  return mx - state.start_x, my - state.start_y
end

-- Clear tracking state for an ID
function M.clear(id)
  drag_states[id] = nil
end

-- Clear all tracking states
function M.clear_all()
  drag_states = {}
end

-- Check if we're tracking a potential drag for this ID
function M.is_tracking(id)
  return drag_states[id] ~= nil
end

-- Get the start position for a tracked drag
function M.get_start_pos(id)
  local state = drag_states[id]
  if not state then return nil, nil end
  return state.start_x, state.start_y
end

return M
