-- @noindex
-- ItemPicker/data/layout_cache.lua
-- Instant layout cache using Project ExtState
-- Stores group names, colors, and counts for instant visual on launch

local M = {}
local JSON = require('arkitekt.core.json')

local EXTSTATE_SECTION = 'ItemPicker'
local EXTSTATE_KEY = 'layout_cache_v1'

-- Save current layout to Project ExtState
function M.save(state)
  if not state then return false end

  local cache = {
    audio_groups = {},
    midi_groups = {},
    timestamp = os.time(),
  }

  -- Cache audio groups
  if state.samples and state.sample_indexes then
    for _, filename in ipairs(state.sample_indexes) do
      local items = state.samples[filename]
      if items and #items > 0 then
        -- Get color from first item in group
        local color = items[1].track_color or 0x808080FF
        cache.audio_groups[filename] = {
          count = #items,
          color = color,
        }
      end
    end
  end

  -- Cache MIDI groups
  if state.midi_items and state.midi_indexes then
    for _, group_key in ipairs(state.midi_indexes) do
      local items = state.midi_items[group_key]
      if items and #items > 0 then
        local color = items[1].track_color or 0x808080FF
        cache.midi_groups[group_key] = {
          count = #items,
          color = color,
        }
      end
    end
  end

  local cache_str = JSON.encode(cache)
  if cache_str then
    reaper.SetProjExtState(0, EXTSTATE_SECTION, EXTSTATE_KEY, cache_str)
    return true
  end

  return false
end

-- Load cached layout from Project ExtState
-- Returns: cache table or nil
function M.load()
  local _, cache_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, EXTSTATE_KEY)

  if not cache_str or cache_str == '' then
    return nil
  end

  local ok, cache = pcall(JSON.decode, cache_str)
  if not ok or not cache then
    return nil
  end

  return cache
end

-- Build fake state from cache for instant display
-- Returns: samples, sample_indexes, midi_items, midi_indexes
function M.build_fake_state(cache)
  if not cache then
    return {}, {}, {}, {}
  end

  local samples = {}
  local sample_indexes = {}
  local midi_items = {}
  local midi_indexes = {}

  -- Build fake audio groups
  if cache.audio_groups then
    for filename, data in pairs(cache.audio_groups) do
      sample_indexes[#sample_indexes + 1] = filename
      samples[filename] = {}

      -- Create placeholder items (just enough for tile count)
      for i = 1, (data.count or 1) do
        samples[filename][i] = {
          nil,  -- No real item pointer
          filename,  -- Display name
          track_color = data.color,
          track_muted = false,
          item_muted = false,
          uuid = 'fake_' .. filename .. '_' .. i,
          _is_placeholder = true,  -- Mark as fake
        }
      end
    end
  end

  -- Build fake MIDI groups
  if cache.midi_groups then
    for group_key, data in pairs(cache.midi_groups) do
      midi_indexes[#midi_indexes + 1] = group_key
      midi_items[group_key] = {}

      for i = 1, (data.count or 1) do
        midi_items[group_key][i] = {
          nil,
          group_key,
          track_color = data.color,
          track_muted = false,
          item_muted = false,
          uuid = 'fake_midi_' .. group_key .. '_' .. i,
          _is_placeholder = true,
        }
      end
    end
  end

  return samples, sample_indexes, midi_items, midi_indexes
end

-- Clear cache
function M.clear()
  reaper.SetProjExtState(0, EXTSTATE_SECTION, EXTSTATE_KEY, '')
end

return M
