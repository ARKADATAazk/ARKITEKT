-- @noindex
-- Blocks/blocks/item_browser/storage.lua
-- Reads/writes ItemPicker's REAPER Project ExtState directly
-- Simple approach: always use ExtState (ItemPicker persists immediately on toggle)

local M = {}

local JSON = require('arkitekt.core.json')

-- ItemPicker's ExtState namespace
local EXTNAME = 'ARK_ItemPicker'

-- ============================================================================
-- FAVORITES
-- ============================================================================

---Load favorites from ExtState
---@return table { audio = { [filename] = true }, midi = { [item_name] = true } }
function M.load_favorites()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'favorites')

  if not has_state or has_state == 0 or state_str == '' then
    return { audio = {}, midi = {} }
  end

  local favorites = JSON.decode(state_str)
  if not favorites or type(favorites) ~= 'table' then
    return { audio = {}, midi = {} }
  end

  -- Ensure both tables exist
  favorites.audio = favorites.audio or {}
  favorites.midi = favorites.midi or {}

  return favorites
end

---Save favorites to ExtState
---@param favorites table Favorites table
function M.save_favorites(favorites)
  if not favorites then return end

  local serialized = JSON.encode(favorites)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'favorites', serialized)
  end
end

---Check if an audio item is a favorite
---@param filename string Audio source filename
---@return boolean
function M.is_audio_favorite(filename)
  local favorites = M.load_favorites()
  return favorites.audio[filename] == true
end

---Check if a MIDI item is a favorite (by item/take name)
---@param item_name string MIDI item/take name
---@return boolean
function M.is_midi_favorite(item_name)
  local favorites = M.load_favorites()
  return favorites.midi[item_name] == true
end

---Toggle audio favorite status
---@param filename string Audio source filename
---@return boolean New favorite state
function M.toggle_audio_favorite(filename)
  local favorites = M.load_favorites()

  if favorites.audio[filename] then
    favorites.audio[filename] = nil
  else
    favorites.audio[filename] = true
  end

  M.save_favorites(favorites)
  return favorites.audio[filename] == true
end

---Toggle MIDI favorite status (by item/take name)
---@param item_name string MIDI item/take name
---@return boolean New favorite state
function M.toggle_midi_favorite(item_name)
  local favorites = M.load_favorites()

  if favorites.midi[item_name] then
    favorites.midi[item_name] = nil
  else
    favorites.midi[item_name] = true
  end

  M.save_favorites(favorites)
  return favorites.midi[item_name] == true
end

-- ============================================================================
-- SETTINGS
-- ============================================================================

---Load settings from ExtState
---@return table Settings table
function M.load_settings()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'settings')

  if not has_state or has_state == 0 or state_str == '' then
    return { show_favorites_only = false }
  end

  local settings = JSON.decode(state_str)
  if not settings or type(settings) ~= 'table' then
    return { show_favorites_only = false }
  end

  return settings
end

---Get a single setting
---@param key string Setting key
---@return any Setting value
function M.get_setting(key)
  local settings = M.load_settings()
  return settings[key]
end

---Set a single setting
---@param key string Setting key
---@param value any Setting value
function M.set_setting(key, value)
  local settings = M.load_settings()
  settings[key] = value

  local serialized = JSON.encode(settings)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'settings', serialized)
  end
end

return M
