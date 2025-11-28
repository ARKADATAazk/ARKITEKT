-- @noindex
-- RegionPlaylist/app/state.lua
-- Single-source-of-truth app state (playlist expansion handled lazily)
--[[
The app layer is now the authoritative owner of playlist structure. Engine-side
modules request a flattened playback sequence through the coordinator bridge
whenever they advance, so the UI just needs to mark the cache dirty after any
mutation. This keeps App ↔ Engine state synchronized without a manual
sync_playlist_to_engine() step and guarantees nested playlists expand exactly
once per invalidation.
]]

local CoordinatorBridge = require("RegionPlaylist.data.bridge")
local RegionState = require("RegionPlaylist.data.storage")
local UndoManager = require("arkitekt.core.undo_manager")
local UndoBridge = require("RegionPlaylist.data.undo")
local Constants = require("RegionPlaylist.defs.constants")
local ProjectMonitor = require("arkitekt.reaper.project_monitor")
local Animation = require("RegionPlaylist.ui.state.animation")
local Notification = require("RegionPlaylist.ui.state.notification")
local UIPreferences = require("RegionPlaylist.ui.state.preferences")
local Region = require("RegionPlaylist.domain.region")
local Dependency = require("RegionPlaylist.domain.dependency")
local Playlist = require("RegionPlaylist.domain.playlist")
local PoolQueries = require("RegionPlaylist.app.pool_queries")
local Logger = require('arkitekt.debug.logger')

local M = {}

-- Set to true for verbose app state logging
local DEBUG_APP_STATE = false

package.loaded["RegionPlaylist.app.state"] = M

-- Build a human-readable status message from undo/redo changes
local function _build_changes_message(prefix, changes)
  local parts = {}

  if changes.playlists_count > 0 then
    parts[#parts + 1] = string.format("%d playlist%s",
      changes.playlists_count,
      changes.playlists_count ~= 1 and "s" or "")
  end

  if changes.items_count > 0 then
    parts[#parts + 1] = string.format("%d item%s",
      changes.items_count,
      changes.items_count ~= 1 and "s" or "")
  end

  if changes.regions_renamed > 0 then
    parts[#parts + 1] = string.format("%d region%s renamed",
      changes.regions_renamed,
      changes.regions_renamed ~= 1 and "s" or "")
  end

  if changes.regions_recolored > 0 then
    parts[#parts + 1] = string.format("%d region%s recolored",
      changes.regions_recolored,
      changes.regions_recolored ~= 1 and "s" or "")
  end

  if #parts > 0 then
    return prefix .. ": " .. table.concat(parts, ", ")
  end
  return prefix
end

-- Re-export mode constants for backward compatibility
M.POOL_MODES = Constants.POOL_MODES
M.LAYOUT_MODES = Constants.LAYOUT_MODES
M.SORT_DIRECTIONS = Constants.SORT_DIRECTIONS

-- =============================================================================
-- STATE FIELDS
-- =============================================================================

-- Domain instances
M.animation = nil                             -- Animation domain instance
M.notification = nil                          -- Notification domain instance
M.ui_preferences = nil                        -- UI preferences domain instance
M.region = nil                                -- Region domain instance
M.dependency = nil                            -- Dependency domain instance
M.playlist = nil                              -- Playlist domain instance

-- Engine/playback coordination
M.bridge = nil                                -- CoordinatorBridge instance for engine communication

-- Project state tracking (for detecting project switches/reloads)
M.last_project_state = -1                     -- Last seen project state count (for change detection)
M.last_project_filename = nil                 -- Last seen project filename
M.last_project_ptr = nil                      -- Last seen project pointer (detects tab switches)

-- Undo system
M.undo_manager = nil                          -- UndoManager instance

-- Project monitoring
M.project_monitor = nil                       -- ProjectMonitor instance

