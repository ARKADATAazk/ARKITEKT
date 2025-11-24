-- @noindex
-- MediaContainer/core/app_state.lua
-- Single-source-of-truth state management for media containers

local Persistence = require("MediaContainer.storage.persistence")
local UUID = require("arkitekt.core.uuid")
local Colors = require("arkitekt.core.colors")

local M = {}

package.loaded["MediaContainer.core.app_state"] = M

-- Container registry
M.containers = {}
M.container_lookup = {}  -- UUID -> container (O(1) lookup)

-- Runtime state
M.clipboard_container_id = nil
M.last_project_state = -1
M.last_project_filename = nil
M.last_project_ptr = nil
M.last_container_count = 0  -- Track container count for reload detection

-- Change tracking
M.item_state_cache = {}  -- item_guid -> state_hash

-- GUID lookup caches (performance optimization)
M.item_guid_cache = {}   -- GUID -> item pointer (O(1) lookup)
M.track_guid_cache = {}  -- GUID -> track pointer (O(1) lookup)
M.guid_cache_dirty = true  -- Flag to rebuild caches

local function get_current_project_filename()
  local proj_path = reaper.GetProjectPath("")
  local proj_name = reaper.GetProjectName(0, "")
  if proj_path == "" or proj_name == "" then
    return nil
  end
  return proj_path .. "/" .. proj_name
end

local function get_current_project_ptr()
  local proj, _ = reaper.EnumProjects(-1, "")
  return proj
end

local function rebuild_container_lookup()
  M.container_lookup = {}
  for _, container in ipairs(M.containers) do
    M.container_lookup[container.id] = container
  end
end

function M.initialize()
  M.last_project_filename = get_current_project_filename()
  M.last_project_ptr = get_current_project_ptr()
  M.guid_cache_dirty = true  -- Mark cache dirty on initialization
  M.load_project_state()
end

function M.load_project_state()
  M.containers = Persistence.load_containers(0)
  rebuild_container_lookup()
  M.clipboard_container_id = Persistence.load_clipboard(0)
  M.last_container_count = #M.containers
  M.guid_cache_dirty = true  -- Mark cache dirty when project state changes

  -- Rebuild item state cache for change detection
  M.rebuild_item_state_cache()
end

-- Check if containers changed (another script added/removed)
function M.check_containers_changed()
  local stored = Persistence.load_containers(0)
  return #stored ~= M.last_container_count
end

function M.reload_project_data()
  M.load_project_state()
end

function M.persist()
  rebuild_container_lookup()
  Persistence.save_containers(M.containers, 0)
  Persistence.save_clipboard(M.clipboard_container_id, 0)
end

-- Container accessors
function M.get_container_by_id(container_id)
  return M.container_lookup[container_id]
end

function M.get_all_containers()
  return M.containers
end

function M.get_master_container(container)
  if not container.master_id then
    return container
  end
  return M.container_lookup[container.master_id]
end

