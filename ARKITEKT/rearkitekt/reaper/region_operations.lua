-- @noindex
-- ReArkitekt/reaper/region_operations.lua
-- Region playlist operations (Append, Paste, Crop, etc.)

local M = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function get_project_length(proj)
  proj = proj or 0
  local length = 0

  for i = 0, reaper.CountTracks(proj) - 1 do
    local track = reaper.GetTrack(proj, i)
    for j = 0, reaper.CountTrackMediaItems(track) - 1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local item_end = reaper.GetMediaItemInfo_Value(item, "D_POSITION") +
                      reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      if item_end > length then
        length = item_end
      end
    end
  end

  return length
end

local function copy_region_content(proj, region_start, region_end, target_position)
  proj = proj or 0
  local new_items = {}
  local time_offset = target_position - region_start

  -- Copy all items in the region
  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item = reaper.GetMediaItem(proj, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_pos + item_length
    local track = reaper.GetMediaItem_Track(item)

    -- Check if item overlaps with region
    if item_pos < region_end and item_end > region_start then
      -- Calculate the portion of the item that's in the region
      local copy_start = math.max(item_pos, region_start)
      local copy_end = math.min(item_end, region_end)
      local copy_length = copy_end - copy_start

      -- Create new item
      local new_item = reaper.AddMediaItemToTrack(track)

      -- Copy item state chunk
      local chunk_success, item_chunk = reaper.GetItemStateChunk(item, "", false)
      if chunk_success then
        local new_pos = copy_start + time_offset

        -- Get the take offset if item starts before region
        local take_offset = 0
        if item_pos < region_start then
          take_offset = region_start - item_pos
        end

        -- Set new item chunk
        reaper.SetItemStateChunk(new_item, item_chunk, false)

        -- Set position and length
        reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", new_pos)
        reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", copy_length)

        -- Adjust take offset
        local take = reaper.GetActiveTake(new_item)
        if take then
          local current_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
          reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", current_offset + take_offset)
        end

        table.insert(new_items, new_item)
      end
    end
  end

  -- Copy automation envelopes
  for i = 0, reaper.CountTracks(proj) - 1 do
    local track = reaper.GetTrack(proj, i)
    for j = 0, reaper.CountTrackEnvelopes(track) - 1 do
      local envelope = reaper.GetTrackEnvelope(track, j)

      -- Get all envelope points in region
      local num_points = reaper.CountEnvelopePoints(envelope)
      local points_to_copy = {}

      for k = 0, num_points - 1 do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, k)
        if time >= region_start and time <= region_end then
          table.insert(points_to_copy, {
            time = time + time_offset,
            value = value,
            shape = shape,
            tension = tension
          })
        end
      end

      -- Insert copied points
      for _, point in ipairs(points_to_copy) do
        reaper.InsertEnvelopePoint(envelope, point.time, point.value, point.shape, point.tension, false, true)
      end
    end
  end

  -- Copy tempo markers
  local tempo_count = reaper.CountTempoTimeSigMarkers(proj)
  for i = 0, tempo_count - 1 do
    local retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo =
      reaper.GetTempoTimeSigMarker(proj, i)

    if timepos >= region_start and timepos <= region_end then
      local new_time = timepos + time_offset
      reaper.SetTempoTimeSigMarker(proj, -1, new_time, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo)
    end
  end

  return new_items
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Append selected regions to the end of the project
--- @param rids table Array of region IDs to append
--- @return boolean success
function M.append_regions_to_project(rids)
  reaper.ShowConsoleMsg("[RegionOps] append_regions_to_project called with " .. tostring(#rids or 0) .. " RIDs\n")

  if not rids or #rids == 0 then
    reaper.ShowConsoleMsg("[RegionOps] No RIDs provided, returning false\n")
    return false
  end

  local proj = 0
  local Regions = require('rearkitekt.reaper.regions')

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  -- Get current project end
  local project_end = get_project_length(proj)
  reaper.ShowConsoleMsg("[RegionOps] Project end position: " .. tostring(project_end) .. "\n")
  local current_position = project_end
  local gap = 0

  -- Get region data and sort by position
  local regions_data = {}
  for _, rid in ipairs(rids) do
    reaper.ShowConsoleMsg("[RegionOps] Looking up region with RID: " .. tostring(rid) .. "\n")
    local region = Regions.get_region_by_rid(proj, rid)
    if region then
      reaper.ShowConsoleMsg("[RegionOps] Found region: " .. tostring(region.name) .. " (" .. tostring(region.start) .. " - " .. tostring(region["end"]) .. ")\n")
      table.insert(regions_data, region)
    else
      reaper.ShowConsoleMsg("[RegionOps] Region not found for RID: " .. tostring(rid) .. "\n")
    end
  end

  -- Sort by start position
  table.sort(regions_data, function(a, b) return a.start < b.start end)
  reaper.ShowConsoleMsg("[RegionOps] Copying " .. #regions_data .. " regions\n")

  -- Copy each region to the end
  for _, region in ipairs(regions_data) do
    reaper.ShowConsoleMsg("[RegionOps] Copying region to position " .. tostring(current_position) .. "\n")
    copy_region_content(proj, region.start, region["end"], current_position)
    current_position = current_position + (region["end"] - region.start) + gap
  end

  reaper.Undo_EndBlock("Append regions to project", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  reaper.ShowConsoleMsg("[RegionOps] append_regions_to_project completed successfully\n")
  return true
end

--- Paste selected regions at edit cursor
--- @param rids table Array of region IDs to paste
--- @return boolean success
function M.paste_regions_at_cursor(rids)
  if not rids or #rids == 0 then
    return false
  end

  local proj = 0
  local Regions = require('rearkitekt.reaper.regions')

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  -- Get edit cursor position
  local cursor_pos = reaper.GetCursorPosition()
  local current_position = cursor_pos
  local gap = 0

  -- Get region data and sort by position
  local regions_data = {}
  for _, rid in ipairs(rids) do
    local region = Regions.get_region_by_rid(proj, rid)
    if region then
      table.insert(regions_data, region)
    end
  end

  -- Sort by start position
  table.sort(regions_data, function(a, b) return a.start < b.start end)

  -- Copy each region to cursor
  for _, region in ipairs(regions_data) do
    copy_region_content(proj, region.start, region["end"], current_position)
    current_position = current_position + (region["end"] - region.start) + gap
  end

  reaper.Undo_EndBlock("Paste regions at cursor", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  return true
end

--- Crop project to selected regions (delete everything outside)
--- @param rids table Array of region IDs to keep
--- @return boolean success
function M.crop_to_regions(rids)
  reaper.ShowConsoleMsg("[RegionOps] crop_to_regions called with " .. tostring(#rids or 0) .. " RIDs\n")

  if not rids or #rids == 0 then
    reaper.ShowConsoleMsg("[RegionOps] No RIDs provided, returning false\n")
    return false
  end

  local proj = 0
  local Regions = require('rearkitekt.reaper.regions')

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  -- Get region data
  local keep_ranges = {}
  for _, rid in ipairs(rids) do
    local region = Regions.get_region_by_rid(proj, rid)
    if region then
      table.insert(keep_ranges, {start = region.start, rgnend = region["end"]})
    end
  end

  -- Delete all items outside the keep ranges
  local items_to_delete = {}

  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item = reaper.GetMediaItem(proj, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    local should_keep = false

    -- Check if item overlaps with any keep range
    for _, range in ipairs(keep_ranges) do
      if item_pos < range.rgnend and item_end > range.start then
        should_keep = true

        -- Trim item if it extends beyond range
        if item_pos < range.start then
          local trim_amount = range.start - item_pos
          reaper.SetMediaItemInfo_Value(item, "D_POSITION", range.start)
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH",
            reaper.GetMediaItemInfo_Value(item, "D_LENGTH") - trim_amount)

          -- Adjust take offset
          local take = reaper.GetActiveTake(item)
          if take then
            local offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offset + trim_amount)
          end

          item_pos = range.start
          item_end = item_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        end

        if item_end > range.rgnend then
          local new_length = range.rgnend - item_pos
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_length)
        end

        break
      end
    end

    if not should_keep then
      table.insert(items_to_delete, item)
    end
  end

  -- Delete items outside ranges
  for _, item in ipairs(items_to_delete) do
    reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
  end

  -- Delete automation points outside ranges
  for i = 0, reaper.CountTracks(proj) - 1 do
    local track = reaper.GetTrack(proj, i)
    for j = 0, reaper.CountTrackEnvelopes(track) - 1 do
      local envelope = reaper.GetTrackEnvelope(track, j)
      local num_points = reaper.CountEnvelopePoints(envelope)

      -- Delete points from end to start to avoid index issues
      for k = num_points - 1, 0, -1 do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, k)

        local in_range = false
        for _, range in ipairs(keep_ranges) do
          if time >= range.start and time <= range.rgnend then
            in_range = true
            break
          end
        end

        if not in_range then
          reaper.DeleteEnvelopePoint(envelope, k)
        end
      end
    end
  end

  reaper.Undo_EndBlock("Crop project to playlist", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  return true
end

--- Crop project to regions in a new project tab
--- @param rids table Array of region IDs to keep
--- @return boolean success
function M.crop_to_regions_new_tab(rids)
  if not rids or #rids == 0 then
    return false
  end

  -- Create new project tab
  reaper.Main_OnCommand(40859, 0) -- New project tab

  -- For now, just crop in the new project (full implementation would require cross-project copying)
  return M.crop_to_regions(rids)
end

--- Append ALL regions to the end of the project
--- @return boolean success
function M.append_all_regions_to_project()
  local proj = 0
  local Regions = require('rearkitekt.reaper.regions')

  -- Get all regions
  local all_regions = Regions.scan_project_regions(proj)
  if #all_regions == 0 then
    return false
  end

  -- Extract RIDs
  local rids = {}
  for _, region in ipairs(all_regions) do
    table.insert(rids, region.rid)
  end

  return M.append_regions_to_project(rids)
end

--- Paste ALL regions at edit cursor
--- @return boolean success
function M.paste_all_regions_at_cursor()
  local proj = 0
  local Regions = require('rearkitekt.reaper.regions')

  -- Get all regions
  local all_regions = Regions.scan_project_regions(proj)
  if #all_regions == 0 then
    return false
  end

  -- Extract RIDs
  local rids = {}
  for _, region in ipairs(all_regions) do
    table.insert(rids, region.rid)
  end

  return M.paste_regions_at_cursor(rids)
end

return M
