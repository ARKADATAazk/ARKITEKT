-- @noindex
-- arkitekt/runtime/chrome/window/docking.lua
-- Dock state tracking and undock restoration

local ImGui = require('arkitekt.core.imgui')
local Helpers = require('arkitekt.runtime.chrome.window.helpers')

local Theme = nil
do
  local ok, mod = pcall(require, 'arkitekt.theme')
  if ok then Theme = mod end
end

local M = {}
local floor = Helpers.floor

--- Create docking state
--- @return table state Docking state object
function M.create_state()
  return {
    was_docked = false,
    last_dock_id = 0,
    pre_dock_pos = nil,
    pre_dock_size = nil,
    stable_pos = nil,
    stable_size = nil,
    drag_start_pos = nil,
    drag_start_size = nil,
    mouse_was_down = false,
    pending_undock = false,
  }
end

--- Load docking state from settings
--- @param settings table|nil Settings object
--- @param dock_state table Docking state to update
function M.load_from_settings(settings, dock_state)
  if not settings then return end

  dock_state.pre_dock_pos = settings:get('window.pre_dock_pos', nil)
  dock_state.pre_dock_size = settings:get('window.pre_dock_size', nil)
end

--- Track floating window position for seamless undocking
--- @param ctx userdata ImGui context
--- @param dock_state table Docking state
function M.track_floating_position(ctx, dock_state)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  local current_pos = { x = floor(wx), y = floor(wy) }
  local current_size = { w = floor(ww), h = floor(wh) }

  -- Check if left mouse button is down
  local mouse_down = ImGui.IsMouseDown and ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) or false

  -- Capture position at the moment of mouse down (start of drag)
  if mouse_down and not dock_state.mouse_was_down then
    dock_state.drag_start_pos = current_pos
    dock_state.drag_start_size = current_size
  end

  -- Update stable position when mouse is not down
  if not mouse_down then
    dock_state.stable_pos = current_pos
    dock_state.stable_size = current_size
  end

  dock_state.mouse_was_down = mouse_down
end

--- Handle transition to docked state
--- @param dock_state table Docking state
--- @param settings table|nil Settings object
function M.on_dock_enter(dock_state, settings)
  -- Save position from drag start (where window was before drag began)
  -- Fallback to stable_pos if drag_start not available
  dock_state.pre_dock_pos = dock_state.drag_start_pos or dock_state.stable_pos
  dock_state.pre_dock_size = dock_state.drag_start_size or dock_state.stable_size

  -- Clear drag start after using it
  dock_state.drag_start_pos = nil
  dock_state.drag_start_size = nil

  -- Persist pre-dock state for seamless undocking after restart
  if settings then
    settings:set('window.pre_dock_pos', dock_state.pre_dock_pos)
    settings:set('window.pre_dock_size', dock_state.pre_dock_size)
  end

  -- Apply REAPER theme without offset when docking (if enabled)
  if Theme and Theme.is_dock_adapt_enabled and Theme.is_dock_adapt_enabled() then
    Theme.sync_with_reaper_no_offset()
  end
end

--- Handle transition to floating state
--- @param dock_state table Docking state
--- @param settings table|nil Settings object
function M.on_dock_exit(dock_state, settings)
  -- Mark for restoration on next frame
  if dock_state.pre_dock_pos or dock_state.pre_dock_size then
    dock_state.pending_undock = true
  end

  -- Clear pre-dock state from settings
  if settings then
    settings:set('window.pre_dock_pos', nil)
    settings:set('window.pre_dock_size', nil)
  end
end

--- Process dock state changes
--- @param ctx userdata ImGui context
--- @param dock_state table Docking state
--- @param settings table|nil Settings object
--- @return boolean is_docked Current docked state
function M.update(ctx, dock_state, settings)
  if not ImGui.GetWindowDockID then
    return false
  end

  local dock_id = ImGui.GetWindowDockID(ctx)
  local is_docked = (dock_id ~= 0)

  -- Track position when floating to enable seamless undocking
  if not is_docked then
    M.track_floating_position(ctx, dock_state)
  end

  -- Check if we just transitioned to docked state
  if dock_id ~= 0 and dock_state.last_dock_id == 0 then
    M.on_dock_enter(dock_state, settings)
  end

  -- Check if we just transitioned to floating state
  if dock_id == 0 and dock_state.last_dock_id ~= 0 then
    M.on_dock_exit(dock_state, settings)
  end

  dock_state.was_docked = is_docked
  dock_state.last_dock_id = dock_id

  return is_docked
end

--- Clear pending undock state after restoration
--- @param dock_state table Docking state
function M.clear_pending_undock(dock_state)
  dock_state.pending_undock = false
  dock_state.pre_dock_pos = nil
  dock_state.pre_dock_size = nil
end

return M