function M.get_linked_containers(master_id)
  local linked = {}
  for _, container in ipairs(M.containers) do
    if container.master_id == master_id or container.id == master_id then
      linked[#linked + 1] = container
    end
  end
  return linked
end

function M.add_container(container)
  M.containers[#M.containers + 1] = container
  M.container_lookup[container.id] = container
  M.last_container_count = #M.containers  -- Update count to prevent reload
  M.persist()
end

function M.remove_container(container_id)
  for i, container in ipairs(M.containers) do
    if container.id == container_id then
      table.remove(M.containers, i)
      M.container_lookup[container_id] = nil
      break
    end
  end
  M.last_container_count = #M.containers  -- Update count to prevent reload
  M.persist()
end

-- Clipboard operations
function M.set_clipboard(container_id)
  M.clipboard_container_id = container_id
  Persistence.save_clipboard(container_id, 0)
end

function M.get_clipboard()
  return M.clipboard_container_id
end

-- Item state hashing for change detection
-- Uses RELATIVE position to container, so moving whole container doesn't trigger sync
function M.get_item_state_hash(item, container)
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
    return nil
  end

  local abs_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  -- Use relative position if container provided, otherwise absolute
  local pos = abs_pos
  if container then
    pos = abs_pos - container.start_time
  end
  local mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
  local vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
  local fadein = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
  local fadeout = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
  local fadein_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEINSHAPE")
  local fadeout_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE")
  local snapoffs = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")

  -- Get take-specific properties
  local take = reaper.GetActiveTake(item)
  local pitch = 0
  local rate = 1
  local take_vol = 1
  if take then
    pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
    rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    take_vol = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
  end

  return string.format("%.6f_%.6f_%d_%.6f_%.6f_%.6f_%d_%d_%.6f_%.6f_%.6f_%.6f",
    pos, len, mute, vol, fadein, fadeout, fadein_shape, fadeout_shape,
    snapoffs, pitch, rate, take_vol)
end

function M.rebuild_item_state_cache()
  M.item_state_cache = {}

  for _, container in ipairs(M.containers) do
    for _, item_ref in ipairs(container.items) do
      local item = M.find_item_by_guid(item_ref.guid)
      if item then
        local hash = M.get_item_state_hash(item, container)
        if hash then
          M.item_state_cache[item_ref.guid] = hash
        end
      end
    end
  end
end

-- Rebuild GUID caches (call when project changes detected)
local function rebuild_guid_caches()
  -- Rebuild item GUID cache
  M.item_guid_cache = {}
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    if item then
      local guid = reaper.BR_GetMediaItemGUID(item)
      if guid then
        M.item_guid_cache[guid] = item
      end
    end
  end

  -- Rebuild track GUID cache
  M.track_guid_cache = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
      local guid = reaper.GetTrackGUID(track)
      if guid then
        M.track_guid_cache[guid] = track
      end
    end
  end

  M.guid_cache_dirty = false
end

-- Find Reaper item by GUID (O(1) with caching)
function M.find_item_by_guid(guid)
  if not guid then return nil end

  -- Rebuild cache if dirty
  if M.guid_cache_dirty then
    rebuild_guid_caches()
  end

  -- Try cache first
  local item = M.item_guid_cache[guid]
  if item and reaper.ValidatePtr2(0, item, "MediaItem*") then
    return item
  end

  -- Cache miss - rebuild and retry (item may have been created recently)
  rebuild_guid_caches()
  return M.item_guid_cache[guid]
end

-- Get track by GUID (O(1) with caching)
function M.find_track_by_guid(guid)
  if not guid then return nil end

  -- Rebuild cache if dirty
  if M.guid_cache_dirty then
    rebuild_guid_caches()
  end

  -- Try cache first
  local track = M.track_guid_cache[guid]
  if track and reaper.ValidatePtr2(0, track, "MediaTrack*") then
    return track
  end

  -- Cache miss - rebuild and retry (track may have been created recently)
  rebuild_guid_caches()
  return M.track_guid_cache[guid]
end

-- Get track index (0-based)
function M.get_track_index(track)
  return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
end

-- Generate random color for container
function M.generate_container_color()
  local hue = math.random()
  local saturation = 0.65 + math.random() * 0.25
  local lightness = 0.50 + math.random() * 0.15

  local r, g, b = Colors.hsl_to_rgb(hue, saturation, lightness)
  return Colors.components_to_rgba(r, g, b, 0xFF)
end

-- Check for project changes
function M.update()
  local current_project_filename = get_current_project_filename()
  local current_project_ptr = get_current_project_ptr()

  local project_changed = (current_project_filename ~= M.last_project_filename) or
                          (current_project_ptr ~= M.last_project_ptr)

  if project_changed then
    M.last_project_filename = current_project_filename
    M.last_project_ptr = current_project_ptr
    M.reload_project_data()
    return true
  end

  -- Only reload if another script added/removed containers
  -- Don't reload on every state change (that would clear item cache)
  local current_state = reaper.GetProjectStateChangeCount(0)
  if current_state ~= M.last_project_state then
    M.last_project_state = current_state
    -- Check if container count changed (another script modified)
    if M.check_containers_changed() then
      M.load_project_state()
    end
  end

  return false
end

return M
