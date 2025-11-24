-- @noindex
-- Shared utilities for audio and MIDI grid factories
-- Extracts common filtering, sorting, and conversion logic

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local pool_utils = require('ItemPicker.services.pool_utils')

local M = {}

-- Build filter hash for cache invalidation
function M.build_filter_hash(settings, indexes)
  return string.format("%s|%s|%s|%s|%s|%s|%s|%s|%s|%d",
    tostring(settings.show_favorites_only),
    tostring(settings.show_disabled_items),
    tostring(settings.show_muted_tracks),
    tostring(settings.show_muted_items),
    settings.search_string or "",
    settings.search_mode or "items",
    settings.sort_mode or "none",
    tostring(settings.sort_reverse or false),
    table.concat(indexes, ","),
    #indexes
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

-- Check if item passes search filter (supports items/tracks/regions/mixed modes)
function M.passes_search_filter(settings, item_name, track_name, regions)
  local search = settings.search_string or ""
  if type(search) ~= "string" or search == "" then
    return true
  end

  local search_mode = settings.search_mode or "items"
  local search_lower = search:lower()

  if search_mode == "items" then
    return item_name:lower():find(search_lower, 1, true) ~= nil
  elseif search_mode == "tracks" then
    return track_name and track_name:lower():find(search_lower, 1, true) ~= nil
  elseif search_mode == "regions" then
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == "table" and region.name or region
        if region_name and region_name:lower():find(search_lower, 1, true) then
          return true
        end
      end
    end
    return false
  elseif search_mode == "mixed" then
    -- Search all: item names, track names, and region names
    if item_name:lower():find(search_lower, 1, true) then
      return true
    end
    if track_name and track_name:lower():find(search_lower, 1, true) then
      return true
    end
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == "table" and region.name or region
        if region_name and region_name:lower():find(search_lower, 1, true) then
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
function M.apply_sorting(filtered, sort_mode, sort_reverse)
  if sort_mode == "length" then
    table.sort(filtered, function(a, b)
      local a_len = a.length or 0
      local b_len = b.length or 0
      if sort_reverse then
        return a_len < b_len
      else
        return a_len > b_len
      end
    end)
  elseif sort_mode == "color" then
    table.sort(filtered, function(a, b)
      local a_color = a.color or 0
      local b_color = b.color or 0
      if sort_reverse then
        return a_color < b_color
      else
        return a_color > b_color
      end
    end)
  elseif sort_mode == "name" then
    table.sort(filtered, function(a, b)
      local a_name = (a.name or ""):lower()
      local b_name = (b.name or ""):lower()
      if sort_reverse then
        return a_name > b_name
      else
        return a_name < b_name
      end
    end)
  elseif sort_mode == "pool" then
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
      local a_name = (a.name or ""):lower()
      local b_name = (b.name or ""):lower()
      return a_name < b_name
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
      table.insert(filtered_list, {index = i, entry = entry})
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
