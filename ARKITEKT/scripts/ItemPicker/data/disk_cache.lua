-- @noindex
-- ItemPicker/data/disk_cache.lua
-- Disk-based cache for waveforms and MIDI thumbnails

local M = {}

-- Cache directory structure:
-- REAPER_RESOURCE_PATH/Data/ARKITEKT/ItemPicker/
--   ├── waveforms/{uuid}.dat
--   └── midi_thumbnails/{uuid}.dat

local cache_dir = nil

-- Initialize cache directory
function M.init()
  local resource_path = reaper.GetResourcePath()
  cache_dir = resource_path .. "/Data/ARKITEKT/ItemPicker"

  -- Create directories if they don't exist
  local waveforms_dir = cache_dir .. "/waveforms"
  local midi_dir = cache_dir .. "/midi_thumbnails"

  reaper.RecursiveCreateDirectory(waveforms_dir, 0)
  reaper.RecursiveCreateDirectory(midi_dir, 0)

  return cache_dir
end

-- Simple Lua table serialization
local function serialize(t)
  if type(t) ~= "table" then
    return tostring(t)
  end

  local result = "{"
  for i, v in ipairs(t) do
    if type(v) == "number" then
      result = result .. v .. ","
    elseif type(v) == "table" then
      result = result .. serialize(v) .. ","
    end
  end
  result = result .. "}"
  return result
end

-- Simple Lua table deserialization
local function deserialize(str)
  if not str or str == "" then return nil end

  -- Use loadstring to evaluate the serialized table
  local func, err = load("return " .. str)
  if not func then
    return nil
  end

  local success, result = pcall(func)
  if success then
    return result
  end
  return nil
end

-- Get item hash (to detect if item changed)
local function get_item_hash(item)
  if not item then return nil end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local take = reaper.GetActiveTake(item)
  if not take then return nil end

  local start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

  -- Simple hash: concatenate values
  return string.format("%.6f_%.6f_%.6f", length, start_offset, playrate)
end

-- Load waveform from disk
function M.load_waveform(item, uuid)
  if not cache_dir then M.init() end

  local filepath = cache_dir .. "/waveforms/" .. uuid .. ".dat"
  local file = io.open(filepath, "r")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then return nil end

  -- Parse: first line is hash, rest is data
  local hash_line, data = content:match("^([^\n]+)\n(.*)$")
  if not hash_line or not data then return nil end

  -- Validate hash
  local current_hash = get_item_hash(item)
  if hash_line ~= current_hash then
    -- Item changed, invalidate cache
    os.remove(filepath)
    return nil
  end

  return deserialize(data)
end

-- Save waveform to disk
function M.save_waveform(item, uuid, waveform)
  if not cache_dir then M.init() end
  if not waveform then return false end

  local filepath = cache_dir .. "/waveforms/" .. uuid .. ".dat"
  local file = io.open(filepath, "w")
  if not file then return false end

  local hash = get_item_hash(item)
  local data = serialize(waveform)

  file:write(hash .. "\n" .. data)
  file:close()

  return true
end

-- Load MIDI thumbnail from disk
function M.load_midi_thumbnail(item, uuid)
  if not cache_dir then M.init() end

  local filepath = cache_dir .. "/midi_thumbnails/" .. uuid .. ".dat"
  local file = io.open(filepath, "r")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then return nil end

  -- Parse: first line is hash, rest is data
  local hash_line, data = content:match("^([^\n]+)\n(.*)$")
  if not hash_line or not data then return nil end

  -- Validate hash
  local current_hash = get_item_hash(item)
  if hash_line ~= current_hash then
    -- Item changed, invalidate cache
    os.remove(filepath)
    return nil
  end

  return deserialize(data)
end

-- Save MIDI thumbnail to disk
function M.save_midi_thumbnail(item, uuid, thumbnail)
  if not cache_dir then M.init() end
  if not thumbnail then return false end

  local filepath = cache_dir .. "/midi_thumbnails/" .. uuid .. ".dat"
  local file = io.open(filepath, "w")
  if not file then return false end

  local hash = get_item_hash(item)
  local data = serialize(thumbnail)

  file:write(hash .. "\n" .. data)
  file:close()

  return true
end

-- Clear entire cache (for cleanup/reset)
function M.clear_cache()
  if not cache_dir then M.init() end

  -- This is a simple implementation - could be enhanced with recursive delete
  -- For now, just return the cache directory for manual cleanup
  return cache_dir
end

return M