-- Event callbacks (set by GUI)
M.on_state_restored = nil                     -- Called when undo/redo restores state
M.on_repeat_cycle = nil                       -- Called when repeat count cycles

-- Settings
M.settings = nil                              -- Persistent UI settings

function M.initialize(settings)
  M.settings = settings

  -- Initialize domains
  M.animation = Animation.new()
  M.notification = Notification.new(Constants.TIMEOUTS)
  M.ui_preferences = UIPreferences.new(Constants, settings)
  M.region = Region.new()
  M.dependency = Dependency.new()
  M.playlist = Playlist.new()

  -- Load UI preferences from settings
  M.ui_preferences:load_from_settings()

  if DEBUG_APP_STATE then
    Logger.info("STATE", "Initialized with all 6 domains: animation, notification, ui_preferences, region, dependency, playlist")
  end

  -- Initialize project monitor to track changes
  M.project_monitor = ProjectMonitor.new({
    on_project_switch = function(old_proj, new_proj)
      M.reload_project_data()
    end,
    on_project_reload = function()
      M.reload_project_data()
    end,
    on_state_change = function(change_count)
      -- Handle state changes in update() for region tracking
    end,
    check_state_changes = true,
  })

  M.load_project_state()
  M.rebuild_dependency_graph()
  
  M.bridge = CoordinatorBridge.create({
    proj = 0,
    on_region_change = function(rid, region, pointer) end,
    on_playback_start = function(rid) end,
    on_playback_stop = function() end,
    on_transition_scheduled = function(rid, region_end, transition_time) end,
    on_repeat_cycle = function(key, current_loop, total_reps)
      if M.on_repeat_cycle then
        M.on_repeat_cycle(key, current_loop, total_reps)
      end
    end,
    get_playlist_by_id = M.get_playlist_by_id,
    get_active_playlist = M.get_active_playlist,
    get_active_playlist_id = M.get_active_playlist_id,
  })
  
  M.undo_manager = UndoManager.new({ max_history = 50 })
  
  M.refresh_regions()
  M.bridge:invalidate_sequence()
  M.bridge:get_sequence()
  M.capture_undo_snapshot()
end

function M.load_project_state()
  local playlists = RegionState.load_playlists(0)

  if #playlists == 0 then
    local UUID = require("arkitekt.core.uuid")
    playlists = {
      {
        id = UUID.generate(),
        name = "Playlist 1",
        items = {},
        chip_color = RegionState.generate_chip_color(),
      }
    }
    RegionState.save_playlists(playlists, 0)
  end

  M.playlist:load_playlists(playlists)

  local saved_active = RegionState.load_active_playlist(0)
  M.playlist:set_active(saved_active or playlists[1].id)
end

function M.reload_project_data()
  if M.bridge and M.bridge.engine and M.bridge.engine.is_playing then
    M.bridge:stop()
  end
  
  M.load_project_state()
  M.rebuild_dependency_graph()
  M.refresh_regions()
  M.bridge:invalidate_sequence()
  M.bridge:get_sequence()
  
  M.undo_manager = UndoManager.new({ max_history = 50 })
  
  M.clear_pending()
  
  if M.on_state_restored then
    M.on_state_restored()
  end
end

-- >>> CANONICAL ACCESSORS (BEGIN)
-- Single source of truth for state access - use these instead of direct field access

function M.get_active_playlist_id()
  return M.playlist:get_active_id()
end

function M.get_active_playlist()
  return M.playlist:get_active()
end

function M.get_playlist_by_id(playlist_id)
  return M.playlist:get_by_id(playlist_id)
end

function M.get_playlists()
  return M.playlist:get_all()
end

function M.get_bridge()
  return M.bridge
end

function M.get_region_by_rid(rid)
  return M.region:get_region_by_rid(rid)
end

function M.get_region_index()
  return M.region:get_region_index()
end

function M.get_pool_order()
  return M.region:get_pool_order()
end

