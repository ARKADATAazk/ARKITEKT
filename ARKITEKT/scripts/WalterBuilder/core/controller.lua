-- @noindex
-- WalterBuilder/core/controller.lua
-- Business logic controller - separates UI from state mutations

local Constants = require('WalterBuilder.defs.constants')
local UndoManager = require('arkitekt.core.undo_manager')
local Logger = require('arkitekt.debug.logger')

local M = {}
local Controller = {}
Controller.__index = Controller

-- Enable for verbose logging
local DEBUG_CONTROLLER = false

function M.new(State, settings)
  local self = setmetatable({
    State = State,
    settings = settings,
    undo_manager = UndoManager.new({ max_history = 50 }),

    -- Status notification callback
    on_status = nil,

    -- Change callbacks (for UI sync)
    on_elements_changed = nil,
    on_tracks_changed = nil,
    on_selection_changed = nil,
  }, Controller)

  if DEBUG_CONTROLLER then
    Logger.info("CONTROLLER", "Initialized with undo manager")
  end

  return self
end

-- ============================================================================
-- UNDO/REDO SUPPORT
-- ============================================================================

-- Capture current state snapshot for undo
function Controller:capture_snapshot(action_type)
  local snapshot = {
    action = action_type,
    elements = self:_clone_elements(),
    tracks = self:_clone_tracks(),
    selected_element_id = self.State.get_selected() and self.State.get_selected().id or nil,
    selected_track_id = self.State.get_selected_track() and self.State.get_selected_track().id or nil,
    parent_w = self.State.get_parent_size(),
  }
  self.undo_manager:push(snapshot)

  if DEBUG_CONTROLLER then
    Logger.debug("CONTROLLER", "Captured snapshot: %s", action_type)
  end
end

-- Clone elements for snapshot
function Controller:_clone_elements()
  local elements = self.State.get_elements()
  local cloned = {}
  for _, elem in ipairs(elements) do
    cloned[#cloned + 1] = {
      id = elem.id,
      name = elem.name,
      category = elem.category,
      visible = elem.visible,
      coords = {
        x = elem.coords.x,
        y = elem.coords.y,
        w = elem.coords.w,
        h = elem.coords.h,
        ls = elem.coords.ls,
        ts = elem.coords.ts,
        rs = elem.coords.rs,
        bs = elem.coords.bs,
      },
    }
  end
  return cloned
end

-- Clone tracks for snapshot
function Controller:_clone_tracks()
  local tracks = self.State.get_tracks()
  local cloned = {}
  for _, track in ipairs(tracks) do
    cloned[#cloned + 1] = {
      id = track.id,
      name = track.name,
      height = track.height,
      color = track.color,
      armed = track.armed,
      muted = track.muted,
      soloed = track.soloed,
      folder_state = track.folder_state,
      folder_depth = track.folder_depth,
      visible = track.visible,
    }
  end
  return cloned
end

-- Restore state from snapshot
function Controller:_restore_snapshot(snapshot)
  if not snapshot then return false end

  -- Restore elements
  self.State.load_elements(snapshot.elements)

  -- Restore tracks
  self.State.clear_tracks()
  for _, track_data in ipairs(snapshot.tracks) do
    self.State.add_track(track_data)
  end

  -- Restore selection
  if snapshot.selected_element_id then
    local elem = self.State.get_element(snapshot.selected_element_id)
    self.State.set_selected(elem)
  else
    self.State.clear_selection()
  end

  if snapshot.selected_track_id then
    for _, track in ipairs(self.State.get_tracks()) do
      if track.id == snapshot.selected_track_id then
        self.State.set_selected_track(track)
        break
      end
    end
  else
    self.State.set_selected_track(nil)
  end

  -- Notify UI
  self:_notify_change("elements")
  self:_notify_change("tracks")
  self:_notify_change("selection")

  return true
end

-- Undo last action
function Controller:undo()
  if not self.undo_manager:can_undo() then
    self:_notify_status("Nothing to undo", Constants.STATUS.INFO)
    return false
  end

  local snapshot = self.undo_manager:undo()
  local success = self:_restore_snapshot(snapshot)

  if success then
    self:_notify_status("Undo: " .. (snapshot.action or "action"), Constants.STATUS.INFO)
  end

  return success
end

-- Redo last undone action
function Controller:redo()
  if not self.undo_manager:can_redo() then
    self:_notify_status("Nothing to redo", Constants.STATUS.INFO)
    return false
  end

  local snapshot = self.undo_manager:redo()
  local success = self:_restore_snapshot(snapshot)

  if success then
    self:_notify_status("Redo: " .. (snapshot.action or "action"), Constants.STATUS.INFO)
  end

  return success
end

function Controller:can_undo()
  return self.undo_manager:can_undo()
end

function Controller:can_redo()
  return self.undo_manager:can_redo()
end

-- ============================================================================
-- ELEMENT OPERATIONS
-- ============================================================================

