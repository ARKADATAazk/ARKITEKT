-- @noindex
-- RegionPlaylist/domains/playlist.lua
-- Manages playlist data, active playlist, and playlist operations

local M = {}

--- Create a new playlist domain
--- @return table domain The playlist domain instance
function M.new()
  local domain = {
    playlists = {},          -- Array of playlist objects
    playlist_lookup = {},    -- Map: UUID -> playlist object (O(1) lookup)
    active_playlist = nil,   -- Currently active/selected playlist ID
  }

  reaper.ShowConsoleMsg("[PLAYLIST] Domain initialized\n")

  --- Rebuild lookup index from playlists array
  local function rebuild_lookup()
    domain.playlist_lookup = {}
    for _, pl in ipairs(domain.playlists) do
      domain.playlist_lookup[pl.id] = pl
    end
  end

  --- Load playlists from array
  --- @param playlists table Array of playlist objects
  function domain:load_playlists(playlists)
    self.playlists = playlists or {}
    rebuild_lookup()
    reaper.ShowConsoleMsg(string.format("[PLAYLIST] Loaded %d playlists\n", #self.playlists))
  end

  --- Get all playlists
  --- @return table playlists Array of playlist objects
  function domain:get_all()
    return self.playlists
  end

  --- Get playlist by ID
  --- @param playlist_id string Playlist UUID
  --- @return table|nil playlist Playlist object or nil
  function domain:get_by_id(playlist_id)
    return self.playlist_lookup[playlist_id]
  end

  --- Get active playlist ID
  --- @return string|nil active_id Active playlist UUID
  function domain:get_active_id()
    return self.active_playlist
  end

  --- Get active playlist object
  --- @return table|nil playlist Active playlist object, or first playlist if not found
  function domain:get_active()
    local pl = self.playlist_lookup[self.active_playlist]
    if pl then
      return pl
    end
    -- Fallback to first playlist
    return self.playlists[1]
  end

  --- Set active playlist
  --- @param playlist_id string Playlist UUID to make active
  function domain:set_active(playlist_id)
    self.active_playlist = playlist_id
    reaper.ShowConsoleMsg(string.format("[PLAYLIST] Active playlist: %s\n", playlist_id or "nil"))
  end

  --- Move playlist to front (position 1)
  --- @param playlist_id string Playlist UUID to move
  function domain:move_to_front(playlist_id)
    local playlist_index = nil
    for i, pl in ipairs(self.playlists) do
      if pl.id == playlist_id then
        playlist_index = i
        break
      end
    end

    if not playlist_index then return end

    if playlist_index ~= 1 then
      local playlist = table.remove(self.playlists, playlist_index)
      table.insert(self.playlists, 1, playlist)
      rebuild_lookup()
      reaper.ShowConsoleMsg(string.format("[PLAYLIST] Moved to front: %s\n", playlist_id))
    end
  end

  --- Reorder playlists by array of IDs
  --- @param new_playlist_ids table Array of playlist UUIDs in new order
  function domain:reorder_by_ids(new_playlist_ids)
    -- Build a map of playlists by ID
    local playlist_map = {}
    for _, pl in ipairs(self.playlists) do
      playlist_map[pl.id] = pl
    end

    -- Rebuild playlists array in new order
    local reordered = {}
    for _, id in ipairs(new_playlist_ids) do
      local pl = playlist_map[id]
      if pl then
        reordered[#reordered + 1] = pl
        playlist_map[id] = nil  -- Mark as used
      end
    end

    -- Append any playlists not in the reorder list (defensive)
    for _, pl in pairs(playlist_map) do
      reordered[#reordered + 1] = pl
    end

    self.playlists = reordered
    rebuild_lookup()
    reaper.ShowConsoleMsg(string.format("[PLAYLIST] Reordered: %d playlists\n", #reordered))
  end

  --- Get tabs for UI display
  --- @return table tabs Array of {id, label, chip_color}
  function domain:get_tabs()
    local tabs = {}
    for _, pl in ipairs(self.playlists) do
      tabs[#tabs + 1] = {
        id = pl.id,
        label = pl.name or "Untitled",
        chip_color = pl.chip_color,
      }
    end
    return tabs
  end

  --- Count playlist contents (regions and nested playlists)
  --- @param playlist_id string Playlist UUID
  --- @return number region_count Number of regions
  --- @return number playlist_count Number of nested playlists
  function domain:count_contents(playlist_id)
    local playlist = self:get_by_id(playlist_id)
    if not playlist or not playlist.items then
      return 0, 0
    end

    local region_count = 0
    local playlist_count = 0

    for _, item in ipairs(playlist.items) do
      if item.type == "region" then
        region_count = region_count + 1
      elseif item.type == "playlist" then
        playlist_count = playlist_count + 1
      end
    end

    return region_count, playlist_count
  end

  --- Notify that playlists changed (rebuilds lookup)
  function domain:mark_changed()
    rebuild_lookup()
  end

  --- Count total playlists
  --- @return number count Number of playlists
  function domain:count()
    return #self.playlists
  end

  return domain
end

return M
