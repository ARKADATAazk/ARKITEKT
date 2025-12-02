-- @noindex
-- RegionPlaylist/data/persistence.lua
-- Region Playlist state persistence via Project ExtState
-- REFACTORED: Now uses arkitekt.reaper.project_state module

local ProjectState = require('arkitekt.reaper.project_state')
local Logger = require('arkitekt.debug.logger')
local Ark = require('arkitekt')
local M = {}

local EXT_STATE_SECTION = 'ARK_REGIONPLAYLIST'
local KEY_PLAYLISTS = 'playlists'
local KEY_ACTIVE = 'active_playlist'
local KEY_SETTINGS = 'settings'

-- Cache storage instances per project to avoid repeated creation
local storage_cache = {}

local function get_storage(proj)
  proj = proj or 0
  if not storage_cache[proj] then
    storage_cache[proj] = ProjectState.new(EXT_STATE_SECTION, proj)
  end
  return storage_cache[proj]
end

function M.save_playlists(playlists, proj)
  Logger.info('STORAGE', 'Saving %d playlists to project', #playlists)
  get_storage(proj):save(KEY_PLAYLISTS, playlists)
end

function M.load_playlists(proj)
  local playlists = get_storage(proj):load(KEY_PLAYLISTS, {})
  Logger.info('STORAGE', 'Loaded %d playlists from project', #playlists)
  return playlists
end

function M.save_active_playlist(playlist_id, proj)
  -- Active playlist is stored as plain string, not JSON
  proj = proj or 0
  reaper.SetProjExtState(proj, EXT_STATE_SECTION, KEY_ACTIVE, playlist_id)
end

function M.load_active_playlist(proj)
  proj = proj or 0
  local ok, playlist_id = reaper.GetProjExtState(proj, EXT_STATE_SECTION, KEY_ACTIVE)
  if ok ~= 1 or not playlist_id or playlist_id == '' then
    return nil
  end
  return playlist_id
end

function M.save_settings(settings, proj)
  get_storage(proj):save(KEY_SETTINGS, settings)
end

function M.load_settings(proj)
  return get_storage(proj):load(KEY_SETTINGS, {})
end

function M.clear_all(proj)
  proj = proj or 0
  local storage = get_storage(proj)
  storage:delete(KEY_PLAYLISTS)
  storage:delete(KEY_ACTIVE)
  storage:delete(KEY_SETTINGS)
end

function M.get_or_create_default_playlist(playlists, regions)
  if #playlists > 0 then
    return playlists
  end

  local default_items = {}
  for i, region in ipairs(regions) do
    default_items[#default_items + 1] = {
      type = 'region',
      rid = i,
      reps = 1,
      enabled = true,
      key = Ark.UUID.generate(),
    }
  end

  return {
    {
      id = Ark.UUID.generate(),
      name = 'Playlist 1',
      items = default_items,
      chip_color = M.generate_chip_color(),
    }
  }
end

--- REFACTORED FUNCTION ---
function M.generate_chip_color()
  local hue = math.random()
  local saturation = 0.65 + math.random() * 0.25
  local lightness = 0.50 + math.random() * 0.15
  
  local r, g, b = Ark.Colors.hsl_to_rgb(hue, saturation, lightness)
  return Ark.Colors.components_to_rgba(r, g, b, 0xFF)
end

return M