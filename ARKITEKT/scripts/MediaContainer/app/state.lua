-- @noindex
-- MediaContainer/app/state.lua
-- Single-source-of-truth state management for media containers
--
-- ARCHITECTURE:
-- Centralized state for container registry, clipboard, and project tracking.
-- Uses ProjectMonitor for detecting project switches and reloads.
-- Integrates with optional Settings for persistent UI preferences.

local Persistence = require('MediaContainer.data.persistence')
local Colors = require('arkitekt.core.colors')
local Constants = require('MediaContainer.config.constants')
local ProjectMonitor = require('arkitekt.reaper.project_monitor')
local Logger = require('arkitekt.debug.logger')

-- =============================================================================
-- PERF: Localize frequently-used functions (30% faster per call)
-- =============================================================================

local random = math.random
local format = string.format

-- REAPER functions used in hot paths (GUID cache rebuild)
local CountMediaItems = reaper.CountMediaItems
local CountTracks = reaper.CountTracks
local GetMediaItem = reaper.GetMediaItem
local GetTrack = reaper.GetTrack
local BR_GetMediaItemGUID = reaper.BR_GetMediaItemGUID
local GetTrackGUID = reaper.GetTrackGUID
local ValidatePtr2 = reaper.ValidatePtr2
local GetMediaItemInfo_Value = reaper.GetMediaItemInfo_Value
local GetMediaItemTakeInfo_Value = reaper.GetMediaItemTakeInfo_Value
local GetActiveTake = reaper.GetActiveTake
local GetMediaTrackInfo_Value = reaper.GetMediaTrackInfo_Value

local M = {}

package.loaded['MediaContainer.app.state'] = M

-- =============================================================================
-- STATE FIELDS
-- =============================================================================

-- Container registry
M.containers = {}
M.container_lookup = {}  -- UUID -> container (O(1) lookup)

-- Runtime state
M.clipboard_container_id = nil
M.last_container_count = 0  -- Track container count for reload detection

-- Change tracking
M.item_state_cache = {}  -- item_guid -> state_hash

-- GUID lookup caches (performance optimization)
M.item_guid_cache = {}   -- GUID -> item pointer (O(1) lookup)
M.track_guid_cache = {}  -- GUID -> track pointer (O(1) lookup)
M.guid_cache_dirty = true  -- Flag to rebuild caches

-- Project monitoring
M.project_monitor = nil

-- Settings (optional, for persistent UI preferences)
M.settings = nil

-- =============================================================================
-- PRIVATE FUNCTIONS
-- =============================================================================

local function _rebuild_container_lookup()
  M.container_lookup = {}
  for _, container in ipairs(M.containers) do
    M.container_lookup[container.id] = container
  end
end

local function _rebuild_guid_caches()
  -- Rebuild item GUID cache
  -- PERF: Use localized functions and cache count
  M.item_guid_cache = {}
  local item_count = CountMediaItems(0)
  for i = 0, item_count - 1 do
    local item = GetMediaItem(0, i)
    if item then
      local guid = BR_GetMediaItemGUID(item)
      if guid then
        M.item_guid_cache[guid] = item
      end
    end
  end

  -- Rebuild track GUID cache
  M.track_guid_cache = {}
  local track_count = CountTracks(0)
  for i = 0, track_count - 1 do
    local track = GetTrack(0, i)
    if track then
      local guid = GetTrackGUID(track)
      if guid then
        M.track_guid_cache[guid] = track
      end
    end
  end

  M.guid_cache_dirty = false
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

