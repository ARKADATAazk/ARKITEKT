-- @noindex
-- MediaContainer/core/app_state.lua
-- Single-source-of-truth state management for media containers

local Persistence = require("MediaContainer.storage.persistence")
local UUID = require("rearkitekt.core.uuid")
local Colors = require("rearkitekt.core.colors")

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

-- Change tracking
M.item_state_cache = {}  -- item_guid -> state_hash

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
  M.load_project_state()
end

function M.load_project_state()
  M.containers = Persistence.load_containers(0)
  rebuild_container_lookup()
  M.clipboard_container_id = Persistence.load_clipboard(0)

  -- Rebuild item state cache for change detection
  M.rebuild_item_state_cache()
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
function M.get_item_state_hash(item)
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
    return nil
  end

  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
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
        local hash = M.get_item_state_hash(item)
        if hash then
          M.item_state_cache[item_ref.guid] = hash
        end
      end
    end
  end
end

-- Find Reaper item by GUID
function M.find_item_by_guid(guid)
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    local item_guid = reaper.BR_GetMediaItemGUID(item)
    if item_guid == guid then
      return item
    end
  end
  return nil
end

-- Get track by GUID
function M.find_track_by_guid(guid)
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local track_guid = reaper.GetTrackGUID(track)
    if track_guid == guid then
      return track
    end
  end
  return nil
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

  return false
end

return M
