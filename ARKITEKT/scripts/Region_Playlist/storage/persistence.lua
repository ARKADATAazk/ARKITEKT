-- @noindex
-- Region_Playlist/storage/persistence.lua
-- Handles ExtState persistence for playlists and the active playlist id.

local JSON = require('rearkitekt.core.json')
local RegionState = require('Region_Playlist.storage.state')

local M = {}

local EXT_STATE_SECTION = "ReArkitekt_RegionPlaylist"
local KEY_PLAYLISTS = "playlists"
local KEY_ACTIVE = "active_playlist"

local function migrate_playlist_items(items)
  for _, item in ipairs(items) do
    if not item.type then
      item.type = "region"
    end
    if item.type == "region" and not item.reps then
      item.reps = 1
    end
    if item.enabled == nil then
      item.enabled = true
    end
  end
  return items
end

local function migrate_playlists(playlists, proj)
  local needs_save = false

  for _, pl in ipairs(playlists) do
    if pl.items then
      migrate_playlist_items(pl.items)
    end
    if not pl.chip_color then
      pl.chip_color = RegionState.generate_chip_color()
      needs_save = true
    end
  end

  if needs_save then
    M.save_playlists(playlists, proj)
  end

  return playlists
end

function M.save_playlists(playlists, proj)
  proj = proj or 0
  local json_str = JSON.encode(playlists)
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_PLAYLISTS, json_str)
end

function M.load_playlists(proj)
  proj = proj or 0
  local ok, json_str = reaper.GetProjExtState(proj, EXT_STATE_SECTION, KEY_PLAYLISTS)
  if ok ~= 1 or not json_str or json_str == "" then
    return {}
  end

  local success, playlists = pcall(JSON.decode, json_str)
  if not success then
    return {}
  end

  return migrate_playlists(playlists or {}, proj)
end

function M.save_active_playlist(playlist_id, proj)
  proj = proj or 0
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_ACTIVE, playlist_id)
end

function M.load_active_playlist(proj)
  proj = proj or 0
  local ok, playlist_id = reaper.GetProjExtState(proj, EXT_STATE_SECTION, KEY_ACTIVE)
  if ok ~= 1 or not playlist_id or playlist_id == "" then
    return nil
  end
  return playlist_id
end

return M
