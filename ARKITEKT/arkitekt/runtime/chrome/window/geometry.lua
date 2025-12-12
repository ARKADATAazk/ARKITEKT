-- @noindex
-- arkitekt/runtime/chrome/window/geometry.lua
-- Window geometry management: position, size, maximize, restore

local ImGui = require('arkitekt.core.imgui')
local Helpers = require('arkitekt.runtime.chrome.window.helpers')

local M = {}
local floor = Helpers.floor

--- Create geometry state
--- @return table state Geometry state object
function M.create_state()
  return {
    is_maximized = false,
    pre_max_pos = nil,
    pre_max_size = nil,
    max_viewport = nil,
    pending_maximize = false,
    pending_restore = false,
    saved_pos = nil,
    saved_size = nil,
    pos_size_set = false,
  }
end

--- Load geometry state from settings
--- @param settings table|nil Settings object
--- @param geo_state table Geometry state to update
function M.load_from_settings(settings, geo_state)
  if not settings then return end

  geo_state.saved_pos = settings:get('window.pos', nil)
  geo_state.saved_size = settings:get('window.size', nil)
  geo_state.is_maximized = settings:get('window.maximized', false)

  -- Load pre-maximize position/size if available (for proper un-maximize)
  if geo_state.is_maximized then
    geo_state.pre_max_pos = settings:get('window.pre_max_pos', nil)
    geo_state.pre_max_size = settings:get('window.pre_max_size', nil)
  end
end

--- Calculate viewport for maximization
--- @param wx number Window X position
--- @param wy number Window Y position
--- @param ww number Window width
--- @param wh number Window height
--- @return table viewport Viewport bounds {x, y, w, h}
local function calculate_viewport(wx, wy, ww, wh)
  -- Try JS API first
  if reaper.JS_Window_GetViewportFromRect then
    local left, top, right, bottom = reaper.JS_Window_GetViewportFromRect(
      wx, wy, wx + ww, wy + wh, true
    )
    if left and right and top and bottom then
      return {
        x = left,
        y = top,
        w = right - left,
        h = bottom - top,
      }
    end
  end

  -- Fallback calculation
  local monitor_width = 1920
  local monitor_height = 1080
  local taskbar_offset = 40
  local monitor_index = math.floor((wx + monitor_width / 2) / monitor_width)
  local monitor_left = monitor_index * monitor_width

  return {
    x = monitor_left,
    y = 0,
    w = monitor_width,
    h = monitor_height - taskbar_offset,
  }
end

--- Toggle maximize state
--- @param ctx userdata ImGui context
--- @param geo_state table Geometry state
--- @param settings table|nil Settings object
--- @param on_maximized_changed function|nil Callback when maximize state changes
function M.toggle_maximize(ctx, geo_state, settings, on_maximized_changed)
  if not ctx then return end

  if geo_state.is_maximized then
    -- Restore
    geo_state.is_maximized = false
    geo_state.pending_restore = true
  else
    -- Maximize
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    geo_state.pre_max_pos = { x = floor(wx), y = floor(wy) }
    geo_state.pre_max_size = { w = floor(ww), h = floor(wh) }
    geo_state.max_viewport = calculate_viewport(wx, wy, ww, wh)
    geo_state.is_maximized = true
  end

  -- Notify callback
  if on_maximized_changed then
    on_maximized_changed(geo_state.is_maximized)
  end

  -- Save to settings
  if settings then
    settings:set('window.maximized', geo_state.is_maximized)

    if geo_state.is_maximized and geo_state.pre_max_pos and geo_state.pre_max_size then
      settings:set('window.pre_max_pos', geo_state.pre_max_pos)
      settings:set('window.pre_max_size', geo_state.pre_max_size)
    elseif not geo_state.is_maximized then
      settings:set('window.pre_max_pos', nil)
      settings:set('window.pre_max_size', nil)
    end
  end
end

--- Apply fullscreen geometry
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
local function apply_fullscreen_geometry(ctx, fullscreen)
  local x, y, w, h

  if fullscreen.use_viewport then
    local viewport = ImGui.GetMainViewport(ctx)
    x, y = ImGui.Viewport_GetPos(viewport)
    w, h = ImGui.Viewport_GetSize(viewport)
  else
    x, y = ImGui.GetWindowPos(ctx)
    w, h = ImGui.GetWindowSize(ctx)
  end

  ImGui.SetNextWindowPos(ctx, x, y, ImGui.Cond_Always)
  ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Always)
end

--- Apply maximized geometry (on launch without viewport)
--- @param geo_state table Geometry state
--- @param initial_pos table|nil Initial position config
local function ensure_max_viewport(geo_state, initial_pos)
  if geo_state.max_viewport then return end

  local pos = geo_state.pre_max_pos or geo_state.saved_pos or initial_pos
  if not pos or not pos.x or not pos.y then return end

  geo_state.max_viewport = calculate_viewport(pos.x, pos.y, 100, 100)
end

