-- @noindex
-- arkitekt/core/composite_undo.lua
-- Composite undo system that captures both app state and external REAPER state
-- Extracted from RegionPlaylist undo_bridge for reuse
-- Upgrades basic undo_manager with deep state snapshotting and change tracking

local UndoManager = require("arkitekt.core.undo_manager")

local M = {}
local CompositeBridge = {}
CompositeBridge.__index = CompositeBridge

--- Create a new composite undo bridge
--- @param opts table Configuration options
---   - max_history: number (default: 50) Maximum undo history
---   - capture_app_state: function() -> table Custom app state capture
---   - restore_app_state: function(state) -> changes Custom app state restore
---   - capture_external: function() -> table Capture external state (e.g., regions)
---   - restore_external: function(state) -> changes Restore external state
--- @return table bridge The composite undo bridge
function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    undo_manager = UndoManager.new({ max_history = opts.max_history or 50 }),
    capture_app_state = opts.capture_app_state,
    restore_app_state = opts.restore_app_state,
    capture_external = opts.capture_external,
    restore_external = opts.restore_external,
  }, CompositeBridge)

  return self
end

--- Capture a complete snapshot of app and external state
--- @return table snapshot The captured snapshot
function CompositeBridge:capture()
  local snapshot = {
    timestamp = os.time(),
    app_state = nil,
    external_state = nil,
  }

  -- Capture app-specific state
  if self.capture_app_state then
    local ok, result = pcall(self.capture_app_state)
    if ok then
      snapshot.app_state = result
    end
  end

  -- Capture external state (e.g., REAPER regions, markers, etc.)
  if self.capture_external then
    local ok, result = pcall(self.capture_external)
    if ok then
      snapshot.external_state = result
    end
  end

  return snapshot
end

--- Restore a snapshot and return what changed
--- @param snapshot table The snapshot to restore
--- @return boolean success Whether restore succeeded
--- @return table? changes What changed during restore
function CompositeBridge:restore(snapshot)
  if not snapshot then
    return false, nil
  end

  local total_changes = {
    app_changes = nil,
    external_changes = nil,
  }

  -- Restore external state first (e.g., region names/colors)
  if snapshot.external_state and self.restore_external then
    local ok, changes = pcall(self.restore_external, snapshot.external_state)
    if ok then
      total_changes.external_changes = changes
    end
  end

  -- Then restore app state
  if snapshot.app_state and self.restore_app_state then
    local ok, changes = pcall(self.restore_app_state, snapshot.app_state)
    if ok then
      total_changes.app_changes = changes
    end
  end

  return true, total_changes
end

--- Push a new snapshot to the undo stack
function CompositeBridge:push()
  local snapshot = self:capture()
  self.undo_manager:push(snapshot)
end

--- Undo to previous state
--- @return boolean success Whether undo succeeded
--- @return table? changes What changed during undo
function CompositeBridge:undo()
  if not self.undo_manager:can_undo() then
    return false, nil
  end

  local snapshot = self.undo_manager:undo()
  return self:restore(snapshot)
end

--- Redo to next state
--- @return boolean success Whether redo succeeded
--- @return table? changes What changed during redo
function CompositeBridge:redo()
  if not self.undo_manager:can_redo() then
    return false, nil
  end

  local snapshot = self.undo_manager:redo()
  return self:restore(snapshot)
end

--- Check if undo is available
--- @return boolean can_undo True if can undo
function CompositeBridge:can_undo()
  return self.undo_manager:can_undo()
end

--- Check if redo is available
--- @return boolean can_redo True if can redo
function CompositeBridge:can_redo()
  return self.undo_manager:can_redo()
end

--- Clear all undo history
function CompositeBridge:clear()
  self.undo_manager:clear()
end

--- Get current snapshot without modifying history
--- @return table? snapshot The current snapshot or nil
function CompositeBridge:get_current()
  return self.undo_manager:get_current()
end

--- Get undo history size
--- @return number count Number of snapshots in history
function CompositeBridge:get_history_size()
  return #self.undo_manager.history
end

--- Get current position in history
--- @return number index Current index in history (0 if no history)
function CompositeBridge:get_current_index()
  return self.undo_manager.current_index
end

return M
