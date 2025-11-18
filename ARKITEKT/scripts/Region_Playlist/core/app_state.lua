-- @noindex
-- Region_Playlist/core/app_state.lua
-- Single-source-of-truth app state (playlist expansion handled lazily)
--[[
The app layer is now the authoritative owner of playlist structure. Engine-side
modules request a flattened playback sequence through the coordinator bridge
whenever they advance, so the UI just needs to mark the cache dirty after any
mutation. This keeps App ↔ Engine state synchronized without a manual
sync_playlist_to_engine() step and guarantees nested playlists expand exactly
once per invalidation.
]]

local CoordinatorBridge = require("Region_Playlist.engine.coordinator_bridge")
local RegionState = require("Region_Playlist.storage.persistence")
local UndoManager = require("rearkitekt.core.undo_manager")
local UndoBridge = require("Region_Playlist.storage.undo_bridge")
local Colors = require("rearkitekt.core.colors")

local M = {}

package.loaded["Region_Playlist.core.app_state"] = M

-- >>> MODE CONSTANTS (BEGIN)
-- Valid mode values for state validation
M.POOL_MODES = {
  REGIONS = "regions",
  PLAYLISTS = "playlists",
  MIXED = "mixed"
}

M.LAYOUT_MODES = {
  HORIZONTAL = "horizontal",
  VERTICAL = "vertical"
}

M.SORT_DIRECTIONS = {
  ASC = "asc",
  DESC = "desc"
}
-- <<< MODE CONSTANTS (END)

-- Flattened state structure (no nested .state table)
M.active_playlist = nil
M.search_filter = ""
M.sort_mode = nil
M.sort_direction = M.SORT_DIRECTIONS.ASC
M.layout_mode = M.LAYOUT_MODES.HORIZONTAL
M.pool_mode = M.POOL_MODES.REGIONS
M.region_index = {}
M.pool_order = {}
M.pending_spawn = {}
M.pending_select = {}
M.pending_destroy = {}
M.bridge = nil
M.last_project_state = -1
M.last_project_filename = nil
M.last_project_ptr = nil  -- Track actual project pointer to detect tab switches
M.undo_manager = nil
M.on_state_restored = nil
M.on_repeat_cycle = nil

M.playlists = {}
M.playlist_lookup = {}  -- UUID -> playlist object (O(1) lookup)
M.settings = nil
M.dependency_graph = {}
M.graph_dirty = true

-- Status bar state
M.selection_info = { region_count = 0, playlist_count = 0 }
M.circular_dependency_error = nil
M.circular_dependency_error_timestamp = nil
M.circular_dependency_error_timeout = 6.0  -- seconds (doubled)

-- Temporary state change notifications
M.state_change_notification = nil
M.state_change_notification_timestamp = nil
M.state_change_notification_timeout = 4.0  -- seconds (doubled)

M.last_override_state = false

local function get_current_project_filename()
  local proj_path = reaper.GetProjectPath("")
  local proj_name = reaper.GetProjectName(0, "")
  if proj_path == "" or proj_name == "" then
    return nil
  end
  return proj_path .. "/" .. proj_name
end

local function get_current_project_ptr()
  -- Get the current project pointer to detect tab switches
  -- EnumProjects(-1, "") returns the current project
  local proj, _ = reaper.EnumProjects(-1, "")
  return proj
end

local function rebuild_playlist_lookup()
  M.playlist_lookup = {}
  for _, pl in ipairs(M.playlists) do
    M.playlist_lookup[pl.id] = pl
  end
end

function M.initialize(settings)
  M.settings = settings
  
  if settings then
    M.search_filter = settings:get('pool_search') or ""
    M.sort_mode = settings:get('pool_sort')
    M.sort_direction = settings:get('pool_sort_direction') or "asc"
    M.layout_mode = settings:get('layout_mode') or 'horizontal'
    M.pool_mode = settings:get('pool_mode') or 'regions'
  end
  
  M.last_project_filename = get_current_project_filename()
  M.last_project_ptr = get_current_project_ptr()

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
    get_active_playlist_id = function()
      return M.active_playlist
    end,
  })
  
  M.undo_manager = UndoManager.new({ max_history = 50 })
  
  M.refresh_regions()
  M.bridge:invalidate_sequence()
  M.bridge:get_sequence()
  M.capture_undo_snapshot()
end