function M.initialize(settings)
  M.settings = settings
  M.guid_cache_dirty = true

  Logger.debug('STATE', 'Initializing MediaContainer state')

  -- Initialize project monitor to track changes
  M.project_monitor = ProjectMonitor.new({
    on_project_switch = function(old_proj, new_proj)
      Logger.info('STATE', 'Project switched, reloading data')
      M.reload_project_data()
    end,
    on_project_reload = function()
      Logger.info('STATE', 'Project reloaded, reloading data')
      M.reload_project_data()
    end,
    on_state_change = function(change_count)
      -- Check if container count changed (another script modified)
      if M.check_containers_changed() then
        Logger.debug('STATE', 'Container count changed externally, reloading')
        M.load_project_state()
      end
    end,
    check_state_changes = true,
  })

  M.load_project_state()
  Logger.info('STATE', 'Initialized with %d containers', #M.containers)
end

function M.load_project_state()
  M.containers = Persistence.load_containers(0)
  _rebuild_container_lookup()
  M.clipboard_container_id = Persistence.load_clipboard(0)
  M.last_container_count = #M.containers
  M.guid_cache_dirty = true

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
  _rebuild_container_lookup()
  Persistence.save_containers(M.containers, 0)
  Persistence.save_clipboard(M.clipboard_container_id, 0)
end

-- =============================================================================
-- CONTAINER ACCESSORS
-- =============================================================================

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
  M.last_container_count = #M.containers
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
  M.last_container_count = #M.containers
  M.persist()
end

-- =============================================================================
-- CLIPBOARD OPERATIONS
-- =============================================================================

function M.set_clipboard(container_id)
  M.clipboard_container_id = container_id
  Persistence.save_clipboard(container_id, 0)
end

function M.get_clipboard()
  return M.clipboard_container_id
end

-- =============================================================================
-- ITEM STATE TRACKING
-- =============================================================================

-- Item state hashing for change detection
-- Uses RELATIVE position to container, so moving whole container doesn't trigger sync
function M.get_item_state_hash(item, container)
  if not item or not ValidatePtr2(0, item, 'MediaItem*') then
    return nil
  end

  -- PERF: Use localized reaper functions
  local abs_pos = GetMediaItemInfo_Value(item, 'D_POSITION')
  local len = GetMediaItemInfo_Value(item, 'D_LENGTH')

  -- Use relative position if container provided, otherwise absolute
  local pos = abs_pos
  if container then
    pos = abs_pos - container.start_time
  end
  local mute = GetMediaItemInfo_Value(item, 'B_MUTE')
  local vol = GetMediaItemInfo_Value(item, 'D_VOL')
  local fadein = GetMediaItemInfo_Value(item, 'D_FADEINLEN')
  local fadeout = GetMediaItemInfo_Value(item, 'D_FADEOUTLEN')
  local fadein_shape = GetMediaItemInfo_Value(item, 'C_FADEINSHAPE')
  local fadeout_shape = GetMediaItemInfo_Value(item, 'C_FADEOUTSHAPE')
  local snapoffs = GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')

  -- Get take-specific properties
  local take = GetActiveTake(item)
  local pitch = 0
  local rate = 1
  local take_vol = 1
  if take then
    pitch = GetMediaItemTakeInfo_Value(take, 'D_PITCH')
    rate = GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
    take_vol = GetMediaItemTakeInfo_Value(take, 'D_VOL')
  end

  return format('%.6f_%.6f_%d_%.6f_%.6f_%.6f_%d_%d_%.6f_%.6f_%.6f_%.6f',
    pos, len, mute, vol, fadein, fadeout, fadein_shape, fadeout_shape,
    snapoffs, pitch, rate, take_vol)
end

function M.rebuild_item_state_cache()
  M.item_state_cache = {}

  -- PERF: Use numeric for loops instead of ipairs
  local containers = M.containers
  local num_containers = #containers
  for i = 1, num_containers do
    local container = containers[i]
    local items = container.items
    local num_items = #items
    for j = 1, num_items do
      local item_ref = items[j]
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

-- =============================================================================
-- GUID LOOKUPS
-- =============================================================================

-- Find Reaper item by GUID (O(1) with caching)
function M.find_item_by_guid(guid)
  if not guid then return nil end

  -- Rebuild cache if dirty
  if M.guid_cache_dirty then
    _rebuild_guid_caches()
  end

  -- Try cache first
  local item = M.item_guid_cache[guid]
  if item and ValidatePtr2(0, item, 'MediaItem*') then
    return item
  end

  -- Cache miss - rebuild and retry (item may have been created recently)
  _rebuild_guid_caches()
  return M.item_guid_cache[guid]
end

-- Get track by GUID (O(1) with caching)
function M.find_track_by_guid(guid)
  if not guid then return nil end

  -- Rebuild cache if dirty
  if M.guid_cache_dirty then
    _rebuild_guid_caches()
  end

  -- Try cache first
  local track = M.track_guid_cache[guid]
  if track and ValidatePtr2(0, track, 'MediaTrack*') then
    return track
  end

  -- Cache miss - rebuild and retry (track may have been created recently)
  _rebuild_guid_caches()
  return M.track_guid_cache[guid]
end

-- Get track index (0-based)
function M.get_track_index(track)
  return GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER') - 1
end

-- =============================================================================
-- UTILITIES
-- =============================================================================

-- Generate random color for container
function M.generate_container_color()
  local cfg = Constants.CONTAINER
  local hue = random()
  local saturation = cfg.saturation_min + random() * cfg.saturation_range
  local lightness = cfg.lightness_min + random() * cfg.lightness_range

  local r, g, b = Colors.HslToRgb(hue, saturation, lightness)
  return Colors.ComponentsToRgba(r, g, b, 0xFF)
end

-- =============================================================================
-- UPDATE LOOP
-- =============================================================================

function M.Update()
  if M.project_monitor then
    M.project_monitor:update()
  end
end

return M
