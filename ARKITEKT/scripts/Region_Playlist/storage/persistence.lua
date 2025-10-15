-- @noindex
-- Region_Playlist/storage/persistence.lua
-- Project ExtState persistence helpers for Region Playlist data.

local JSON = require('rearkitekt.core.json')

local M = {}

local EXT_STATE_SECTION = 'ReArkitekt_RegionPlaylist'
local KEY_PLAYLISTS = 'playlists'
local KEY_ACTIVE = 'active_playlist'

local function coerce_project(proj)
  if proj == nil then
    return 0
  end
  return proj
end

local function encode_playlists(playlists)
  local ok, payload = pcall(JSON.encode, playlists or {})
  if ok and type(payload) == 'string' then
    return payload
  end
  return '[]'
end

local function decode_playlists(payload)
  if not payload or payload == '' then
    return {}
  end
  local ok, decoded = pcall(JSON.decode, payload)
  if not ok or type(decoded) ~= 'table' then
    return {}
  end
  return decoded
end

function M.save_playlists(playlists, proj)
  local project = coerce_project(proj)
  local payload = encode_playlists(playlists)
  reaper.SetProjExtState(project, EXT_STATE_SECTION, KEY_PLAYLISTS, payload)
end

function M.load_playlists(proj)
  local project = coerce_project(proj)
  local ok, payload = reaper.GetProjExtState(project, EXT_STATE_SECTION, KEY_PLAYLISTS)
  if ok ~= 1 then
    return {}
  end
  return decode_playlists(payload)
end

-- @deprecated TEMP_PARITY_SHIM: save_active_playlist() → prefer storage.state.save_active_playlist
-- EXPIRES: 2025-12-31 (planned removal: Phase-7)
-- reason: app/state still persists active playlist via persistence.lua during migration.
function M.save_active_playlist(playlist_id, proj)
  local project = coerce_project(proj)
  reaper.SetProjExtState(project, EXT_STATE_SECTION, KEY_ACTIVE, playlist_id or '')
end

-- @deprecated TEMP_PARITY_SHIM: load_active_playlist() → prefer storage.state.load_active_playlist
-- EXPIRES: 2025-12-31 (planned removal: Phase-7)
-- reason: app/state still reads active playlist via persistence.lua during migration.
function M.load_active_playlist(proj)
  local project = coerce_project(proj)
  local ok, playlist_id = reaper.GetProjExtState(project, EXT_STATE_SECTION, KEY_ACTIVE)
  if ok ~= 1 or not playlist_id or playlist_id == '' then
    return nil
  end
  return playlist_id
end

return M
