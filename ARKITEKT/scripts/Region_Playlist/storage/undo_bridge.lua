-- @noindex
-- ReArkitekt/features/region_playlist/undo_bridge.lua
-- Bridge between undo manager and playlist state

local M = {}

function M.capture_snapshot(playlists, active_playlist_id)
  local Regions = require('rearkitekt.reaper.regions')

  local snapshot = {
    playlists = {},
    active_playlist = active_playlist_id,
    regions = {},  -- Capture region state (name, color)
    timestamp = os.time(),
  }

  -- Collect all unique region IDs referenced in playlists
  local region_rids = {}
  for _, pl in ipairs(playlists) do
    for _, item in ipairs(pl.items) do
      if item.type == "region" and item.rid then
        region_rids[item.rid] = true
      end
    end
  end

  -- Snapshot region properties (name, color)
  for rid in pairs(region_rids) do
    local region = Regions.get_region_by_rid(0, rid)
    if region then
      snapshot.regions[rid] = {
        name = region.name,
        color = region.color,
      }
    end
  end

  for _, pl in ipairs(playlists) do
    local pl_copy = {
      id = pl.id,
      name = pl.name,
      chip_color = pl.chip_color,
      items = {},
    }

    for _, item in ipairs(pl.items) do
      local item_copy = {
        type = item.type,
        rid = item.rid,
        reps = item.reps,
        enabled = item.enabled,
        key = item.key,
      }
      -- Save playlist_id for playlist items
      if item.type == "playlist" then
        item_copy.playlist_id = item.playlist_id
      end
      pl_copy.items[#pl_copy.items + 1] = item_copy
    end

    snapshot.playlists[#snapshot.playlists + 1] = pl_copy
  end

  return snapshot
end

function M.restore_snapshot(snapshot, region_index)
  local Regions = require('rearkitekt.reaper.regions')
  local restored_playlists = {}

  -- Track what was changed for status reporting
  local changes = {
    regions_renamed = 0,
    regions_recolored = 0,
    playlists_count = 0,
    items_count = 0,
  }

  -- Restore region properties (name, color) if snapshot contains region data
  -- Use raw versions to avoid creating REAPER undo points (we have our own undo system)
  if snapshot.regions then
    for rid, region_data in pairs(snapshot.regions) do
      local current_region = Regions.get_region_by_rid(0, rid)
      if current_region then
        -- Only restore if properties have changed
        if current_region.name ~= region_data.name then
          Regions.set_region_name_raw(0, rid, region_data.name)
          changes.regions_renamed = changes.regions_renamed + 1
        end
        if current_region.color ~= region_data.color then
          Regions.set_region_color_raw(0, rid, region_data.color)
          changes.regions_recolored = changes.regions_recolored + 1
        end
      end
    end

    -- Force UI update after all region changes
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(false)
  end

  for _, pl in ipairs(snapshot.playlists) do
    local pl_copy = {
      id = pl.id,
      name = pl.name,
      chip_color = pl.chip_color,
      items = {},
    }

    for _, item in ipairs(pl.items) do
      -- For region items, verify the region still exists
      -- For playlist items, always restore them
      if item.type == "playlist" or region_index[item.rid] then
        local item_copy = {
          type = item.type,
          rid = item.rid,
          reps = item.reps,
          enabled = item.enabled,
          key = item.key,
        }
        -- Restore playlist_id for playlist items
        if item.type == "playlist" then
          item_copy.playlist_id = item.playlist_id
        end
        pl_copy.items[#pl_copy.items + 1] = item_copy
        changes.items_count = changes.items_count + 1
      end
    end

    restored_playlists[#restored_playlists + 1] = pl_copy
    changes.playlists_count = changes.playlists_count + 1
  end

  return restored_playlists, snapshot.active_playlist, changes
end

function M.should_capture(old_playlists, new_playlists)
  if #old_playlists ~= #new_playlists then
    return true
  end

  for i, old_pl in ipairs(old_playlists) do
    local new_pl = new_playlists[i]
    if not new_pl or
       old_pl.id ~= new_pl.id or
       old_pl.name ~= new_pl.name or
       old_pl.chip_color ~= new_pl.chip_color then
      return true
    end

    if #old_pl.items ~= #new_pl.items then
      return true
    end

    for j, old_item in ipairs(old_pl.items) do
      local new_item = new_pl.items[j]
      if not new_item or
         old_item.type ~= new_item.type or
         old_item.rid ~= new_item.rid or
         old_item.reps ~= new_item.reps or
         old_item.enabled ~= new_item.enabled or
         old_item.playlist_id ~= new_item.playlist_id then
        return true
      end
    end
  end

  return false
end

return M