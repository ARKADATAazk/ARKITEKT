-- @noindex
-- RegionPlaylist/core/app_state.lua
-- Single-source-of-truth app state (playlist expansion handled lazily)
--[[
The app layer is now the authoritative owner of playlist structure. Engine-side
modules request a flattened playback sequence through the coordinator bridge
whenever they advance, so the UI just needs to mark the cache dirty after any
mutation. This keeps App ↔ Engine state synchronized without a manual
sync_playlist_to_engine() step and guarantees nested playlists expand exactly
once per invalidation.
]]

local CoordinatorBridge = require("RegionPlaylist.engine.coordinator_bridge")
local ark = require('arkitekt')
local RegionState = require("RegionPlaylist.storage.persistence")
local UndoManager = require("arkitekt.core.undo_manager")
local UndoBridge = require("RegionPlaylist.storage.undo_bridge")
local Constants = require("RegionPlaylist.defs.constants")
local ProjectMonitor = require("arkitekt.reaper.project_monitor")
local Animation = require("RegionPlaylist.domains.animation")
local Notification = require("RegionPlaylist.domains.notification")
local UIPreferences = require("RegionPlaylist.domains.ui_preferences")
local Region = require("RegionPlaylist.domains.region")
local Dependency = require("RegionPlaylist.domains.dependency")
local Playlist = require("RegionPlaylist.domains.playlist")
local Logger = require('arkitekt.debug.logger')

local M = {}

-- Set to true for verbose app state logging
local DEBUG_APP_STATE = false

package.loaded["RegionPlaylist.core.app_state"] = M