--- Apply geometry before ImGui.Begin
--- @param ctx userdata ImGui context
--- @param geo_state table Geometry state
--- @param dock_state table Docking state
--- @param fullscreen table|nil Fullscreen state
--- @param initial_pos table|nil Initial position config
--- @param initial_size table|nil Initial size config
--- @param min_size table|nil Minimum size config
function M.apply(ctx, geo_state, dock_state, fullscreen, initial_pos, initial_size, min_size)
  -- Fullscreen mode
  if fullscreen and fullscreen.enabled then
    apply_fullscreen_geometry(ctx, fullscreen)
    geo_state.pos_size_set = true

  -- Maximized with viewport
  elseif geo_state.is_maximized and geo_state.max_viewport then
    if geo_state.max_viewport.x and geo_state.max_viewport.y then
      ImGui.SetNextWindowPos(ctx, geo_state.max_viewport.x, geo_state.max_viewport.y, ImGui.Cond_Always)
    end
    ImGui.SetNextWindowSize(ctx, geo_state.max_viewport.w, geo_state.max_viewport.h, ImGui.Cond_Always)
    geo_state.pos_size_set = true

  -- Maximized on launch (need to calculate viewport)
  elseif geo_state.is_maximized and not geo_state.max_viewport then
    ensure_max_viewport(geo_state, initial_pos)
    if geo_state.max_viewport then
      if geo_state.max_viewport.x and geo_state.max_viewport.y then
        ImGui.SetNextWindowPos(ctx, geo_state.max_viewport.x, geo_state.max_viewport.y, ImGui.Cond_Always)
      end
      ImGui.SetNextWindowSize(ctx, geo_state.max_viewport.w, geo_state.max_viewport.h, ImGui.Cond_Always)
      geo_state.pos_size_set = true
    end

  -- Restoring from maximized
  elseif geo_state.pending_restore and geo_state.pre_max_pos then
    ImGui.SetNextWindowPos(ctx, geo_state.pre_max_pos.x, geo_state.pre_max_pos.y, ImGui.Cond_Always)
    ImGui.SetNextWindowSize(ctx, geo_state.pre_max_size.w, geo_state.pre_max_size.h, ImGui.Cond_Always)
    geo_state.pending_restore = false
    geo_state.pos_size_set = true

  -- Manual position change (e.g., titlebar drag)
  elseif geo_state.pending_pos then
    ImGui.SetNextWindowPos(ctx, geo_state.pending_pos.x, geo_state.pending_pos.y, ImGui.Cond_Always)
    geo_state.pending_pos = nil

  -- Undocking restoration
  elseif dock_state.pending_undock and (dock_state.pre_dock_pos or dock_state.pre_dock_size) then
    if dock_state.pre_dock_pos then
      ImGui.SetNextWindowPos(ctx, dock_state.pre_dock_pos.x, dock_state.pre_dock_pos.y, ImGui.Cond_Always)
    end
    if dock_state.pre_dock_size then
      ImGui.SetNextWindowSize(ctx, dock_state.pre_dock_size.w, dock_state.pre_dock_size.h, ImGui.Cond_Always)
    end
    dock_state.pending_undock = false
    geo_state.pos_size_set = false
    dock_state.pre_dock_pos = nil
    dock_state.pre_dock_size = nil

  -- Initial/saved position
  elseif not geo_state.pos_size_set then
    local pos = geo_state.saved_pos or initial_pos
    local size = geo_state.saved_size or initial_size
    if pos and pos.x and pos.y then
      ImGui.SetNextWindowPos(ctx, pos.x, pos.y, ImGui.Cond_Once)
    end
    if size and size.w and size.h then
      ImGui.SetNextWindowSize(ctx, size.w, size.h, ImGui.Cond_Once)
    end
    geo_state.pos_size_set = true
  end

  -- Apply min size constraints (not in fullscreen)
  if not (fullscreen and fullscreen.enabled) then
    if ImGui.SetNextWindowSizeConstraints and min_size then
      ImGui.SetNextWindowSizeConstraints(ctx, min_size.w, min_size.h, 99999, 99999)
    end
  end
end

--- Save geometry to settings
--- @param ctx userdata ImGui context
--- @param geo_state table Geometry state
--- @param dock_state table Docking state
--- @param fullscreen table|nil Fullscreen state
--- @param settings table|nil Settings object
function M.save(ctx, geo_state, dock_state, fullscreen, settings)
  if not settings then return end
  if geo_state.is_maximized then return end
  if fullscreen and fullscreen.enabled then return end
  if dock_state.was_docked then return end

  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  local pos = { x = floor(wx), y = floor(wy) }
  local size = { w = floor(ww), h = floor(wh) }

  if not geo_state.saved_pos or pos.x ~= geo_state.saved_pos.x or pos.y ~= geo_state.saved_pos.y then
    geo_state.saved_pos = pos
    settings:set('window.pos', pos)
  end
  if not geo_state.saved_size or size.w ~= geo_state.saved_size.w or size.h ~= geo_state.saved_size.h then
    geo_state.saved_size = size
    settings:set('window.size', size)
  end
end

return M
