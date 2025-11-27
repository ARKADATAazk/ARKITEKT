-- @noindex
-- RegionPlaylist/app/events.lua
-- Central event bus factory and event name constants
--
-- This module provides a typed event system for decoupled pub/sub communication
-- between RegionPlaylist components (GUI, engine, state, etc.)
--
-- Usage:
--   local AppEvents = require("RegionPlaylist.app.events")
--   local bus = AppEvents.create_bus(debug_mode)
--   bus:on(AppEvents.EVENTS.PLAYBACK_STARTED, function(data) ... end)

local Events = require("arkitekt.core.events")

local M = {}

-- =============================================================================
-- EVENT NAMES (type-safe constants)
-- =============================================================================

M.EVENTS = {
  -- Playlist events
  PLAYLIST_CREATED = "playlist.created",
  PLAYLIST_DELETED = "playlist.deleted",
  PLAYLIST_RENAMED = "playlist.renamed",
  PLAYLIST_REORDERED = "playlist.reordered",
  PLAYLIST_ACTIVE_CHANGED = "playlist.active_changed",

  -- Item events
  ITEM_ADDED = "item.added",
  ITEM_REMOVED = "item.removed",
  ITEM_REORDERED = "item.reordered",
  ITEM_ENABLED_CHANGED = "item.enabled_changed",
  ITEM_REPEATS_CHANGED = "item.repeats_changed",

  -- Playback events
  PLAYBACK_STARTED = "playback.started",
  PLAYBACK_STOPPED = "playback.stopped",
  PLAYBACK_PAUSED = "playback.paused",
  PLAYBACK_RESUMED = "playback.resumed",
  PLAYBACK_REGION_CHANGED = "playback.region_changed",
  PLAYBACK_TRANSITION = "playback.transition",
  PLAYBACK_REPEAT_CYCLE = "playback.repeat_cycle",

  -- UI events
  UI_SELECTION_CHANGED = "ui.selection_changed",
  UI_SEARCH_CHANGED = "ui.search_changed",
  UI_SORT_CHANGED = "ui.sort_changed",
  UI_LAYOUT_CHANGED = "ui.layout_changed",
  UI_POOL_MODE_CHANGED = "ui.pool_mode_changed",

  -- State events
  STATE_RESTORED = "state.restored",
  STATE_SAVED = "state.saved",
  STATE_SNAPSHOT_CAPTURED = "state.snapshot_captured",

  -- Animation events
  ANIMATION_SPAWN = "animation.spawn",
  ANIMATION_DESTROY = "animation.destroy",

  -- Region events
  REGION_RENAMED = "region.renamed",
  REGION_RECOLORED = "region.recolored",
  REGION_DELETED = "region.deleted",
}

-- =============================================================================
-- BUS FACTORY
-- =============================================================================

--- Create the application event bus
--- @param debug boolean Enable debug logging
--- @return table bus Event bus instance
function M.create_bus(debug)
  return Events.new({
    debug = debug or false,
    max_history = 100,
  })
end

-- =============================================================================
-- EVENT PAYLOAD DOCUMENTATION
-- =============================================================================
--[[
Event Payloads Reference:

PLAYLIST_CREATED:      { id, name }
PLAYLIST_DELETED:      { id }
PLAYLIST_RENAMED:      { id, old_name, new_name }
PLAYLIST_REORDERED:    { playlist_ids }
PLAYLIST_ACTIVE_CHANGED: { id, previous_id }

ITEM_ADDED:            { playlist_id, key, rid, index }
ITEM_REMOVED:          { playlist_id, keys }
ITEM_REORDERED:        { playlist_id, new_order }
ITEM_ENABLED_CHANGED:  { playlist_id, key, enabled }
ITEM_REPEATS_CHANGED:  { playlist_id, key, reps }

PLAYBACK_STARTED:      { rid, pointer }
PLAYBACK_STOPPED:      {}
PLAYBACK_PAUSED:       { position }
PLAYBACK_RESUMED:      { position }
PLAYBACK_REGION_CHANGED: { rid, region, pointer }
PLAYBACK_TRANSITION:   { from_idx, to_idx }
PLAYBACK_REPEAT_CYCLE: { key, current_loop, total_loops }

UI_SELECTION_CHANGED:  { keys, source }
UI_SEARCH_CHANGED:     { text }
UI_SORT_CHANGED:       { mode, direction }
UI_LAYOUT_CHANGED:     { mode }
UI_POOL_MODE_CHANGED:  { mode }

STATE_RESTORED:        { action, changes }
STATE_SAVED:           {}
STATE_SNAPSHOT_CAPTURED: {}

ANIMATION_SPAWN:       { key }
ANIMATION_DESTROY:     { key }

REGION_RENAMED:        { rid, old_name, new_name }
REGION_RECOLORED:      { rid, old_color, new_color }
REGION_DELETED:        { rid }
]]

return M