function M.load_project_state()
  M.playlists = RegionState.load_playlists(0)

  if #M.playlists == 0 then
    local UUID = require("rearkitekt.core.uuid")
    M.playlists = {
      {
        id = UUID.generate(),
        name = "Playlist 1",
        items = {},
        chip_color = RegionState.generate_chip_color(),
      }
    }
    RegionState.save_playlists(M.playlists, 0)
  end

  rebuild_playlist_lookup()

  local saved_active = RegionState.load_active_playlist(0)
  M.active_playlist = saved_active or M.playlists[1].id
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
  return M.active_playlist
end

function M.get_active_playlist()
  local pl = M.playlist_lookup[M.active_playlist]
  if pl then
    return pl
  end
  return M.playlists[1]
end

function M.get_playlist_by_id(playlist_id)
  return M.playlist_lookup[playlist_id]
end

function M.get_playlists()
  return M.playlists
end

function M.get_bridge()
  return M.bridge
end

function M.get_region_by_rid(rid)
  return M.region_index[rid]
end

function M.get_region_index()
  return M.region_index
end

function M.get_pool_order()
  return M.pool_order
end

function M.set_pool_order(new_order)
  M.pool_order = new_order
end

function M.get_search_filter()
  return M.search_filter
end

function M.set_search_filter(text)
  M.search_filter = text
end

function M.get_sort_mode()
  return M.sort_mode
end

function M.set_sort_mode(mode)
  M.sort_mode = mode
end

function M.get_sort_direction()
  return M.sort_direction
end

function M.set_sort_direction(direction)
  -- Validate sort direction
  if direction ~= M.SORT_DIRECTIONS.ASC and 
     direction ~= M.SORT_DIRECTIONS.DESC then
    error(string.format("Invalid sort_direction: %s (expected 'asc' or 'desc')", tostring(direction)))
  end
  M.sort_direction = direction
end

function M.get_layout_mode()
  return M.layout_mode
end

function M.set_layout_mode(mode)
  -- Validate layout mode
  if mode ~= M.LAYOUT_MODES.HORIZONTAL and 
     mode ~= M.LAYOUT_MODES.VERTICAL then
    error(string.format("Invalid layout_mode: %s (expected 'horizontal' or 'vertical')", tostring(mode)))
  end
  M.layout_mode = mode
end

function M.get_pool_mode()
  return M.pool_mode
end

function M.set_pool_mode(mode)
  -- Validate pool mode
  if mode ~= M.POOL_MODES.REGIONS and 
     mode ~= M.POOL_MODES.PLAYLISTS and 
     mode ~= M.POOL_MODES.MIXED then
    error(string.format("Invalid pool_mode: %s (expected 'regions', 'playlists', or 'mixed')", tostring(mode)))
  end
  M.pool_mode = mode
end

function M.get_pending_spawn()
  return M.pending_spawn
end

function M.get_pending_select()
  return M.pending_select
end

function M.get_pending_destroy()
  return M.pending_destroy
end

function M.get_separator_position_horizontal()
  return M.separator_position_horizontal
end

function M.set_separator_position_horizontal(pos)
  M.separator_position_horizontal = pos
end

function M.get_separator_position_vertical()
  return M.separator_position_vertical
end

function M.set_separator_position_vertical(pos)
  M.separator_position_vertical = pos
end

