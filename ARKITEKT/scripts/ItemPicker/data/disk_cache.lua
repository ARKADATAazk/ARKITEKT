-- @noindex
-- ItemPicker/data/disk_cache.lua
-- Project-scoped disk cache with LRU eviction (max 5 projects)

local M = {}

-- Cache directory: REAPER_RESOURCE_PATH/Data/ARKITEKT/ItemPicker/
--   ├── cache_index.lua (tracks 5 most recent projects)
--   ├── {project_guid_1}.lua
--   ├── {project_guid_2}.lua
--   └── ...

local cache_dir = nil
local current_project_guid = nil
local current_cache = nil -- In-memory cache for current project
local MAX_PROJECTS = 5
local flushed = false -- Prevent double flush

-- Simple Lua table serialization (supports nested tables, numbers, and strings)
-- Uses table buffer pattern to avoid O(n²) string concatenation
local function serialize(t, indent, buf)
  indent = indent or ""
  buf = buf or {}

  if type(t) ~= "table" then
    if type(t) == "number" then
      return tostring(t)
    elseif type(t) == "string" then
      return string.format("%q", t)
    else
      return "nil"
    end
  end

  local next_indent = indent .. "  "
  buf[#buf + 1] = "{\n"

  -- Handle array part
  for i, v in ipairs(t) do
    buf[#buf + 1] = next_indent
    if type(v) == "number" then
      buf[#buf + 1] = tostring(v)
    elseif type(v) == "string" then
      buf[#buf + 1] = string.format("%q", v)
    elseif type(v) == "table" then
      serialize(v, next_indent, buf)
    end
    buf[#buf + 1] = ",\n"
  end

  -- Handle hash part (for MIDI thumbnails with x1,y1,x2,y2 and hash strings)
  local array_len = #t
  for k, v in pairs(t) do
    if type(k) ~= "number" or k > array_len then
      buf[#buf + 1] = next_indent
      buf[#buf + 1] = "["
      buf[#buf + 1] = string.format("%q", tostring(k))
      buf[#buf + 1] = "] = "
      if type(v) == "number" then
        buf[#buf + 1] = tostring(v)
      elseif type(v) == "string" then
        buf[#buf + 1] = string.format("%q", v)
      elseif type(v) == "table" then
        serialize(v, next_indent, buf)
      end
      buf[#buf + 1] = ",\n"
    end
  end

  buf[#buf + 1] = indent
  buf[#buf + 1] = "}"

  -- Only concat at top level
  if indent == "" then
    return table.concat(buf)
  end
end

-- Deserialize Lua table from string
local function deserialize(str)
  if not str or str == "" then return nil end

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

-- Get current project GUID
local function get_project_guid()
  local proj = 0 -- Current project
  local retval, guid = reaper.GetSetProjectInfo_String(proj, "PROJECT_ID", "", false)

  -- If project has no GUID yet (unsaved), use project file path
  if not retval or guid == "" then
    local proj_path = reaper.GetProjectPath("")
    local proj_name = reaper.GetProjectName(0, "")

    if proj_path and proj_path ~= "" and proj_name and proj_name ~= "" then
      -- Use full path + name as stable identifier
      local full_path = proj_path .. "/" .. proj_name
      guid = "path_" .. tostring(full_path):gsub("[^%w]", "_")
    else
      guid = "unsaved_project"
    end
  end

  return guid
end

-- Get item hash (to detect if item changed)
local function get_item_hash(item)
  if not item or not reaper.ValidatePtr(item, "MediaItem*") then
    return nil
  end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local take = reaper.GetActiveTake(item)
  if not take then return nil end

  local start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

  return string.format("%.6f_%.6f_%.6f", length, start_offset, playrate)
end

-- Load cache index (tracks last 5 projects)
local function load_cache_index()
  local index_path = cache_dir .. "/cache_index.lua"
  local file = io.open(index_path, "r")

  if not file then
    return { projects = {} } -- { projects = { {guid="...", timestamp=123}, ... } }
  end

  local content = file:read("*all")
  file:close()

  local index = deserialize(content)
  return index or { projects = {} }
end

-- Save cache index
local function save_cache_index(index)
  local index_path = cache_dir .. "/cache_index.lua"
  local file = io.open(index_path, "w")

  if not file then return false end

  file:write(serialize(index))
  file:close()

  return true
end

-- Update project access time and evict old projects
local function update_project_access(project_guid)
  local index = load_cache_index()
  local timestamp = os.time()

  -- Find existing project entry
  local found = false
  for i, proj in ipairs(index.projects) do
    if proj.guid == project_guid then
      -- Update timestamp (move to end - most recent)
      table.remove(index.projects, i)
      table.insert(index.projects, { guid = project_guid, timestamp = timestamp })
      found = true
      break
    end
  end

  -- Add new project if not found
  if not found then
    table.insert(index.projects, { guid = project_guid, timestamp = timestamp })
  end

  -- Evict oldest project if we exceed MAX_PROJECTS
  if #index.projects > MAX_PROJECTS then
    local oldest = table.remove(index.projects, 1) -- Remove first (oldest)

    -- Delete the old project's cache file
    local old_cache_path = cache_dir .. "/" .. oldest.guid .. ".lua"
    os.remove(old_cache_path)
  end

  save_cache_index(index)
end

-- Load project cache from disk
local function load_project_cache(project_guid)
  local cache_path = cache_dir .. "/" .. project_guid .. ".lua"
  local file = io.open(cache_path, "r")

  if not file then
    return {} -- Empty cache
  end

  local content = file:read("*all")
  file:close()

  local cache = deserialize(content)
  if not cache then
    return {}
  end

  return cache
end

-- Save project cache to disk
local function save_project_cache(project_guid, cache)
  local cache_path = cache_dir .. "/" .. project_guid .. ".lua"
  local file = io.open(cache_path, "w")

  if not file then
    return false
  end

  file:write(serialize(cache))
  file:close()

  return true
end

-- Initialize cache system
function M.init()
  local resource_path = reaper.GetResourcePath()
  cache_dir = resource_path .. "/Data/ARKITEKT/ItemPicker"

  -- Create cache directory
  reaper.RecursiveCreateDirectory(cache_dir, 0)

  -- Get current project GUID
  current_project_guid = get_project_guid()

  -- Load cache for current project
  current_cache = load_project_cache(current_project_guid)

  -- Update access time and handle eviction
  update_project_access(current_project_guid)

  return cache_dir
end

-- Pre-load disk cache into runtime cache (call on startup)
-- This makes cached items instantly available without going through job queue
function M.preload_to_runtime(runtime_cache)
  if not current_cache or not runtime_cache then
    return { loaded = 0, skipped = 0 }
  end

  local loaded = 0
  local skipped = 0

  for uuid, entry in pairs(current_cache) do
    -- Load waveforms
    if entry.waveform then
      if not runtime_cache.waveforms then
        runtime_cache.waveforms = {}
      end
      runtime_cache.waveforms[uuid] = entry.waveform
      loaded = loaded + 1
    end

    -- Load MIDI thumbnails
    if entry.midi_thumbnail then
      if not runtime_cache.midi_thumbnails then
        runtime_cache.midi_thumbnails = {}
      end
      runtime_cache.midi_thumbnails[uuid] = entry.midi_thumbnail
      loaded = loaded + 1
    end
  end

  return { loaded = loaded, skipped = skipped }
end

-- Load waveform from cache
function M.load_waveform(item, uuid)
  if not current_cache then return nil end

  local entry = current_cache[uuid]
  if not entry then return nil end

  -- Validate hash (detect if item changed)
  local current_hash = get_item_hash(item)
  if not current_hash or entry.hash ~= current_hash then
    -- Item changed, invalidate cache entry
    current_cache[uuid] = nil
    return nil
  end

  return entry.waveform
end

-- Save waveform to cache
function M.save_waveform(item, uuid, waveform)
  if not current_cache or not waveform then
    return false
  end

  local hash = get_item_hash(item)
  if not hash then
    return false
  end

  -- Create or update entry
  if not current_cache[uuid] then
    current_cache[uuid] = {}
  end

  current_cache[uuid].hash = hash
  current_cache[uuid].waveform = waveform

  -- Don't save to disk on every waveform - too slow! Will flush on exit
  -- reaper.ShowConsoleMsg(string.format("[Cache] Saved waveform %s\n", uuid:sub(1,8)))
  return true
end

-- Load MIDI thumbnail from cache
function M.load_midi_thumbnail(item, uuid)
  if not current_cache then return nil end

  local entry = current_cache[uuid]
  if not entry then return nil end

  -- Validate hash
  local current_hash = get_item_hash(item)
  if not current_hash or entry.hash ~= current_hash then
    -- Item changed, invalidate cache entry
    current_cache[uuid] = nil
    return nil
  end

  return entry.midi_thumbnail
end

-- Save MIDI thumbnail to cache
function M.save_midi_thumbnail(item, uuid, thumbnail)
  if not current_cache or not thumbnail then return false end

  local hash = get_item_hash(item)
  if not hash then return false end

  -- Create or update entry
  if not current_cache[uuid] then
    current_cache[uuid] = {}
  end

  current_cache[uuid].hash = hash
  current_cache[uuid].midi_thumbnail = thumbnail

  -- Don't save to disk on every thumbnail - too slow! Will flush on exit
  return true
end

-- Flush cache to disk (call on exit)
function M.flush()
  if flushed then
    return
  end

  if current_cache and current_project_guid then
    local success = save_project_cache(current_project_guid, current_cache)
    if success then
      flushed = true
    end
  end
end

-- Clear cache for current project
function M.clear_current_project()
  if current_project_guid then
    current_cache = {}
    local cache_path = cache_dir .. "/" .. current_project_guid .. ".lua"
    os.remove(cache_path)
  end
end

-- Get cache stats
function M.get_stats()
  if not current_cache then return { items = 0 } end

  local count = 0
  for _ in pairs(current_cache) do
    count = count + 1
  end

  return {
    items = count,
    project = current_project_guid,
    directory = cache_dir
  }
end

return M