function M.set_pool_order(new_order)
  M.region:set_pool_order(new_order)
end

function M.get_search_filter()
  return M.ui_preferences:get_search_filter()
end

function M.set_search_filter(text)
  M.ui_preferences:set_search_filter(text)
end

function M.get_sort_mode()
  return M.ui_preferences:get_sort_mode()
end

function M.set_sort_mode(mode)
  M.ui_preferences:set_sort_mode(mode)
end

function M.get_sort_direction()
  return M.ui_preferences:get_sort_direction()
end

function M.set_sort_direction(direction)
  M.ui_preferences:set_sort_direction(direction)
end

function M.get_layout_mode()
  return M.ui_preferences:get_layout_mode()
end

function M.set_layout_mode(mode)
  M.ui_preferences:set_layout_mode(mode)
end

function M.get_pool_mode()
  return M.ui_preferences:get_pool_mode()
end

function M.set_pool_mode(mode)
  M.ui_preferences:set_pool_mode(mode)
end

function M.get_pending_spawn()
  return M.animation:get_pending_spawn()
end

function M.get_pending_select()
  return M.animation:get_pending_select()
end

function M.get_pending_destroy()
  return M.animation:get_pending_destroy()
end

function M.get_separator_position_horizontal()
  return M.ui_preferences:get_separator_position_horizontal()
end

function M.set_separator_position_horizontal(pos)
  M.ui_preferences:set_separator_position_horizontal(pos)
end

function M.get_separator_position_vertical()
  return M.ui_preferences:get_separator_position_vertical()
end

function M.set_separator_position_vertical(pos)
  M.ui_preferences:set_separator_position_vertical(pos)
end

-- Pending operation helpers
function M.add_pending_spawn(key)
  M.animation:queue_spawn(key)
end

function M.add_pending_select(key)
  M.animation:queue_select(key)
end

function M.add_pending_destroy(key)
  M.animation:queue_destroy(key)
end

-- Status bar state accessors (delegated to notification domain)
function M.get_selection_info()
  return M.notification:get_selection_info()
end

function M.set_selection_info(info)
  M.notification:set_selection_info(info)
end

function M.get_circular_dependency_error()
  return M.notification:get_circular_dependency_error()
end

function M.set_circular_dependency_error(error_msg)
  M.notification:set_circular_dependency_error(error_msg)
end

function M.clear_circular_dependency_error()
  M.notification:clear_circular_dependency_error()
end

function M.get_state_change_notification()
  return M.notification:get_state_change_notification()
end

function M.set_state_change_notification(message)
  M.notification:set_state_change_notification(message)
end

function M.check_override_state_change(current_override_state)
  M.notification:check_override_state_change(current_override_state)
end

-- <<< CANONICAL ACCESSORS (END)

function M.get_tabs()
  return M.playlist:get_tabs()
end

function M.count_playlist_contents(playlist_id)
  return M.playlist:count_contents(playlist_id)
end

function M.refresh_regions()
  local regions = M.bridge:get_regions_for_ui()
  M.region:refresh_from_bridge(regions)
end

function M.persist()
  M.playlist:mark_changed()  -- Rebuild lookup table whenever playlists change
  RegionState.save_playlists(M.playlist:get_all(), 0)
  RegionState.save_active_playlist(M.playlist:get_active_id(), 0)
  M.mark_graph_dirty()
  if M.bridge then
    M.bridge:invalidate_sequence()
  end
end

function M.persist_ui_prefs()
  M.ui_preferences:save_to_settings()
end

function M.capture_undo_snapshot()
  local snapshot = UndoBridge.capture_snapshot(M.playlist:get_all(), M.playlist:get_active_id())
  M.undo_manager:push(snapshot)
end

function M.clear_pending()
  M.animation:clear_all()
end