-- Generate a deterministic color from a string (e.g., playlist ID)
-- This ensures the same ID always produces the same color
local function deterministic_color_from_id(id)
  local str = tostring(id)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + str:byte(i)) % 2147483647
  end
  local hue = (hash % 360) / 360
  local saturation = 0.65 + ((hash % 100) / 400)  -- 0.65-0.90
  local lightness = 0.50 + ((hash % 60) / 400)    -- 0.50-0.65
  local r, g, b = ark.Colors.hsl_to_rgb(hue, saturation, lightness)
  return ark.Colors.components_to_rgba(r, g, b, 0xFF)
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
    -- Build status message from changes
    local parts = {}
    if changes.playlists_count > 0 then
      parts[#parts + 1] = string.format("%d playlist%s", changes.playlists_count, changes.playlists_count ~= 1 and "s" or "")
    end
    if changes.items_count > 0 then
      parts[#parts + 1] = string.format("%d item%s", changes.items_count, changes.items_count ~= 1 and "s" or "")
    end
    if changes.regions_renamed > 0 then
      parts[#parts + 1] = string.format("%d region%s renamed", changes.regions_renamed, changes.regions_renamed ~= 1 and "s" or "")
    end
    if changes.regions_recolored > 0 then
      parts[#parts + 1] = string.format("%d region%s recolored", changes.regions_recolored, changes.regions_recolored ~= 1 and "s" or "")
    end

    if #parts > 0 then
      M.set_state_change_notification("Undo: " .. table.concat(parts, ", "))
    else
      M.set_state_change_notification("Undo")
    end
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
    -- Build status message from changes
    local parts = {}
    if changes.playlists_count > 0 then
      parts[#parts + 1] = string.format("%d playlist%s", changes.playlists_count, changes.playlists_count ~= 1 and "s" or "")
    end
    if changes.items_count > 0 then
      parts[#parts + 1] = string.format("%d item%s", changes.items_count, changes.items_count ~= 1 and "s" or "")
    end
    if changes.regions_renamed > 0 then
      parts[#parts + 1] = string.format("%d region%s renamed", changes.regions_renamed, changes.regions_renamed ~= 1 and "s" or "")
    end
    if changes.regions_recolored > 0 then
      parts[#parts + 1] = string.format("%d region%s recolored", changes.regions_recolored, changes.regions_recolored ~= 1 and "s" or "")
    end

    if #parts > 0 then
      M.set_state_change_notification("Redo: " .. table.concat(parts, ", "))
    else
      M.set_state_change_notification("Redo")
    end
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

local function compare_by_color(a, b)
  local color_a = a.color or 0
  local color_b = b.color or 0
  return ark.Colors.compare_colors(color_a, color_b)
end

local function compare_by_index(a, b)
  return a.rid < b.rid
end

local function compare_by_alpha(a, b)
  local name_a = (a.name or ""):lower()
  local name_b = (b.name or ""):lower()
  return name_a < name_b
end

local function compare_by_length(a, b)
  local len_a = (a["end"] or 0) - (a.start or 0)
  local len_b = (b["end"] or 0) - (b.start or 0)
  return len_a < len_b
end

function M.get_filtered_pool_regions()
  local result = {}
  local search = M.get_search_filter():lower()

  local region_index = M.get_region_index()
  for _, rid in ipairs(M.get_pool_order()) do
    local region = region_index[rid]
    if region and region.name ~= "__TRANSITION_TRIGGER" and (search == "" or region.name:lower():find(search, 1, true)) then
      result[#result + 1] = region
    end
  end

  local sort_mode = M.get_sort_mode()
  local sort_dir = M.get_sort_direction() or "asc"
  
  -- ONLY sort if there's an active sort mode
  if sort_mode == "color" then
    table.sort(result, compare_by_color)
  elseif sort_mode == "index" then
    table.sort(result, compare_by_index)
  elseif sort_mode == "alpha" then
    table.sort(result, compare_by_alpha)
  elseif sort_mode == "length" then
    table.sort(result, compare_by_length)
  end
  
  -- CRITICAL FIX: Only reverse if we have an active sort mode AND direction is desc
  if sort_mode and sort_mode ~= "" and sort_dir == "desc" then
    local reversed = {}
    for i = #result, 1, -1 do
      reversed[#reversed + 1] = result[i]
    end
    result = reversed
  end
  
  return result
end


-- Helper: Calculate total duration of all regions in a playlist
local function calculate_playlist_duration(playlist, region_index)
  if not playlist or not playlist.items then return 0 end
  
  local total_duration = 0
  
  for _, item in ipairs(playlist.items) do
    -- Skip disabled items
    if item.enabled == false then
      goto continue
    end
    
    local item_type = item.type or "region"
    local rid = item.rid
    
    if item_type == "region" and rid then
      local region = region_index[rid]
      if region then
        -- region.start and region["end"] are time positions in seconds
        local duration_seconds = (region["end"] or 0) - (region.start or 0)
        local repeats = item.reps or 1
        total_duration = total_duration + (duration_seconds * repeats)
      end
    elseif item_type == "playlist" and item.playlist_id then
      -- For nested playlists, recursively calculate duration
      local nested_pl = M.get_playlist_by_id(item.playlist_id)
      if nested_pl then
        local nested_duration = calculate_playlist_duration(nested_pl, region_index)
        local repeats = item.reps or 1
        total_duration = total_duration + (nested_duration * repeats)
      end
    end
    
    ::continue::
  end
  
  return total_duration
end

-- Playlist comparison functions
local function compare_playlists_by_alpha(a, b)
  local name_a = (a.name or ""):lower()
  local name_b = (b.name or ""):lower()
  return name_a < name_b
end

local function compare_playlists_by_item_count(a, b)
  local count_a = #a.items
  local count_b = #b.items
  return count_a < count_b
end

local function compare_playlists_by_color(a, b)
  local color_a = a.chip_color or 0
  local color_b = b.chip_color or 0
  return ark.Colors.compare_colors(color_a, color_b)
end

local function compare_playlists_by_index(a, b)
  return (a.index or 0) < (b.index or 0)
end

local function compare_playlists_by_duration(a, b)
  return (a.total_duration or 0) < (b.total_duration or 0)
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

  local pool_playlists = {}
  local active_id = M.playlist:get_active_id()
  local playlists = M.playlist:get_all()

  -- Build playlist index map for implicit ordering
  local playlist_index_map = {}
  for i, pl in ipairs(playlists) do
    playlist_index_map[pl.id] = i
  end

  for _, pl in ipairs(playlists) do
    if pl.id ~= active_id then
      local is_draggable = M.is_playlist_draggable_to(pl.id, active_id)
      local total_duration = calculate_playlist_duration(pl, M.get_region_index())
      
      pool_playlists[#pool_playlists + 1] = {
        type = "playlist",  -- Mark as playlist for mixed mode
        id = pl.id,
        name = pl.name,
        items = pl.items,
        chip_color = pl.chip_color or deterministic_color_from_id(pl.id),
        is_disabled = not is_draggable,
        index = playlist_index_map[pl.id] or 0,
        total_duration = total_duration,
      }
    end
  end
  
  local search = M.get_search_filter():lower()
  if search ~= "" then
    local filtered = {}
    for _, pl in ipairs(pool_playlists) do
      if pl.name:lower():find(search, 1, true) then
        filtered[#filtered + 1] = pl
      end
    end
    pool_playlists = filtered
  end

  local sort_mode = M.get_sort_mode()
  local sort_dir = M.get_sort_direction() or "asc"
  
  -- Apply sorting (only if sort_mode is active)
  if sort_mode == "color" then
    table.sort(pool_playlists, compare_playlists_by_color)
  elseif sort_mode == "index" then
    table.sort(pool_playlists, compare_playlists_by_index)
  elseif sort_mode == "alpha" then
    table.sort(pool_playlists, compare_playlists_by_alpha)
  elseif sort_mode == "length" then
    -- Length now sorts by total duration instead of item count
    table.sort(pool_playlists, compare_playlists_by_duration)
  end
  
  -- Reverse if descending (only when sort_mode is active)
  if sort_mode and sort_dir == "desc" then
    local reversed = {}
    for i = #pool_playlists, 1, -1 do
      reversed[#reversed + 1] = pool_playlists[i]
    end
    pool_playlists = reversed
  end
  
  return pool_playlists
end

-- Mixed mode: combine regions and playlists with unified sorting
function M.get_mixed_pool_sorted()
  local regions = M.get_filtered_pool_regions()
  local playlists = M.get_playlists_for_pool()

  local sort_mode = M.get_sort_mode()
  local sort_dir = M.get_sort_direction() or "asc"
  
  -- If no sort mode, return regions first, then playlists (natural order)
  if not sort_mode then
    local result = {}
    for _, region in ipairs(regions) do
      result[#result + 1] = region
    end
    for _, playlist in ipairs(playlists) do
      result[#result + 1] = playlist
    end
    return result
  end
  
  -- Otherwise, combine and sort together
  local combined = {}
  
  -- Add regions (already have type field or can be identified by lack of type)
  for _, region in ipairs(regions) do
    if not region.type then
      region.type = "region"
    end
    combined[#combined + 1] = region
  end
  
  -- Add playlists (already marked with type="playlist")
  for _, playlist in ipairs(playlists) do
    combined[#combined + 1] = playlist
  end
  
  -- Unified comparison function that works for both regions and playlists
  local function unified_compare(a, b)
    if sort_mode == "color" then
      local color_a = a.chip_color or a.color or 0
      local color_b = b.chip_color or b.color or 0
      return ark.Colors.compare_colors(color_a, color_b)
    elseif sort_mode == "index" then
      local idx_a = a.index or a.rid or 0
      local idx_b = b.index or b.rid or 0
      return idx_a < idx_b
    elseif sort_mode == "alpha" then
      local name_a = (a.name or ""):lower()
      local name_b = (b.name or ""):lower()
      return name_a < name_b
    elseif sort_mode == "length" then
      -- For regions: use end - start
      -- For playlists: use total_duration
      local len_a
      if a.type == "playlist" then
        len_a = a.total_duration or 0
      else
        len_a = (a["end"] or 0) - (a.start or 0)
      end
      
      local len_b
      if b.type == "playlist" then
        len_b = b.total_duration or 0
      else
        len_b = (b["end"] or 0) - (b.start or 0)
      end
      
      return len_a < len_b
    end
    
    return false
  end
  
  table.sort(combined, unified_compare)
  
  -- Reverse if descending
  if sort_dir == "desc" then
    local reversed = {}
    for i = #combined, 1, -1 do
      reversed[#reversed + 1] = combined[i]
    end
    return reversed
  end
  
  return combined
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

function M.cleanup_deleted_regions()
  local removed_any = false
  local region_index = M.get_region_index()
  local playlists = M.playlist:get_all()

  for _, pl in ipairs(playlists) do
    local i = 1
    while i <= #pl.items do
      local item = pl.items[i]
      if item.type == "region" and not region_index[item.rid] then
        table.remove(pl.items, i)
        removed_any = true
        M.add_pending_destroy(item.key)
      else
        i = i + 1
      end
    end
  end
  
  if removed_any then
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
