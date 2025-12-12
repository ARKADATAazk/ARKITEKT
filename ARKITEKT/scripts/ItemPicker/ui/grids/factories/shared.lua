-- @noindex
-- ItemPicker/ui/grids/factories/shared.lua
-- Shared utilities for audio and MIDI grid factories
-- Extracts common filtering, sorting, and conversion logic

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local pool_utils = require('ItemPicker.domain.filters.pool')

local M = {}

-- Simple string hash for cache keys
local function string_hash(s)
  if not s then return 0 end
  local h = 0
  for i = 1, math.min(#s, 16) do  -- Only hash first 16 chars for speed
    h = (h * 31 + string.byte(s, i)) % 2147483647
  end
  return h
end

-- Build filter hash for cache invalidation
-- Uses numeric hash instead of string concatenation for performance
function M.build_filter_hash(settings, indexes)
  -- Compute numeric hash of indexes array (avoids O(n) string allocation)
  -- Uses count + first/last values + sampling for quick change detection
  local idx_count = #indexes
  local idx_hash = idx_count
  if idx_count > 0 then
    -- Include first, last, and middle values for collision resistance
    -- indexes contains strings (filenames/item names), so hash them
    idx_hash = idx_hash * 31 + string_hash(indexes[1])
    idx_hash = idx_hash * 31 + string_hash(indexes[idx_count])
    if idx_count > 2 then
      local mid = (idx_count + 1) // 2
      idx_hash = idx_hash * 31 + string_hash(indexes[mid])
    end
  end

  return string.format('%s|%s|%s|%s|%s|%s|%s|%s|%d',
    tostring(settings.show_favorites_only),
    tostring(settings.show_disabled_items),
    tostring(settings.show_muted_tracks),
    tostring(settings.show_muted_items),
    settings.search_string or '',
    settings.search_mode or 'items',
    settings.sort_mode or 'track',
    tostring(settings.sort_reverse or false),
    idx_hash
  )
end

-- Check if item passes favorites filter
function M.passes_favorites_filter(settings, favorites_map, key)
  if settings.show_favorites_only and not favorites_map[key] then
    return false
  end
  return true
end

-- Check if item passes disabled filter
function M.passes_disabled_filter(settings, disabled_map, key)
  if not settings.show_disabled_items and disabled_map[key] then
    return false
  end
  return true
end

-- Check if item passes mute filters
function M.passes_mute_filters(settings, track_muted, item_muted)
  if not settings.show_muted_tracks and track_muted then
    return false
  end
  if not settings.show_muted_items and item_muted then
    return false
  end
  return true
end

-- Cache for lowercased search string (avoids per-item allocation)
local _search_cache = { raw = nil, lower = nil }

-- Check if item passes search filter (supports items/tracks/regions/mixed modes)
-- PERF: Uses cached lowercase search string; accepts optional pre-lowercased names
function M.passes_search_filter(settings, item_name, track_name, regions, item_name_lower, track_name_lower)
  local search = settings.search_string or ''
  if type(search) ~= 'string' or search == '' then
    return true
  end

  -- Cache lowercase search string (only recompute when search changes)
  local search_lower
  if _search_cache.raw == search then
    search_lower = _search_cache.lower
  else
    search_lower = search:lower()
    _search_cache.raw = search
    _search_cache.lower = search_lower
  end

  local search_mode = settings.search_mode or 'items'

  if search_mode == 'items' then
    local name_l = item_name_lower or item_name:lower()
    return name_l:find(search_lower, 1, true) ~= nil
  elseif search_mode == 'tracks' then
    if not track_name then return false end
    local track_l = track_name_lower or track_name:lower()
    return track_l:find(search_lower, 1, true) ~= nil
  elseif search_mode == 'regions' then
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == 'table' and region.name or region
        local region_lower = type(region) == 'table' and region.name_lower or (region_name and region_name:lower())
        if region_lower and region_lower:find(search_lower, 1, true) then
          return true
        end
      end
    end
    return false
  elseif search_mode == 'mixed' then
    -- Search all: item names, track names, and region names
    local name_l = item_name_lower or item_name:lower()
    if name_l:find(search_lower, 1, true) then
      return true
    end
    if track_name then
      local track_l = track_name_lower or track_name:lower()
      if track_l:find(search_lower, 1, true) then
        return true
      end
    end
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == 'table' and region.name or region
        local region_lower = type(region) == 'table' and region.name_lower or (region_name and region_name:lower())
        if region_lower and region_lower:find(search_lower, 1, true) then
          return true
        end
      end
    end
    return false
  end

  return true
end

-- Check if item passes track filter
function M.passes_track_filter(state, track_guid)
  -- If no track filtering is set up, pass all items
  if not state.track_filters_enabled then
    return true
  end

  -- Check if at least one track is disabled (otherwise no filtering needed)
  local has_disabled = false
  for guid, enabled in pairs(state.track_filters_enabled) do
    if not enabled then
      has_disabled = true
      break
    end
  end

  if not has_disabled then
    return true  -- All tracks enabled, no filtering
  end

  -- Check if this item's track is enabled
  if not track_guid then
    return true  -- No track info, pass by default
  end

  local is_enabled = state.track_filters_enabled[track_guid]
  -- If not in the map, it means it's not whitelisted, so filter it out
  if is_enabled == nil then
    return false
  end

  return is_enabled
end

-- Sort filtered items by various criteria
-- @param filtered table - list of items to sort (modified in place)
-- @param sort_mode string - 'none', 'length', 'color', 'name', 'pool', 'recent', 'track', 'position'
-- @param sort_reverse boolean - reverse the sort order
-- @param item_usage table - (optional) { [uuid] = timestamp } for 'recent' sort
function M.apply_sorting(filtered, sort_mode, sort_reverse, item_usage)
  if sort_mode == 'length' then
    table.sort(filtered, function(a, b)
      local a_len = a.length or 0
      local b_len = b.length or 0
      if sort_reverse then
        return a_len < b_len
      else
        return a_len > b_len
      end
    end)
  elseif sort_mode == 'color' then
    table.sort(filtered, function(a, b)
      local a_color = a.color or 0
      local b_color = b.color or 0
      if sort_reverse then
        return a_color < b_color
      else
        return a_color > b_color
      end
    end)
  elseif sort_mode == 'name' then
    table.sort(filtered, function(a, b)
      local a_name = (a.name or ''):lower()
      local b_name = (b.name or ''):lower()
      if sort_reverse then
        return a_name > b_name
      else
        return a_name < b_name
      end
    end)
  elseif sort_mode == 'pool' then
    table.sort(filtered, function(a, b)
      local a_pool = a.pool_count or 1
      local b_pool = b.pool_count or 1
      if a_pool ~= b_pool then
        if sort_reverse then
          return a_pool < b_pool
        else
          return a_pool > b_pool
        end
      end
      -- Tie-breaker: sort by name
      local a_name = (a.name or ''):lower()
      local b_name = (b.name or ''):lower()
      return a_name < b_name
    end)
  elseif sort_mode == 'recent' then
    -- Sort by recently used (most recent first by default)
    -- Items never used go to the end
    item_usage = item_usage or {}
    table.sort(filtered, function(a, b)
      local a_time = item_usage[a.uuid] or 0
      local b_time = item_usage[b.uuid] or 0
      if a_time ~= b_time then
        if sort_reverse then
          return a_time < b_time  -- Oldest first when reversed
        else
          return a_time > b_time  -- Most recent first (default)
        end
      end
      -- Tie-breaker: alphabetical by name
      local a_name = (a.name or ''):lower()
      local b_name = (b.name or ''):lower()
      return a_name < b_name
    end)
  elseif sort_mode == 'track' then
    -- Sort by track index (top-to-bottom in project)
    table.sort(filtered, function(a, b)
      local a_track = a.track_index or 9999
      local b_track = b.track_index or 9999
      if a_track ~= b_track then
        if sort_reverse then
          return a_track > b_track  -- Bottom tracks first when reversed
        else
          return a_track < b_track  -- Top tracks first (default)
        end
      end
      -- Tie-breaker: timeline position
      local a_pos = a.item_position or 0
      local b_pos = b.item_position or 0
      return a_pos < b_pos
    end)
  elseif sort_mode == 'position' then
    -- Sort by timeline position (earliest first by default)
    table.sort(filtered, function(a, b)
      local a_pos = a.item_position or 0
      local b_pos = b.item_position or 0
      if sort_reverse then
        return a_pos > b_pos  -- Latest first when reversed
      else
        return a_pos < b_pos  -- Earliest first (default)
      end
    end)
  end
end

-- Convert REAPER track color to RGBA
function M.convert_track_color(track_color)
  if (track_color & 0x01000000) ~= 0 then
    local colorref = track_color & 0x00FFFFFF
    local R = colorref & 255
    local G = (colorref >> 8) & 255
    local B = (colorref >> 16) & 255
    return ImGui.ColorConvertDouble4ToU32(R/255, G/255, B/255, 1)
  else
    -- Default grey for no custom color
    return ImGui.ColorConvertDouble4ToU32(85/255, 91/255, 91/255, 1)
  end
end

-- Get filtered position and count for an item in content array
function M.get_filtered_position(content, current_idx)
  local seen_pools = {}
  local filtered_list = {}

  for i, entry in ipairs(content) do
    if not pool_utils.is_pooled_duplicate(entry, seen_pools) then
      filtered_list[#filtered_list + 1] = {index = i, entry = entry}
    end
  end

  local current_position = 1
  for pos, item in ipairs(filtered_list) do
    if item.index == current_idx then
      current_position = pos
      break
    end
  end

  return current_position, #filtered_list
end

-- Build UUID-to-key mapping for selected items
function M.build_uuid_to_key_map(selected_keys, content_map, current_item_map)
  local map = {}
  for _, uuid in ipairs(selected_keys) do
    for key, content in pairs(content_map) do
      local idx = current_item_map[key] or 1
      local entry = content[idx]
      if entry and entry.uuid == uuid then
        map[uuid] = key
        break
      end
    end
  end
  return map
end

-- Toggle state for multi-select (batch operation)
function M.toggle_multi_select(selected_keys, uuid_map, state_table, get_first_state)
  if #selected_keys > 1 then
    -- Batch toggle based on first item's state
    local first_key = uuid_map[selected_keys[1]]
    local new_state = not get_first_state(first_key)

    for _, uuid in ipairs(selected_keys) do
      local key = uuid_map[uuid]
      if key then
        if new_state then
          state_table[key] = true
        else
          state_table[key] = nil
        end
      end
    end
  elseif #selected_keys == 1 then
    -- Single toggle
    local key = uuid_map[selected_keys[1]]
    if key then
      if state_table[key] then
        state_table[key] = nil
      else
        state_table[key] = true
      end
    end
  end
end

return M
