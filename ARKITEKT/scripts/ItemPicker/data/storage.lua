-- @noindex
-- ItemPicker/data/storage.lua
-- Settings persistence using REAPER project extended state
-- @migrated 2024-11-27 from data/persistence.lua

local M = {}
local JSON = require('arkitekt.core.json')

local EXTNAME = 'ARK_ItemPicker'
local SETTINGS_KEY = 'settings'

-- Default settings
local function get_default_settings()
  return {
    play_item_through_track = false,
    show_muted_tracks = false,
    show_muted_items = false,
    show_disabled_items = false,
    show_favorites_only = false,
    pin_favorites_to_top = false,
    show_audio = true,
    show_midi = true,
    focus_keyboard_on_init = true,
    search_string = '',
    tile_width = nil,  -- nil = use config default
    tile_height = nil,  -- nil = use config default
    split_midi_by_track = false,
    group_items_by_name = true,
    separator_position = nil,
    separator_position_horizontal = nil,
    sort_mode = 'track',
    sort_reverse = false,
    waveform_quality = 0.2,
    layout_mode = 'vertical',
    enable_region_processing = false,  -- Enable region detection and filtering
    show_region_tags = false,  -- Show region tags on item tiles (only if processing enabled)
    search_mode = 'items',  -- Search mode: 'items', 'tracks', 'regions', 'mixed'
  }
end

function M.load_settings()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, SETTINGS_KEY)

  if not has_state or has_state == 0 or state_str == '' then
    return get_default_settings()
  end

  -- SECURITY FIX: Use safe JSON.decode instead of unsafe load()
  local settings = JSON.decode(state_str)
  if not settings or type(settings) ~= 'table' then
    return get_default_settings()
  end

  -- Merge with defaults to handle new settings added
  local defaults = get_default_settings()
  for k, v in pairs(defaults) do
    if settings[k] == nil then
      settings[k] = v
    end
  end

  return settings
end

function M.save_settings(settings)
  if not settings then return end

  -- SECURITY FIX: Use safe JSON.encode instead of custom serialization
  local serialized = JSON.encode(settings)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, SETTINGS_KEY, serialized)
  end
end

-- Disabled items persistence
function M.load_disabled_items()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'disabled_items')

  if not has_state or has_state == 0 or state_str == '' then
    return { audio = {}, midi = {} }
  end

  -- SECURITY FIX: Use safe JSON.decode instead of unsafe load()
  local disabled = JSON.decode(state_str)
  if not disabled or type(disabled) ~= 'table' then
    return { audio = {}, midi = {} }
  end

  return disabled
end

function M.save_disabled_items(disabled)
  if not disabled then return end

  -- SECURITY FIX: Use safe JSON.encode instead of custom serialization
  local serialized = JSON.encode(disabled)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'disabled_items', serialized)
  end
end

-- Favorites persistence
function M.load_favorites()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'favorites')

  if not has_state or has_state == 0 or state_str == '' then
    return { audio = {}, midi = {} }
  end

  -- SECURITY FIX: Use safe JSON.decode instead of unsafe load()
  local favorites = JSON.decode(state_str)
  if not favorites or type(favorites) ~= 'table' then
    return { audio = {}, midi = {} }
  end

  return favorites
end

function M.save_favorites(favorites)
  if not favorites then return end

  -- SECURITY FIX: Use safe JSON.encode instead of custom serialization
  local serialized = JSON.encode(favorites)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'favorites', serialized)
  end
end

-- Track filter persistence
function M.load_track_filter()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'track_filter')

  if not has_state or has_state == 0 or state_str == '' then
    return { whitelist = nil, enabled = nil }
  end

  -- SECURITY FIX: Use safe JSON.decode instead of unsafe load()
  local filter = JSON.decode(state_str)
  if not filter or type(filter) ~= 'table' then
    return { whitelist = nil, enabled = nil }
  end

  return filter
end

function M.save_track_filter(whitelist, enabled)
  -- SECURITY FIX: Use safe JSON.encode instead of custom serialization
  local filter_data = {
    whitelist = whitelist,
    enabled = enabled
  }
  local serialized = JSON.encode(filter_data)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'track_filter', serialized)
  end
end

-- Item usage persistence (for "recent" sort)
function M.load_item_usage()
  local has_state, state_str = reaper.GetProjExtState(0, EXTNAME, 'item_usage')

  if not has_state or has_state == 0 or state_str == '' then
    return {}
  end

  local usage = JSON.decode(state_str)
  if not usage or type(usage) ~= 'table' then
    return {}
  end

  return usage
end

function M.save_item_usage(usage)
  if not usage then return end

  local serialized = JSON.encode(usage)
  if serialized then
    reaper.SetProjExtState(0, EXTNAME, 'item_usage', serialized)
  end
end

return M