-- Add element from definition
function Controller:add_element(def)
  self:capture_snapshot(Constants.UNDO_ACTIONS.ADD_ELEMENT)

  local elem = self.State.add_element(def)
  if elem then
    self.State.set_selected(elem)
    self:_notify_change("elements")
    self:_notify_change("selection")
    self:_notify_status("Added: " .. (elem.name or elem.id), Constants.STATUS.SUCCESS)

    if DEBUG_CONTROLLER then
      Logger.debug("CONTROLLER", "Added element: %s", elem.id)
    end
  end

  return elem
end

-- Add a pre-built Element object directly (for rtconfig loading)
-- Does not capture undo snapshot individually - caller should handle batch undo
function Controller:add_element_direct(element)
  local elem = self.State.add_element_direct(element)
  if elem and DEBUG_CONTROLLER then
    Logger.debug("CONTROLLER", "Added element directly: %s", elem.id)
  end
  return elem
end

-- Remove element
function Controller:remove_element(element)
  if not element then return false end

  self:capture_snapshot(Constants.UNDO_ACTIONS.REMOVE_ELEMENT)

  local name = element.name or element.id
  local success = self.State.remove_element(element)

  if success then
    self.State.clear_selection()
    self:_notify_change("elements")
    self:_notify_change("selection")
    self:_notify_status("Removed: " .. name, Constants.STATUS.INFO)
  end

  return success
end

-- Update element properties
function Controller:update_element(element, changes)
  if not element then return false end

  self:capture_snapshot(Constants.UNDO_ACTIONS.UPDATE_ELEMENT)

  -- Apply changes
  for key, value in pairs(changes) do
    if key == "coords" then
      for coord_key, coord_val in pairs(value) do
        element.coords[coord_key] = coord_val
      end
    else
      element[key] = value
    end
  end

  self.State.element_changed(element)
  self:_notify_change("elements")

  return true
end

-- Clear all elements
function Controller:clear_elements()
  self:capture_snapshot(Constants.UNDO_ACTIONS.CLEAR_ALL)

  self.State.clear_elements()
  self.State.clear_selection()
  self:_notify_change("elements")
  self:_notify_change("selection")
  self:_notify_status("Cleared all elements", Constants.STATUS.INFO)
end

-- Load default TCP layout
function Controller:load_tcp_defaults()
  self:capture_snapshot(Constants.UNDO_ACTIONS.LOAD_DEFAULTS)

  self.State.load_tcp_defaults()
  self.State.clear_selection()
  self:_notify_change("elements")
  self:_notify_change("selection")
  self:_notify_status("Loaded default TCP layout", Constants.STATUS.SUCCESS)
end

-- ============================================================================
-- TRACK OPERATIONS
-- ============================================================================

-- Add a new track
function Controller:add_track(opts)
  self:capture_snapshot(Constants.UNDO_ACTIONS.ADD_TRACK)

  local track = self.State.add_track(opts)
  if track then
    self.State.set_selected_track(track)
    self:_notify_change("tracks")
    self:_notify_change("selection")
    self:_notify_status("Added track: " .. track.name, Constants.STATUS.SUCCESS)
  end

  return track
end

-- Remove a track
function Controller:remove_track(track)
  if not track then return false end

  self:capture_snapshot(Constants.UNDO_ACTIONS.REMOVE_TRACK)

  local name = track.name
  local success = self.State.remove_track(track)

  if success then
    self.State.set_selected_track(nil)
    self:_notify_change("tracks")
    self:_notify_change("selection")
    self:_notify_status("Removed track: " .. name, Constants.STATUS.INFO)
  end

  return success
end

-- Update track properties
function Controller:update_track(track, changes)
  if not track then return false end

  self:capture_snapshot(Constants.UNDO_ACTIONS.UPDATE_TRACK)

  -- Apply changes
  for key, value in pairs(changes) do
    track[key] = value
  end

  self:_notify_change("tracks")

  return true
end

-- Load default demo tracks
function Controller:load_default_tracks()
  self:capture_snapshot(Constants.UNDO_ACTIONS.LOAD_DEFAULTS)

  self.State.load_default_tracks()
  self.State.set_selected_track(nil)
  self:_notify_change("tracks")
  self:_notify_change("selection")
  self:_notify_status("Reset to default tracks", Constants.STATUS.SUCCESS)
end

-- ============================================================================
-- SELECTION OPERATIONS
-- ============================================================================

-- Select element
function Controller:select_element(element)
  self.State.set_selected(element)
  self:_notify_change("selection")
end

-- Select track
function Controller:select_track(track)
  self.State.set_selected_track(track)
  self:_notify_change("selection")
end

-- Clear all selection
function Controller:clear_selection()
  self.State.clear_selection()
  self.State.set_selected_track(nil)
  self:_notify_change("selection")
end

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

-- Notify UI of state changes
function Controller:_notify_change(change_type)
  if change_type == "elements" and self.on_elements_changed then
    self.on_elements_changed()
  elseif change_type == "tracks" and self.on_tracks_changed then
    self.on_tracks_changed()
  elseif change_type == "selection" and self.on_selection_changed then
    self.on_selection_changed()
  end
end

-- Notify status message
function Controller:_notify_status(message, status_type)
  if self.on_status then
    self.on_status(message, status_type or Constants.STATUS.INFO)
  end

  if DEBUG_CONTROLLER then
    Logger.info("CONTROLLER", "[%s] %s", status_type or "info", message)
  end
end

return M
