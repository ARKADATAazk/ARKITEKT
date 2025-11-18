-- @noindex
-- ReArkitekt/features/region_playlist/undo_bridge.lua
-- Bridge between undo manager and playlist state

local M = {}

function M.capture_snapshot(playlists, active_playlist_id)
  local snapshot = {
    playlists = {},
    active_playlist = active_playlist_id,
    timestamp = os.time(),
  }
  
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
  local restored_playlists = {}
  
  for _, pl in ipairs(snapshot.playlists) do
    local pl_copy = {
      id = pl.id,
      name = pl.name,
      chip_color = pl.chip_color,  -- Will be nil for old snapshots, which is fine
      items = {},
    }

    for _, item in ipairs(pl.items) do
      -- Infer type from presence of fields for backward compatibility
      local item_type = item.type or (item.playlist_id and "playlist" or "region")

      -- For region items, verify the region still exists
      -- For playlist items, always restore them
      if item_type == "playlist" or region_index[item.rid] then
        local item_copy = {
          type = item_type,
          rid = item.rid,
          reps = item.reps or 1,
          enabled = item.enabled ~= false,  -- Default to true if missing
          key = item.key,
        }
        -- Restore playlist_id for playlist items
        if item_type == "playlist" then
          item_copy.playlist_id = item.playlist_id
        end
        pl_copy.items[#pl_copy.items + 1] = item_copy
      end
    end

    restored_playlists[#restored_playlists + 1] = pl_copy
  end
  
  return restored_playlists, snapshot.active_playlist
end

function M.should_capture(old_playlists, new_playlists)
  if #old_playlists ~= #new_playlists then
    return true
  end

  for i, old_pl in ipairs(old_playlists) do
    local new_pl = new_playlists[i]
    if not new_pl or old_pl.id ~= new_pl.id then
      return true
    end

    -- Compare playlist properties (handle nil gracefully)
    if (old_pl.name or "") ~= (new_pl.name or "") or
       (old_pl.chip_color or 0) ~= (new_pl.chip_color or 0) then
      return true
    end

    if #old_pl.items ~= #new_pl.items then
      return true
    end

    for j, old_item in ipairs(old_pl.items) do
      local new_item = new_pl.items[j]
      if not new_item then
        return true
      end

      -- Compare item properties (handle nil gracefully)
      local old_type = old_item.type or (old_item.playlist_id and "playlist" or "region")
      local new_type = new_item.type or (new_item.playlist_id and "playlist" or "region")

      if old_type ~= new_type or
         (old_item.rid or 0) ~= (new_item.rid or 0) or
         (old_item.reps or 1) ~= (new_item.reps or 1) or
         (old_item.enabled ~= false) ~= (new_item.enabled ~= false) or
         (old_item.playlist_id or "") ~= (new_item.playlist_id or "") then
        return true
      end
    end
  end

  return false
end

return M