function M.restore_snapshot(snapshot)
  if not snapshot then return false end

  if M.bridge and M.bridge.engine and M.bridge.engine.is_playing then
    M.bridge:stop()
  end

  local restored_playlists, restored_active, changes = UndoBridge.restore_snapshot(
    snapshot,
    M.get_region_index()
  )

  M.playlist:load_playlists(restored_playlists)
  M.playlist:set_active(restored_active)

  M.persist()
  M.clear_pending()

  -- Refresh region cache to show updated region colors/names in UI
  M.refresh_regions()

  if M.bridge then
    M.bridge:get_sequence()
  end

  if M.on_state_restored then
    M.on_state_restored()
  end

  return true, changes
end

function M.undo()
  if not M.undo_manager:can_undo() then
    return false
  end

  local snapshot = M.undo_manager:undo()
  local success, changes = M.restore_snapshot(snapshot)

  if success and changes then
    M.set_state_change_notification(_build_changes_message("Undo", changes))
  end

  return success
end

function M.redo()
  if not M.undo_manager:can_redo() then
    return false
  end

  local snapshot = M.undo_manager:redo()
  local success, changes = M.restore_snapshot(snapshot)

  if success and changes then
    M.set_state_change_notification(_build_changes_message("Redo", changes))
  end

  return success
end

function M.can_undo()
  return M.undo_manager:can_undo()
end

function M.can_redo()
  return M.undo_manager:can_redo()
end

function M.set_active_playlist(playlist_id, move_to_end)
  M.playlist:set_active(playlist_id)

  -- Optionally move the playlist to the front (first visible tab)
  if move_to_end then
    M.move_playlist_to_front(playlist_id)
  end

  M.persist()
  if M.bridge then
    M.bridge:get_sequence()
  end
end

function M.move_playlist_to_front(playlist_id)
  M.playlist:move_to_front(playlist_id)
  M.persist()
end

function M.reorder_playlists_by_ids(new_playlist_ids)
  M.playlist:reorder_by_ids(new_playlist_ids)
  M.persist()
end

-- =============================================================================
-- POOL QUERIES (delegated to pool_queries module)
-- =============================================================================

function M.get_filtered_pool_regions()
  return PoolQueries.get_filtered_pool_regions({
    pool_order = M.get_pool_order(),
    region_index = M.get_region_index(),
    search_filter = M.get_search_filter(),
    sort_mode = M.get_sort_mode(),
    sort_dir = M.get_sort_direction(),
  })
end

function M.mark_graph_dirty()
  M.dependency:mark_dirty()
end

function M.rebuild_dependency_graph()
  M.dependency:rebuild(M.playlist:get_all())
end

function M.is_playlist_draggable_to(playlist_id, target_playlist_id)
  M.dependency:ensure_fresh(M.playlist:get_all())
  return M.dependency:is_draggable_to(playlist_id, target_playlist_id)
end

function M.get_playlists_for_pool()
  M.dependency:ensure_fresh(M.playlist:get_all())

  return PoolQueries.get_playlists_for_pool({
    playlists = M.playlist:get_all(),
    active_id = M.playlist:get_active_id(),
    region_index = M.get_region_index(),
    search_filter = M.get_search_filter(),
    sort_mode = M.get_sort_mode(),
    sort_dir = M.get_sort_direction(),
    is_draggable_to = M.is_playlist_draggable_to,
    get_playlist_by_id = M.get_playlist_by_id,
  })
end

-- Mixed mode: combine regions and playlists with unified sorting
function M.get_mixed_pool_sorted()
  return PoolQueries.get_mixed_pool_sorted({
    regions = M.get_filtered_pool_regions(),
    playlists = M.get_playlists_for_pool(),
    sort_mode = M.get_sort_mode(),
    sort_dir = M.get_sort_direction(),
  })
end

function M.detect_circular_reference(target_playlist_id, playlist_id_to_add)
  M.dependency:ensure_fresh(M.playlist:get_all())
  return M.dependency:detect_circular_reference(target_playlist_id, playlist_id_to_add)
