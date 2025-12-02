-- @noindex
-- RegionPlaylist/app/pool_queries.lua
-- Pool filtering, sorting, and query operations (extracted from state.lua)

local Ark = require('arkitekt')
local Sorting = require('arkitekt.core.sorting')

local M = {}

-- =============================================================================
-- HELPERS
-- =============================================================================

-- Generate a deterministic color from a string (e.g., playlist ID)
-- This ensures the same ID always produces the same color
function M.deterministic_color_from_id(id)
  local str = tostring(id)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + str:byte(i)) % 2147483647
  end
  local hue = (hash % 360) / 360
  local saturation = 0.65 + ((hash % 100) / 400)  -- 0.65-0.90
  local lightness = 0.50 + ((hash % 60) / 400)    -- 0.50-0.65
  local r, g, b = Ark.Colors.hsl_to_rgb(hue, saturation, lightness)
  return Ark.Colors.components_to_rgba(r, g, b, 0xFF)
end

-- =============================================================================
-- DURATION CALCULATION
-- =============================================================================

-- Calculate total duration of all regions in a playlist
-- @param playlist The playlist to calculate duration for
-- @param region_index Map of rid -> region
-- @param get_playlist_by_id Function to get playlist by ID (for recursion)
-- @return Total duration in seconds
function M.calculate_playlist_duration(playlist, region_index, get_playlist_by_id)
  if not playlist or not playlist.items then return 0 end

  local total_duration = 0

  for _, item in ipairs(playlist.items) do
    -- Skip disabled items
    if item.enabled == false then
      goto continue
    end

    local item_type = item.type or 'region'
    local rid = item.rid

    if item_type == 'region' and rid then
      local region = region_index[rid]
      if region then
        local duration_seconds = (region['end'] or 0) - (region.start or 0)
        local repeats = item.reps or 1
        total_duration = total_duration + (duration_seconds * repeats)
      end
    elseif item_type == 'playlist' and item.playlist_id then
      -- For nested playlists, recursively calculate duration
      local nested_pl = get_playlist_by_id(item.playlist_id)
      if nested_pl then
        local nested_duration = M.calculate_playlist_duration(nested_pl, region_index, get_playlist_by_id)
        local repeats = item.reps or 1
        total_duration = total_duration + (nested_duration * repeats)
      end
    end

    ::continue::
  end

  return total_duration
end

-- =============================================================================
-- POOL QUERY FUNCTIONS
-- =============================================================================

-- Get filtered and sorted pool regions
-- @param params Table with: pool_order, region_index, search_filter, sort_mode, sort_dir
-- @return Filtered and sorted list of regions
function M.get_filtered_pool_regions(params)
  local result = {}
  local search = (params.search_filter or ''):lower()

  -- Filter regions
  for _, rid in ipairs(params.pool_order) do
    local region = params.region_index[rid]
    if region and region.name ~= '__TRANSITION_TRIGGER' and (search == '' or region.name:lower():find(search, 1, true)) then
      result[#result + 1] = region
    end
  end

  -- Apply sorting using framework module
  return Sorting.apply(result, {
    mode = params.sort_mode,
    direction = params.sort_dir,
    -- Custom accessor for index (use rid for regions)
    get_value = params.sort_mode == 'index' and function(x) return x.rid or 0 end or nil,
  })
end

-- Get playlists available for the pool (excludes active, applies sorting)
-- @param params Table with: playlists, active_id, region_index, search_filter, sort_mode, sort_dir,
--               is_draggable_to (function), get_playlist_by_id (function)
-- @return Filtered and sorted list of playlist pool entries
function M.get_playlists_for_pool(params)
  local pool_playlists = {}
  local playlists = params.playlists
  local active_id = params.active_id

  -- Build playlist index map for implicit ordering
  local playlist_index_map = {}
  for i, pl in ipairs(playlists) do
    playlist_index_map[pl.id] = i
  end

  for _, pl in ipairs(playlists) do
    if pl.id ~= active_id then
      local is_draggable = params.is_draggable_to(pl.id, active_id)
      local total_duration = M.calculate_playlist_duration(pl, params.region_index, params.get_playlist_by_id)

      pool_playlists[#pool_playlists + 1] = {
        type = 'playlist',
        id = pl.id,
        name = pl.name,
        items = pl.items,
        chip_color = pl.chip_color or M.deterministic_color_from_id(pl.id),
        is_disabled = not is_draggable,
        index = playlist_index_map[pl.id] or 0,
        total_duration = total_duration,
      }
    end
  end

  -- Apply search filter
  local search = (params.search_filter or ''):lower()
  if search ~= '' then
    local filtered = {}
    for _, pl in ipairs(pool_playlists) do
      if pl.name:lower():find(search, 1, true) then
        filtered[#filtered + 1] = pl
      end
    end
    pool_playlists = filtered
  end

  -- Apply sorting using framework module
  return Sorting.apply(pool_playlists, {
    mode = params.sort_mode,
    direction = params.sort_dir,
    -- Custom accessors for playlist-specific fields
    get_value = (params.sort_mode == 'color' and function(x) return x.chip_color or 0 end)
             or (params.sort_mode == 'length' and function(x) return x.total_duration or 0 end)
             or nil,
  })
end

-- Get mixed pool (regions + playlists) with unified sorting
-- @param params Table with: regions (pre-filtered), playlists (pre-filtered), sort_mode, sort_dir
-- @return Combined and sorted list
function M.get_mixed_pool_sorted(params)
  local regions = params.regions
  local playlists = params.playlists
  local sort_mode = params.sort_mode
  local sort_dir = params.sort_dir or 'asc'

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

  -- Combine items
  local combined = {}

  -- Add regions (mark type if not present)
  for _, region in ipairs(regions) do
    if not region.type then
      region.type = 'region'
    end
    combined[#combined + 1] = region
  end

  -- Add playlists (already marked with type='playlist')
  for _, playlist in ipairs(playlists) do
    combined[#combined + 1] = playlist
  end

  -- Build unified accessor that handles both regions and playlists
  local get_value
  if sort_mode == 'color' then
    get_value = function(x) return x.chip_color or x.color or 0 end
  elseif sort_mode == 'index' then
    get_value = function(x) return x.index or x.rid or 0 end
  elseif sort_mode == 'length' then
    get_value = function(x)
      if x.type == 'playlist' then
        return x.total_duration or 0
      else
        return (x['end'] or 0) - (x.start or 0)
      end
    end
  end

  -- Apply sorting using framework module
  return Sorting.apply(combined, {
    mode = sort_mode,
    direction = sort_dir,
    get_value = get_value,
  })
end

return M
