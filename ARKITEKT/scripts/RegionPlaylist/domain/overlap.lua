-- @noindex
-- RegionPlaylist/domain/overlap.lua
-- Detects overlapping/nested regions (business logic, no ImGui)
--
-- A region is "nested" if another region's start or end falls within it.
-- This can cause playback issues as the transport may jump unexpectedly.
--
-- Based on SWS RegionPlaylist GetNestedRegion() logic.

local M = {}

-- Fudge factor to ignore adjacent/touching regions (in seconds)
-- Regions that merely touch at boundaries are not considered nested
local FUDGE_FACTOR = 0.001

--- Check if a position falls within a region's boundaries (exclusive of edges)
--- @param pos number Position to check
--- @param region_start number Region start time
--- @param region_end number Region end time
--- @return boolean is_inside True if position is inside (not touching edges)
local function is_inside(pos, region_start, region_end)
  return pos >= (region_start + FUDGE_FACTOR) and pos <= (region_end - FUDGE_FACTOR)
end

--- Check if one region is nested inside another
--- A region is nested if its start OR end falls inside the outer region
--- @param inner table Region to check {start, end, rid}
--- @param outer table Potential containing region {start, end, rid}
--- @return boolean is_nested True if inner is nested within outer
local function is_nested_in(inner, outer)
  if inner.rid == outer.rid then return false end

  local outer_start = outer.start
  local outer_end = outer['end']

  -- Check if inner's start or end falls within outer's boundaries
  return is_inside(inner.start, outer_start, outer_end) or
         is_inside(inner['end'], outer_start, outer_end)
end

--- Find all overlapping regions in the cache
--- @param region_cache table Map of rid -> region {rid, start, end, name, color}
--- @return table overlap_map Map of outer_rid -> {inner_rid1, inner_rid2, ...}
function M.find_overlaps(region_cache)
  local overlap_map = {}

  -- Convert cache to array for iteration
  local regions = {}
  for rid, region in pairs(region_cache) do
    regions[#regions + 1] = region
  end

  -- For each region, check if any other region is nested inside it
  for _, outer in ipairs(regions) do
    for _, inner in ipairs(regions) do
      if is_nested_in(inner, outer) then
        local outer_rid = outer.rid
        if not overlap_map[outer_rid] then
          overlap_map[outer_rid] = {}
        end
        overlap_map[outer_rid][#overlap_map[outer_rid] + 1] = inner.rid
      end
    end
  end

  return overlap_map
end

--- Check if a specific region has nested regions
--- @param rid number Region ID to check
--- @param overlap_map table Map from find_overlaps()
--- @return boolean has_nested True if region contains nested regions
function M.has_nested(rid, overlap_map)
  return overlap_map[rid] ~= nil and #overlap_map[rid] > 0
end

--- Get list of nested region IDs for a specific region
--- @param rid number Region ID
--- @param overlap_map table Map from find_overlaps()
--- @return table|nil nested_rids Array of nested region IDs, or nil if none
function M.get_nested(rid, overlap_map)
  return overlap_map[rid]
end

--- Get detailed overlap info for UI display
--- @param region_cache table Map of rid -> region
--- @param overlap_map table Map from find_overlaps()
--- @return table overlaps Array of {outer = region, inners = {region, ...}}
function M.get_overlap_details(region_cache, overlap_map)
  local details = {}

  for outer_rid, inner_rids in pairs(overlap_map) do
    local outer = region_cache[outer_rid]
    if outer then
      local inners = {}
      for _, inner_rid in ipairs(inner_rids) do
        local inner = region_cache[inner_rid]
        if inner then
          inners[#inners + 1] = inner
        end
      end

      if #inners > 0 then
        details[#details + 1] = {
          outer = outer,
          inners = inners,
        }
      end
    end
  end

  return details
end

--- Check if any regions in a playlist have overlaps
--- @param playlist table Playlist with items array
--- @param overlap_map table Map from find_overlaps()
--- @return table|nil first_overlap First overlapping region, or nil if none
function M.find_playlist_overlap(playlist, overlap_map)
  if not playlist or not playlist.items then return nil end

  for _, item in ipairs(playlist.items) do
    if item.type == 'region' and item.rid then
      if M.has_nested(item.rid, overlap_map) then
        return item
      end
    end
  end

  return nil
end

--- Count total overlapping regions
--- @param overlap_map table Map from find_overlaps()
--- @return number count Number of regions that contain nested regions
function M.count_overlapping(overlap_map)
  local count = 0
  for _ in pairs(overlap_map) do
    count = count + 1
  end
  return count
end

-- =============================================================================
-- BEYOND PROJECT END DETECTION
-- Regions that start after the project length will cause playback to stop
-- =============================================================================

--- Find regions that start beyond the project end
--- @param region_cache table Map of rid -> region {rid, start, end, name, color}
--- @param project_length number Project length in seconds
--- @return table beyond_map Map of rid -> true for regions beyond project end
function M.find_beyond_project_end(region_cache, project_length)
  local beyond_map = {}

  if not project_length or project_length < 0.1 then
    return beyond_map
  end

  for rid, region in pairs(region_cache) do
    if region.start and region.start >= project_length then
      beyond_map[rid] = true
    end
  end

  return beyond_map
end

--- Check if a region starts beyond the project end
--- @param rid number Region ID
--- @param beyond_map table Map from find_beyond_project_end()
--- @return boolean is_beyond True if region starts after project end
function M.is_beyond_project_end(rid, beyond_map)
  return beyond_map[rid] == true
end

--- Check if any regions in a playlist are beyond project end
--- @param playlist table Playlist with items array
--- @param beyond_map table Map from find_beyond_project_end()
--- @return table|nil first_beyond First beyond-end region, or nil if none
function M.find_playlist_beyond_end(playlist, beyond_map)
  if not playlist or not playlist.items then return nil end

  for _, item in ipairs(playlist.items) do
    if item.type == 'region' and item.rid then
      if M.is_beyond_project_end(item.rid, beyond_map) then
        return item
      end
    end
  end

  return nil
end

return M