-- Pending operation helpers
function M.add_pending_spawn(key)
  M.pending_spawn[#M.pending_spawn + 1] = key
end

function M.add_pending_select(key)
  M.pending_select[#M.pending_select + 1] = key
end

function M.add_pending_destroy(key)
  M.pending_destroy[#M.pending_destroy + 1] = key
end

-- Status bar state accessors
function M.get_selection_info()
  return M.selection_info
end

function M.set_selection_info(info)
  M.selection_info = info or { region_count = 0, playlist_count = 0 }
end

function M.get_circular_dependency_error()
  -- Auto-clear error after timeout
  if M.circular_dependency_error and M.circular_dependency_error_timestamp then
    local current_time = reaper.time_precise()
    if (current_time - M.circular_dependency_error_timestamp) >= M.circular_dependency_error_timeout then
      M.circular_dependency_error = nil
      M.circular_dependency_error_timestamp = nil
    end
  end
  return M.circular_dependency_error
end

function M.set_circular_dependency_error(error_msg)
  M.circular_dependency_error = error_msg
  M.circular_dependency_error_timestamp = reaper.time_precise()
end

function M.clear_circular_dependency_error()
  M.circular_dependency_error = nil
  M.circular_dependency_error_timestamp = nil
end

function M.get_state_change_notification()
  -- Auto-clear notification after timeout
  if M.state_change_notification and M.state_change_notification_timestamp then
    local current_time = reaper.time_precise()
    if (current_time - M.state_change_notification_timestamp) >= M.state_change_notification_timeout then
      M.state_change_notification = nil
      M.state_change_notification_timestamp = nil
    end
  end
  return M.state_change_notification
end

function M.set_state_change_notification(message)
  M.state_change_notification = message
  M.state_change_notification_timestamp = reaper.time_precise()
end

function M.check_override_state_change(current_override_state)
  if current_override_state ~= M.last_override_state then
    M.last_override_state = current_override_state
    if current_override_state then
      M.set_state_change_notification("Override: Transport will take over when hitting a region")
    else
      M.set_state_change_notification("Override disabled")
    end
  end
end

-- <<< CANONICAL ACCESSORS (END)

function M.get_tabs()
  local tabs = {}
  for _, pl in ipairs(M.playlists) do
    tabs[#tabs + 1] = {
      id = pl.id,
      label = pl.name or "Untitled",
      chip_color = pl.chip_color,
    }
  end
  return tabs
end

function M.count_playlist_contents(playlist_id)
  local playlist = M.get_playlist_by_id(playlist_id)
  if not playlist or not playlist.items then
    return 0, 0
  end
  
  local region_count = 0
  local playlist_count = 0
  
  for _, item in ipairs(playlist.items) do
    if item.type == "region" then
      region_count = region_count + 1
    elseif item.type == "playlist" then
      playlist_count = playlist_count + 1
    end
  end
  
  return region_count, playlist_count
end

function M.refresh_regions()
  local regions = M.bridge:get_regions_for_ui()
  
  M.region_index = {}
  M.pool_order = {}
  
  for _, region in ipairs(regions) do
    M.region_index[region.rid] = region
    M.pool_order[#M.pool_order + 1] = region.rid
  end
end

function M.persist()
  rebuild_playlist_lookup()  -- Rebuild lookup table whenever playlists change
  RegionState.save_playlists(M.playlists, 0)
  RegionState.save_active_playlist(M.active_playlist, 0)
  M.mark_graph_dirty()
  if M.bridge then
    M.bridge:invalidate_sequence()
  end
end

function M.persist_ui_prefs()
  if not M.settings then return end
  M.settings:set('pool_search', M.search_filter)
  M.settings:set('pool_sort', M.sort_mode)
  M.settings:set('pool_sort_direction', M.sort_direction)
  M.settings:set('layout_mode', M.layout_mode)
  M.settings:set('pool_mode', M.pool_mode)
end

function M.capture_undo_snapshot()
  local snapshot = UndoBridge.capture_snapshot(M.playlists, M.active_playlist)
  M.undo_manager:push(snapshot)
end

function M.clear_pending()
  M.pending_spawn = {}
  M.pending_select = {}
  M.pending_destroy = {}
end

function M.restore_snapshot(snapshot)
  if not snapshot then return false end

  if M.bridge and M.bridge.engine and M.bridge.engine.is_playing then
    M.bridge:stop()
  end

  local restored_playlists, restored_active, changes = UndoBridge.restore_snapshot(
    snapshot,
    M.region_index
  )

  M.playlists = restored_playlists
  M.active_playlist = restored_active

  rebuild_playlist_lookup()

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
      table.insert(parts, string.format("%d playlist%s", changes.playlists_count, changes.playlists_count ~= 1 and "s" or ""))
    end
    if changes.items_count > 0 then
      table.insert(parts, string.format("%d item%s", changes.items_count, changes.items_count ~= 1 and "s" or ""))
    end
    if changes.regions_renamed > 0 then
      table.insert(parts, string.format("%d region%s renamed", changes.regions_renamed, changes.regions_renamed ~= 1 and "s" or ""))
    end
    if changes.regions_recolored > 0 then
      table.insert(parts, string.format("%d region%s recolored", changes.regions_recolored, changes.regions_recolored ~= 1 and "s" or ""))
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
      table.insert(parts, string.format("%d playlist%s", changes.playlists_count, changes.playlists_count ~= 1 and "s" or ""))
    end
    if changes.items_count > 0 then
      table.insert(parts, string.format("%d item%s", changes.items_count, changes.items_count ~= 1 and "s" or ""))
    end
    if changes.regions_renamed > 0 then
      table.insert(parts, string.format("%d region%s renamed", changes.regions_renamed, changes.regions_renamed ~= 1 and "s" or ""))
    end
    if changes.regions_recolored > 0 then
      table.insert(parts, string.format("%d region%s recolored", changes.regions_recolored, changes.regions_recolored ~= 1 and "s" or ""))
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
  M.active_playlist = playlist_id
  
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
  -- Find the playlist's current position
  local playlist_index = nil
  for i, pl in ipairs(M.playlists) do
    if pl.id == playlist_id then
      playlist_index = i
      break
    end
  end
  
  if not playlist_index then return end
  
  -- Move to position 1 (front) so it's always visible
  -- Most recently selected playlist appears first
  if playlist_index ~= 1 then
    local playlist = table.remove(M.playlists, playlist_index)
    table.insert(M.playlists, 1, playlist)
    M.persist()
  end
end

function M.reorder_playlists_by_ids(new_playlist_ids)
  -- Build a map of playlists by ID
  local playlist_map = {}
  for _, pl in ipairs(M.playlists) do
    playlist_map[pl.id] = pl
  end
  
  -- Rebuild playlists array in new order
  local reordered = {}
  for _, id in ipairs(new_playlist_ids) do
    local pl = playlist_map[id]
    if pl then
      reordered[#reordered + 1] = pl
      playlist_map[id] = nil  -- Mark as used
    end
  end
  
  -- Append any playlists not in the reorder list (shouldn't happen, but defensive)
  for _, pl in pairs(playlist_map) do
    reordered[#reordered + 1] = pl
  end

  M.playlists = reordered
  rebuild_playlist_lookup()
  M.persist()
end

local function compare_by_color(a, b)
  local color_a = a.color or 0
  local color_b = b.color or 0
  return Colors.compare_colors(color_a, color_b)
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
  local search = M.search_filter:lower()
  
  for _, rid in ipairs(M.pool_order) do
    local region = M.region_index[rid]
    if region and region.name ~= "__TRANSITION_TRIGGER" and (search == "" or region.name:lower():find(search, 1, true)) then
      result[#result + 1] = region
    end
  end
  
  local sort_mode = M.sort_mode
  local sort_dir = M.sort_direction or "asc"
  
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
  return Colors.compare_colors(color_a, color_b)
end

local function compare_playlists_by_index(a, b)
  return (a.index or 0) < (b.index or 0)
end

local function compare_playlists_by_duration(a, b)
  return (a.total_duration or 0) < (b.total_duration or 0)
end

function M.mark_graph_dirty()
  M.graph_dirty = true
end

function M.rebuild_dependency_graph()
  M.dependency_graph = {}
  
  for _, pl in ipairs(M.playlists) do
    M.dependency_graph[pl.id] = {
      direct_deps = {},
      all_deps = {},
      is_disabled_for = {}
    }
    
    for _, item in ipairs(pl.items) do
      if item.type == "playlist" and item.playlist_id then
        M.dependency_graph[pl.id].direct_deps[#M.dependency_graph[pl.id].direct_deps + 1] = item.playlist_id
      end
    end
  end
  
  for _, pl in ipairs(M.playlists) do
    local all_deps = {}
    local visited = {}
    
    local function collect_deps(pid)
      if visited[pid] then return end
      visited[pid] = true
      
      local node = M.dependency_graph[pid]
      if not node then return end
      
      for _, dep_id in ipairs(node.direct_deps) do
        all_deps[dep_id] = true
        collect_deps(dep_id)
      end
    end
    
    collect_deps(pl.id)
    
    M.dependency_graph[pl.id].all_deps = all_deps
  end
  
  for target_id, target_node in pairs(M.dependency_graph) do
    for source_id, source_node in pairs(M.dependency_graph) do
      if target_id ~= source_id then
        if source_node.all_deps[target_id] or target_id == source_id then
          target_node.is_disabled_for[source_id] = true
        end
      end
    end
  end
  
  M.graph_dirty = false
end

function M.is_playlist_draggable_to(playlist_id, target_playlist_id)
  if M.graph_dirty then
    M.rebuild_dependency_graph()
  end
  
  if playlist_id == target_playlist_id then
    return false
  end
  
  local target_node = M.dependency_graph[target_playlist_id]
  if not target_node then
    return true
  end
  
  if target_node.is_disabled_for[playlist_id] then
    return false
  end
  
  local playlist_node = M.dependency_graph[playlist_id]
  if not playlist_node then
    return true
  end
  
  if playlist_node.all_deps[target_playlist_id] then
    return false
  end
  
  return true
end

function M.get_playlists_for_pool()
  if M.graph_dirty then
    M.rebuild_dependency_graph()
  end
  
  local pool_playlists = {}
  local active_id = M.active_playlist
  
  -- Build playlist index map for implicit ordering
  local playlist_index_map = {}
  for i, pl in ipairs(M.playlists) do
    playlist_index_map[pl.id] = i
  end
  
  for _, pl in ipairs(M.playlists) do
    if pl.id ~= active_id then
      local is_draggable = M.is_playlist_draggable_to(pl.id, active_id)
      local total_duration = calculate_playlist_duration(pl, M.region_index)
      
      pool_playlists[#pool_playlists + 1] = {
        type = "playlist",  -- Mark as playlist for mixed mode
        id = pl.id,
        name = pl.name,
        items = pl.items,
        chip_color = pl.chip_color or RegionState.generate_chip_color(),
        is_disabled = not is_draggable,
        index = playlist_index_map[pl.id] or 0,
        total_duration = total_duration,
      }
    end
  end
  
  local search = M.search_filter:lower()
  if search ~= "" then
    local filtered = {}
    for _, pl in ipairs(pool_playlists) do
      if pl.name:lower():find(search, 1, true) then
        filtered[#filtered + 1] = pl
      end
    end
    pool_playlists = filtered
  end
  
  local sort_mode = M.sort_mode
  local sort_dir = M.sort_direction or "asc"
  
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
  
  local sort_mode = M.sort_mode
  local sort_dir = M.sort_direction or "asc"
  
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
      return Colors.compare_colors(color_a, color_b)
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
  if M.graph_dirty then
    M.rebuild_dependency_graph()
  end
  
  if target_playlist_id == playlist_id_to_add then
    return true, {target_playlist_id}
  end
  
  local target_node = M.dependency_graph[target_playlist_id]
  if target_node and target_node.is_disabled_for[playlist_id_to_add] then
    return true, {playlist_id_to_add, target_playlist_id}
  end
  
  local playlist_node = M.dependency_graph[playlist_id_to_add]
  if playlist_node and playlist_node.all_deps[target_playlist_id] then
    local path = {playlist_id_to_add}
    
    local function build_path(from_id, to_id, current_path)
      if from_id == to_id then
        return current_path
      end
      
      local node = M.dependency_graph[from_id]
      if not node then return nil end
      
      for _, dep_id in ipairs(node.direct_deps) do
        if not current_path[dep_id] then
          local new_path = {}
          for k, v in pairs(current_path) do new_path[k] = v end
          new_path[dep_id] = true
          
          local result = build_path(dep_id, to_id, new_path)
          if result then
            return result
          end
        end
      end
      
      return nil
    end
    
    local path_set = {[playlist_id_to_add] = true}
    local full_path_set = build_path(playlist_id_to_add, target_playlist_id, path_set)
    
    if full_path_set then
      local path_array = {}
      for pid in pairs(full_path_set) do
        path_array[#path_array + 1] = pid
      end
      path_array[#path_array + 1] = target_playlist_id
      return true, path_array
    end
    
    return true, {playlist_id_to_add, "...", target_playlist_id}
  end
  
  return false
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
  
  for _, pl in ipairs(M.playlists) do
    local i = 1
    while i <= #pl.items do
      local item = pl.items[i]
      if item.type == "region" and not M.region_index[item.rid] then
        table.remove(pl.items, i)
        removed_any = true
        M.pending_destroy[item.key] = true
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
  local current_project_filename = get_current_project_filename()
  local current_project_ptr = get_current_project_ptr()

  -- Detect project change: either filename changed OR project pointer changed
  -- This handles both saved projects (filename changes) and unsaved projects (pointer changes)
  local project_changed = (current_project_filename ~= M.last_project_filename) or
                          (current_project_ptr ~= M.last_project_ptr)

  if project_changed then
    M.last_project_filename = current_project_filename
    M.last_project_ptr = current_project_ptr
    M.reload_project_data()
    return
  end
  
  local current_project_state = reaper.GetProjectStateChangeCount(0)
  if current_project_state ~= M.last_project_state then
    local old_region_count = 0
    for _ in pairs(M.region_index) do
      old_region_count = old_region_count + 1
    end
    
    M.refresh_regions()
    
    local new_region_count = 0
    for _ in pairs(M.region_index) do
      new_region_count = new_region_count + 1
    end
    
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