end

function M.create_playlist_item(playlist_id, reps)
  local playlist = M.get_playlist_by_id(playlist_id)
  if not playlist then
    return nil
  end
  
  return {
    type = "playlist",
    playlist_id = playlist_id,
    reps = reps or 1,
    enabled = true,
    key = "playlist_" .. playlist_id .. "_" .. reaper.time_precise(),
  }
end

-- Debug: Set to true to log cleanup resolution
local DEBUG_CLEANUP = false

function M.cleanup_deleted_regions()
  local removed_any = false
  local updated_any = false
  local playlists = M.playlist:get_all()

  if DEBUG_CLEANUP then
    reaper.ShowConsoleMsg("=== cleanup_deleted_regions() ===\n")
  end

  for _, pl in ipairs(playlists) do
    local i = 1
    while i <= #pl.items do
      local item = pl.items[i]
      if item.type == "region" then
        -- Try to resolve region: GUID → Name → RID
        local region = M.region:resolve_region(item.guid, item.rid, item.region_name)

        if DEBUG_CLEANUP then
          reaper.ShowConsoleMsg(string.format("  Item: rid=%s guid=%s name='%s' -> resolved=%s\n",
            tostring(item.rid), tostring(item.guid), tostring(item.region_name or ""),
            region and tostring(region.rid) or "NIL"))
        end

        if region then
          -- Region found - update RID if changed (was renumbered)
          if item.rid ~= region.rid then
            if DEBUG_CLEANUP then
              reaper.ShowConsoleMsg(string.format("    UPDATING rid: %d -> %d\n", item.rid, region.rid))
            end
            item.rid = region.rid
            updated_any = true
          end
          -- Update GUID if changed or missing (renumbering generates new GUIDs)
          if region.guid and item.guid ~= region.guid then
            if DEBUG_CLEANUP then
              reaper.ShowConsoleMsg(string.format("    UPDATING guid: %s -> %s\n",
                tostring(item.guid), region.guid))
            end
            item.guid = region.guid
            updated_any = true
          end
          -- Update stored name if it changed
          if region.name and region.name ~= "" and item.region_name ~= region.name then
            if DEBUG_CLEANUP then
              reaper.ShowConsoleMsg(string.format("    UPDATING name: '%s' -> '%s'\n",
                tostring(item.region_name or ""), region.name))
            end
            item.region_name = region.name
            updated_any = true
          end
          i = i + 1
        else
          -- Region truly deleted - remove from playlist
          if DEBUG_CLEANUP then
            reaper.ShowConsoleMsg(string.format("    REMOVING (not found)\n"))
          end
          table.remove(pl.items, i)
          removed_any = true
          M.add_pending_destroy(item.key)
        end
      else
        i = i + 1
      end
    end
  end

  if removed_any or updated_any then
    M.persist()
  end

  return removed_any
end

function M.update()
  -- Use project monitor to detect changes
  local project_changed = M.project_monitor:update()

  -- If project switched/reloaded, monitor already called our callback
  -- Just return early
  if project_changed and (
      M.project_monitor:get_last_filename() ~= M.last_project_filename or
      M.project_monitor:get_last_ptr() ~= M.last_project_ptr) then
    M.last_project_filename = M.project_monitor:get_last_filename()
    M.last_project_ptr = M.project_monitor:get_last_ptr()
    return
  end

  -- Handle region-specific state changes
  local current_project_state = M.project_monitor:get_last_state_count()
  if current_project_state ~= M.last_project_state then
    local old_region_count = M.region:count()

    M.refresh_regions()

    local new_region_count = M.region:count()
    
    local regions_deleted = new_region_count < old_region_count
    
    if regions_deleted then
      M.cleanup_deleted_regions()
    end
    
    if M.bridge then
      M.bridge:get_sequence()
    end
    M.last_project_state = current_project_state
  end
end

return M
