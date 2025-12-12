-- @noindex
-- ItemPicker/domain/filters/items.lua
-- Pure item filtering and sorting logic (no UI dependencies)

local M = {}

-- Build filter hash for cache invalidation
function M.build_filter_hash(settings, indexes)
  return string.format('%s|%s|%s|%s|%s|%s|%s|%s|%s|%d',
    tostring(settings.show_favorites_only),
    tostring(settings.show_disabled_items),
    tostring(settings.show_muted_tracks),
    tostring(settings.show_muted_items),
    settings.search_string or '',
    settings.search_mode or 'items',
    settings.sort_mode or 'none',
    tostring(settings.sort_reverse or false),
    table.concat(indexes, ','),
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
  local search = settings.search_string or ''
  if type(search) ~= 'string' or search == '' then
    return true
  end

  local search_mode = settings.search_mode or 'items'
  local search_lower = search:lower()

  if search_mode == 'items' then
    return item_name:lower():find(search_lower, 1, true) ~= nil
  elseif search_mode == 'tracks' then
    return track_name and track_name:lower():find(search_lower, 1, true) ~= nil
  elseif search_mode == 'regions' then
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == 'table' and region.name or region
        if region_name and region_name:lower():find(search_lower, 1, true) then
          return true
        end
      end
    end
    return false
  elseif search_mode == 'mixed' then
    if item_name:lower():find(search_lower, 1, true) then
      return true
    end
    if track_name and track_name:lower():find(search_lower, 1, true) then
      return true
    end
    if regions then
      for _, region in ipairs(regions) do
        local region_name = type(region) == 'table' and region.name or region
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
function M.passes_track_filter(track_filters_enabled, track_guid)
  if not track_filters_enabled then
    return true
  end

  -- Check if at least one track is disabled
  local has_disabled = false
  for guid, enabled in pairs(track_filters_enabled) do
    if not enabled then
      has_disabled = true
      break
    end
  end

  if not has_disabled then
    return true
  end

  if not track_guid then
    return true
  end

  local is_enabled = track_filters_enabled[track_guid]
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

-- Check if item passes all filters (convenience function)
function M.passes_all_filters(settings, state, entry, key)
  if not M.passes_favorites_filter(settings, state.favorites or {}, key) then
    return false
  end
  if not M.passes_disabled_filter(settings, state.disabled_items or {}, key) then
    return false
  end
  if not M.passes_mute_filters(settings, entry.track_muted, entry.item_muted) then
    return false
  end
  if not M.passes_search_filter(settings, entry.name or '', entry.track_name, entry.regions) then
    return false
  end
  if not M.passes_track_filter(state.track_filters_enabled, entry.track_guid) then
    return false
  end
  return true
end

return M
